module ReactManifest
  # Scans JS/JSX (and optionally TS/TSX) files using regex — no AST, no Node.js required.
  #
  # Returns a {Result} containing:
  # - +symbol_index+  — map of exported symbol name → shared require path
  # - +controller_usages+ — map of controller name → sorted array of referenced shared files
  # - +warnings+ — non-fatal issues found during scanning
  #
  # Phase 1 — builds a symbol index from shared dirs:
  #   "PrimaryButton" => "ux/components/buttons/primary_button"
  #   "useFetch"      => "ux/hooks/use_fetch"
  #   "formatDate"    => "ux/lib/format_date"
  #
  # Phase 2 — scans controller files for usage of those symbols
  #   and produces per-controller lists of referenced shared files.
  #
  # Phase 3 — emits non-fatal warnings.
  # rubocop:disable Metrics/ClassLength
  class Scanner
    # Patterns to detect symbol definitions (CommonJS and ES module style)
    DEFINITION_PATTERNS = [
      # CommonJS / variable-assignment style
      /(?:const|let|var)\s+([A-Z][A-Za-z0-9_]*)\s*=/, # const FooBar =
      /function\s+([A-Z][A-Za-z0-9_]*)\s*\(/,                                       # function FooBar(
      /class\s+([A-Z][A-Za-z0-9_]*)\s*(?:extends|\{)/,                              # class FooBar
      /(?:const|let|var)\s+(use[A-Z][A-Za-z0-9_]*)\s*=/, # const useFoo = (hooks)
      /function\s+(use[A-Z][A-Za-z0-9_]*)\s*\(/, # function useFoo(
      /(?:const|let|var)\s+([a-z][A-Za-z0-9_]{2,})\s*=\s*(?:function|\()/, # const formatDate = function/arrow
      /^function\s+([a-z][A-Za-z0-9_]{2,})\s*\(/, # function formatDate( at line start

      # ES module style (export default / named exports)
      /^export\s+default\s+(?:function|class)\s+([A-Z][A-Za-z0-9_]*)/,             # export default function Foo
      /^export\s+default\s+(?:function|class)\s+(use[A-Z][A-Za-z0-9_]*)/,          # export default function useFoo
      /^export\s+(?:const|let|var)\s+([A-Z][A-Za-z0-9_]*)\s*=/,                    # export const Foo =
      /^export\s+(?:const|let|var)\s+(use[A-Z][A-Za-z0-9_]*)\s*=/,                 # export const useFoo =
      /^export\s+(?:const|let|var)\s+([a-z][A-Za-z0-9_]{2,})\s*=\s*(?:function|\()/, # export const formatDate =
      /^export\s+function\s+([A-Z][A-Za-z0-9_]*)\s*\(/,                             # export function Foo(
      /^export\s+function\s+(use[A-Z][A-Za-z0-9_]*)\s*\(/,                          # export function useFoo(
      /^export\s+class\s+([A-Z][A-Za-z0-9_]*)\s*(?:extends|\{)/ # export class Foo
    ].freeze

    # Patterns to detect usage in controller files.
    # Token-based patterns match any identifier occurrence regardless of syntax
    # context (JSX, constructor, assignment, array, function argument, etc.).
    PASCAL_TOKEN_PATTERN = /\b([A-Z][A-Za-z0-9_]*)\b/
    HOOK_TOKEN_PATTERN   = /\b(use[A-Z][A-Za-z0-9_]*)\b/
    # Lib calls matched against known lib symbols to reduce false positives
    LIB_CALL_PATTERN     = /\b([a-z][A-Za-z0-9_]{2,})\s*\(/

    # Common JS built-ins to exclude from lib-call matching
    JS_BUILTINS = %w[
      require function return typeof instanceof delete void
      console document window location history navigator
      setTimeout setInterval clearTimeout clearInterval
      parseInt parseFloat isNaN isFinite encodeURI decodeURI
      fetch Promise Object Array String Number Boolean Math JSON
      Object Array String Number Boolean Symbol Map Set WeakMap
    ].freeze

    Result = Struct.new(:symbol_index, :controller_usages, :warnings, :shared_violations, keyword_init: true)

    def initialize(config = ReactManifest.configuration)
      @config = config
    end

    # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/PerceivedComplexity
    def scan(classification)
      warnings      = []
      symbol_index  = {}

      # Phase 1a: index symbols from shared dirs
      shared_file_paths = {} # file_path => relative_require_path for all shared files
      classification.shared_dirs.each do |shared_dir|
        js_files_in(shared_dir[:path]).each do |file_path|
          relative = relative_require_path(file_path)
          shared_file_paths[file_path] = relative
          symbols = extract_definitions(file_path)
          symbols.each do |sym|
            if symbol_index.key?(sym)
              warnings << "Duplicate symbol '#{sym}' in #{relative} (already from #{symbol_index[sym]})"
            else
              symbol_index[sym] = relative
            end
          end
        end
      end

      # Phase 1b: index symbols from external_roots dirs
      @config.external_roots.each do |root_path|
        abs_root = abs_external_root(root_path)
        js_files_in(abs_root).each do |file_path|
          relative = relative_require_path(file_path)
          symbols  = extract_definitions(file_path)
          symbols.each do |sym|
            symbol_index[sym] ||= relative
          end
        end
      end

      # Phase 1c: add explicit external_providers (highest precedence — wins on conflict)
      @config.external_providers.each do |sym, require_path|
        symbol_index[sym] = require_path
      end

      # Phase 1d: build controller (app-dir) symbol index for violation detection
      controller_symbol_index = {}
      classification.controller_dirs.each do |ctrl|
        js_files_in(ctrl[:path]).each do |file_path|
          extract_definitions(file_path).each do |sym|
            controller_symbol_index[sym] ||= {
              file: relative_require_path(file_path),
              controller: ctrl[:name]
            }
          end
        end
      end

      $stdout.puts "[ReactManifest] Shared symbol index: #{symbol_index.size} symbols indexed" if @config.verbose?

      # Phase 1e: detect shared files that use app-dir (controller) symbols
      shared_violations = detect_shared_violations(shared_file_paths, controller_symbol_index, warnings)

      # Phase 2: scan controller dirs for usage
      controller_usages = {}

      classification.controller_dirs.each do |ctrl|
        files   = js_files_in(ctrl[:path])
        used    = Set.new

        warnings << "Controller dir '#{ctrl[:name]}' has no JS/JSX files" if files.empty? && @config.verbose?

        files.each do |file_path|
          validate_naming(file_path, ctrl[:name], warnings)
          content = read_controller_file(file_path, warnings)
          next unless content

          used.merge(extract_used_shared_paths(content, symbol_index))
        end

        controller_usages[ctrl[:name]] = used.to_a.sort
      end

      # Phase 3: additional warnings
      emit_fanout_warnings(controller_usages, warnings)

      Result.new(
        symbol_index: symbol_index,
        controller_usages: controller_usages,
        warnings: warnings,
        shared_violations: shared_violations
      )
    end
    # rubocop:enable Metrics/MethodLength,Metrics/AbcSize,Metrics/PerceivedComplexity

    private

    def js_files_in(dir)
      return [] unless Dir.exist?(dir)

      Dir.glob(File.join(dir, "**", @config.extensions_glob))
         .reject { |f| File.directory?(f) }
         .reject { |f| excluded_path?(f) }
         .sort
    end

    # Returns true if the file path contains a segment matching any exclude_path.
    def excluded_path?(abs_path)
      parts = abs_path.split(File::SEPARATOR)
      @config.exclude_paths.any? { |ep| parts.include?(ep) }
    end

    def extract_definitions(file_path)
      begin
        content = File.read(file_path, encoding: "utf-8")
      rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
        return []
      end
      symbols = []
      DEFINITION_PATTERNS.each do |pattern|
        content.scan(pattern) { |m| symbols << m[0] }
      end
      symbols.uniq
    end

    def relative_require_path(abs_path)
      # Build relative to output_dir (configurable) rather than a hardcoded path.
      base = @config.abs_output_dir + File::SEPARATOR
      rel  = abs_path.sub(base, "")
      # Strip Sprockets-understood extensions: .js.jsx/.jsx/.js -> logical path.
      rel.sub(/\.js\.jsx$/, "").sub(/\.jsx$/, "").sub(/\.js$/, "")
    end

    def validate_naming(file_path, ctrl_name, warnings)
      basename = File.basename(file_path, ".*").sub(/\.js$/, "")
      # Expected: <controller>_index, <controller>_show, <controller>_form, etc.
      return if basename.start_with?("#{ctrl_name}_") || basename == ctrl_name

      warnings << "File '#{File.basename(file_path)}' in '#{ctrl_name}' does not follow " \
                  "'#{ctrl_name}_<action>.js.jsx' naming convention"
    end

    def detect_shared_violations(shared_file_paths, controller_symbol_index, warnings)
      violations = []
      shared_file_paths.each do |file_path, relative|
        content = begin
          File.read(file_path, encoding: "utf-8")
        rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
          next
        end

        local_syms = Set.new
        DEFINITION_PATTERNS.each { |p| content.scan(p) { |m| local_syms << m[0] } }

        [PASCAL_TOKEN_PATTERN, HOOK_TOKEN_PATTERN].each do |pattern|
          content.scan(pattern) do |match|
            sym = match[0]
            next if local_syms.include?(sym)
            next unless controller_symbol_index.key?(sym)

            info = controller_symbol_index[sym]
            violations << { shared_file: relative, symbol: sym,
                            controller: info[:controller], app_file: info[:file] }
            warnings << "Shared file '#{relative}' uses app-dir symbol '#{sym}' " \
                        "(from ux/app/#{info[:controller]}). " \
                        "Move '#{sym}' to a shared dir or the shared file will be incomplete."
          end
        end
      end
      violations
    end

    # Count how many controllers use each shared file
    def emit_fanout_warnings(controller_usages, warnings)
      fanout = Hash.new(0)
      controller_usages.each_value do |files|
        files.each { |f| fanout[f] += 1 }
      end

      fanout.each do |file, count|
        if count > 3
          warnings << "High fan-out: '#{file}' is used by #{count} controllers " \
                      "(consider ensuring it's in the shared bundle)"
        end
      end
    end

    def read_controller_file(file_path, warnings)
      File.read(file_path, encoding: "utf-8")
    rescue Errno::ENOENT, Errno::EACCES => e
      warnings << "Skipping #{file_path}: #{e.message}"
      nil
    rescue Encoding::InvalidByteSequenceError
      warnings << "Skipping #{file_path}: not valid UTF-8"
      nil
    end

    def extract_used_shared_paths(content, symbol_index)
      used = Set.new

      # Collect locally-defined symbols so we don't count a file as "using"
      # its own exports (avoid self-referencing false positives).
      local_syms = Set.new
      DEFINITION_PATTERNS.each do |pattern|
        content.scan(pattern) { |m| local_syms << m[0] }
      end

      # PascalCase token scan: catches JSX elements, constructors (new Foo()),
      # prop values, array entries, function arguments, assignments, etc.
      content.scan(PASCAL_TOKEN_PATTERN) do |match|
        sym = match[0]
        next if local_syms.include?(sym)
        next unless symbol_index.key?(sym)

        used << symbol_index[sym]
      end

      # Hook token scan: catches useFoo(...) and bare useFoo references.
      content.scan(HOOK_TOKEN_PATTERN) do |match|
        sym = match[0]
        next if local_syms.include?(sym)
        next unless symbol_index.key?(sym)

        used << symbol_index[sym]
      end

      # Lib call scan (lowercase): already filtered to symbol_index keys.
      content.scan(LIB_CALL_PATTERN) do |match|
        sym = match[0]
        next if JS_BUILTINS.include?(sym)
        next if local_syms.include?(sym)
        next unless symbol_index.key?(sym)

        used << symbol_index[sym]
      end

      used
    end

    def scan_component_usage(content, pattern, symbol_index, used)
      content.scan(pattern) do |match|
        sym = match[0]
        next unless symbol_index.key?(sym)

        used << symbol_index[sym]
      end
    end

    def scan_array_component_usage(content, symbol_index, used)
      content.scan(ARRAY_COMPONENT_LIST_PATTERN) do |match|
        list = match[0]
        list.split(/\s*,\s*/).each do |sym|
          next unless symbol_index.key?(sym)

          used << symbol_index[sym]
        end
      end
    end

    def abs_external_root(path)
      return path if Pathname.new(path).absolute?

      Rails.root.join(path).to_s
    end
  end
  # rubocop:enable Metrics/ClassLength
end
