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

    # Patterns to detect usage in controller files
    JSX_ELEMENT_PATTERN      = %r{<([A-Z][A-Za-z0-9_]*)[\s/>]}
    REACT_CREATE_PATTERN     = /React\.createElement\(\s*([A-Z][A-Za-z0-9_]*)[\s,)]/
    HOOK_CALL_PATTERN        = /\b(use[A-Z][A-Za-z0-9_]*)\s*\(/
    # Lib calls matched against known lib symbols to reduce false positives
    LIB_CALL_PATTERN         = /\b([a-z][A-Za-z0-9_]{2,})\s*\(/

    # Common JS built-ins to exclude from lib-call matching
    JS_BUILTINS = %w[
      require function return typeof instanceof delete void
      console document window location history navigator
      setTimeout setInterval clearTimeout clearInterval
      parseInt parseFloat isNaN isFinite encodeURI decodeURI
      fetch Promise Object Array String Number Boolean Math JSON
      Object Array String Number Boolean Symbol Map Set WeakMap
    ].freeze

    Result = Struct.new(:symbol_index, :controller_usages, :warnings, keyword_init: true)

    def initialize(config = ReactManifest.configuration)
      @config = config
    end

    def scan(classification)
      warnings      = []
      symbol_index  = {}

      # Phase 1: index symbols from shared dirs
      classification.shared_dirs.each do |shared_dir|
        js_files_in(shared_dir[:path]).each do |file_path|
          relative = relative_require_path(file_path)
          symbols  = extract_definitions(file_path)
          symbols.each do |sym|
            if symbol_index.key?(sym)
              warnings << "Duplicate symbol '#{sym}' in #{relative} (already from #{symbol_index[sym]})"
            else
              symbol_index[sym] = relative
            end
          end
        end
      end

      $stdout.puts "[ReactManifest] Shared symbol index: #{symbol_index.size} symbols indexed" if @config.verbose?

      # Phase 2: scan controller dirs for usage
      controller_usages = {}

      classification.controller_dirs.each do |ctrl|
        files   = js_files_in(ctrl[:path])
        used    = Set.new

        warnings << "Controller dir '#{ctrl[:name]}' has no JS/JSX files" if files.empty? && @config.verbose?

        files.each do |file_path|
          validate_naming(file_path, ctrl[:name], warnings)
          begin
            content = File.read(file_path, encoding: "utf-8")
          rescue Errno::ENOENT, Errno::EACCES => e
            warnings << "Skipping #{file_path}: #{e.message}"
            next
          rescue Encoding::InvalidByteSequenceError
            warnings << "Skipping #{file_path}: not valid UTF-8"
            next
          end

          # JSX element usage: <PrimaryButton (JSX tag syntax)
          content.scan(JSX_ELEMENT_PATTERN) do |match|
            sym = match[0]
            used << symbol_index[sym] if symbol_index.key?(sym)
          end

          # React.createElement(PrimaryButton, ...) (non-JSX style)
          content.scan(REACT_CREATE_PATTERN) do |match|
            sym = match[0]
            used << symbol_index[sym] if symbol_index.key?(sym)
          end

          # Hook calls: useFetch(
          content.scan(HOOK_CALL_PATTERN) do |match|
            sym = match[0]
            used << symbol_index[sym] if symbol_index.key?(sym)
          end

          # Lib function calls: formatDate( — filtered against lib symbol index
          content.scan(LIB_CALL_PATTERN) do |match|
            sym = match[0]
            next if JS_BUILTINS.include?(sym)

            used << symbol_index[sym] if symbol_index.key?(sym)
          end
        end

        controller_usages[ctrl[:name]] = used.to_a.sort
      end

      # Phase 3: additional warnings
      emit_fanout_warnings(controller_usages, warnings)

      Result.new(
        symbol_index: symbol_index,
        controller_usages: controller_usages,
        warnings: warnings
      )
    end

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

    def emit_fanout_warnings(controller_usages, warnings)
      # Count how many controllers use each shared file
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
  end
end
