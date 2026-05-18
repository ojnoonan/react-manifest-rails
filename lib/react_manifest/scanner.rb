require_relative "path_utils"

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
  #
  # Phase 2 — scans controller files for usage of those symbols
  #   and produces per-controller lists of referenced shared files.
  #
  # Phase 3 — emits non-fatal warnings.
  # rubocop:disable Metrics/ClassLength
  class Scanner
    include PathUtils
    include ReactManifest::Logging

    # Patterns to detect symbol definitions (CommonJS and ES module style)
    DEFINITION_PATTERNS = [
      # CommonJS / variable-assignment style
      /(?:const|let|var)\s+([A-Z][A-Za-z0-9_]*)\s*=/, # const FooBar =
      /function\s+([A-Z][A-Za-z0-9_]*)\s*\(/,         # function FooBar(
      /class\s+([A-Z][A-Za-z0-9_]*)\s*(?:extends|\{)/, # class FooBar
      /(?:const|let|var)\s+(use[A-Z][A-Za-z0-9_]*)\s*=/, # const useFoo = (hooks)
      /function\s+(use[A-Z][A-Za-z0-9_]*)\s*\(/, # function useFoo(

      # ES module style (export default / named exports)
      /^export\s+default\s+(?:function|class)\s+([A-Z][A-Za-z0-9_]*)/,
      /^export\s+default\s+(?:function|class)\s+(use[A-Z][A-Za-z0-9_]*)/,
      /^export\s+(?:const|let|var)\s+([A-Z][A-Za-z0-9_]*)\s*=/,
      /^export\s+(?:const|let|var)\s+(use[A-Z][A-Za-z0-9_]*)\s*=/,
      /^export\s+function\s+([A-Z][A-Za-z0-9_]*)\s*\(/,
      /^export\s+function\s+(use[A-Z][A-Za-z0-9_]*)\s*\(/,
      /^export\s+class\s+([A-Z][A-Za-z0-9_]*)\s*(?:extends|\{)/
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

    Result = Struct.new(:symbol_index, :controller_usages, :warnings, :shared_violations,
                        :external_violations, keyword_init: true)

    class << self
      def file_symbol_cache
        @file_symbol_cache ||= {}
      end

      def clear_cache!
        @file_symbol_cache = {}
      end

      def invalidate(file_path)
        file_symbol_cache.delete(file_path)
      end
    end

    def initialize(config = ReactManifest.configuration)
      @config = config
    end

    # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
    def scan(classification)
      warnings      = Set.new
      symbol_index  = {}
      external_file_paths = {} # file_path => relative_require_path for external_roots files

      # Phase 1a: index symbols from shared dirs; cache content for violation detection
      shared_file_paths = {}    # file_path => relative_require_path
      shared_file_content = {}  # file_path => raw content string
      classification.shared_dirs.each do |shared_dir|
        js_files_in(shared_dir[:path]).each do |file_path|
          relative = relative_require_path(file_path)
          shared_file_paths[file_path] = relative
          content = begin
            File.read(file_path, encoding: "utf-8")
          rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
            nil
          end
          shared_file_content[file_path] = content
          symbols = extract_definitions_from(file_path, content)
          symbols.each do |sym|
            if symbol_index.key?(sym)
              warnings.add("Duplicate symbol '#{sym}' in #{relative} (already from #{symbol_index[sym]})")
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
          external_file_paths[file_path] = relative
          symbols = extract_definitions(file_path)
          symbols.each do |sym|
            symbol_index[sym] ||= relative
          end
        end
      end

      # Phase 1c: add explicit external_providers (highest precedence — wins on conflict)
      @config.external_providers.each do |sym, require_path|
        symbol_index[sym] = require_path
      end

      log_debug "Shared symbol index: #{symbol_index.size} symbols indexed" if @config.verbose?

      # Phase 2: single pass over controller dirs — build violation index AND detect usages
      controller_symbol_index = {}
      controller_usages = {}

      classification.controller_dirs.each do |ctrl|
        files = js_files_in(ctrl[:path])
        used  = Set.new

        warnings.add("Controller dir '#{ctrl[:name]}' has no JS/JSX files") if files.empty? && @config.verbose?

        files.each do |file_path|
          content = read_controller_file(file_path, warnings)
          next unless content

          extract_definitions_from(file_path, content).each do |sym|
            controller_symbol_index[sym] ||= {
              file: relative_require_path(file_path),
              controller: ctrl[:name]
            }
          end

          used.merge(extract_used_shared_paths(content, symbol_index))
        end

        controller_usages[ctrl[:name]] = used.to_a.sort
      end

      # Phase 3a: detect shared/external files that use app-dir (controller) symbols
      shared_violations = detect_shared_violations(shared_file_paths, shared_file_content, controller_symbol_index,
                                                   warnings)
      external_violations = detect_external_root_violations(external_file_paths, controller_symbol_index, warnings)

      # Phase 3b: additional warnings
      emit_fanout_warnings(controller_usages, warnings)

      Result.new(
        symbol_index: symbol_index,
        controller_usages: controller_usages,
        warnings: warnings.to_a,
        shared_violations: shared_violations,
        external_violations: external_violations
      )
    end
    # rubocop:enable Metrics/MethodLength,Metrics/AbcSize

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
      cache = self.class.file_symbol_cache
      return cache[file_path] if cache.key?(file_path)

      cache[file_path] = scan_file_definitions(file_path)
    end

    # Like extract_definitions but uses pre-read content, populating the cache as a side-effect.
    def extract_definitions_from(file_path, content)
      cache = self.class.file_symbol_cache
      return cache[file_path] if cache.key?(file_path)

      cache[file_path] = parse_definitions(content)
    end

    def scan_file_definitions(file_path)
      begin
        content = File.read(file_path, encoding: "utf-8")
      rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
        return []
      end
      parse_definitions(content)
    end

    def parse_definitions(content)
      return [] unless content

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
      strip_asset_extension(rel)
    end

    def detect_shared_violations(shared_file_paths, shared_file_content, controller_symbol_index, warnings)
      violations = []
      shared_file_paths.each do |file_path, relative|
        content = shared_file_content[file_path]
        next unless content

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
            warnings.add("Shared file '#{relative}' uses app-dir symbol '#{sym}' " \
                         "(from ux/app/#{info[:controller]}). " \
                         "Move '#{sym}' to a shared dir or the shared file will be incomplete.")
          end
        end
      end
      violations
    end

    def detect_external_root_violations(external_file_paths, controller_symbol_index, warnings)
      violations = []
      external_file_paths.each do |file_path, relative|
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
            violations << { external_file: relative, symbol: sym,
                            controller: info[:controller], app_file: info[:file] }
            warnings.add("External file '#{relative}' uses app-dir symbol '#{sym}' " \
                         "(from ux/app/#{info[:controller]}). " \
                         "Move '#{sym}' into a shared ux dir to avoid duplicate runtime declarations.")
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
        warnings.add("High fan-out: '#{file}' is used by #{count} controllers") if count > 3
      end
    end

    def read_controller_file(file_path, warnings)
      File.read(file_path, encoding: "utf-8")
    rescue Errno::ENOENT, Errno::EACCES => e
      warnings.add("Skipping #{file_path}: #{e.message}")
      nil
    rescue Encoding::InvalidByteSequenceError
      warnings.add("Skipping #{file_path}: not valid UTF-8")
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

    def abs_external_root(path)
      return path if Pathname.new(path).absolute?

      Rails.root.join(path).to_s
    end
  end
  # rubocop:enable Metrics/ClassLength
end
