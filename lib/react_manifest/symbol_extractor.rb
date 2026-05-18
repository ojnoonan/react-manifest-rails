module ReactManifest
  module SymbolExtractor
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

    module_function

    def extract_definitions(content)
      return [] if content.to_s.empty?

      symbols = []
      scan_content = strip_comments(content)
      DEFINITION_PATTERNS.each do |pattern|
        scan_content.scan(pattern) { |match| symbols << match[0] }
      end
      symbols.uniq
    end

    def extract_usages(content)
      return [] if content.to_s.empty?

      scan_content = strip_comments(content)
      local_syms = extract_definitions(scan_content)
      symbols = []

      [PASCAL_TOKEN_PATTERN, HOOK_TOKEN_PATTERN, LIB_CALL_PATTERN].each do |pattern|
        scan_content.scan(pattern) do |match|
          sym = match[0]
          next if method_call?(scan_content, Regexp.last_match.begin(0))
          next if local_syms.include?(sym)
          next if JS_BUILTINS.include?(sym)

          symbols << sym
        end
      end

      symbols.uniq
    end

    def strip_comments(content)
      content.gsub(%r{/\*.*?\*/}m, "").gsub(%r{//.*$}, "")
    end

    def method_call?(content, start_index)
      start_index.positive? && content[start_index - 1] == "."
    end
    private_class_method :strip_comments, :method_call?
  end
end
