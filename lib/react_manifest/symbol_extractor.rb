module ReactManifest
  module SymbolExtractor
    DEFINITION_PATTERNS = [
      /(?:const|let|var)\s+([A-Z][A-Za-z0-9_]*)\s*=/,
      /function\s+([A-Z][A-Za-z0-9_]*)\s*\(/,
      /class\s+([A-Z][A-Za-z0-9_]*)\s*(?:extends|\{)/,
      /(?:const|let|var)\s+(use[A-Z][A-Za-z0-9_]*)\s*=/,
      /function\s+(use[A-Z][A-Za-z0-9_]*)\s*\(/,
      /^export\s+default\s+(?:function|class)\s+([A-Z][A-Za-z0-9_]*)/,
      /^export\s+default\s+(?:function|class)\s+(use[A-Z][A-Za-z0-9_]*)/,
      /^export\s+(?:const|let|var)\s+([A-Z][A-Za-z0-9_]*)\s*=/,
      /^export\s+(?:const|let|var)\s+(use[A-Z][A-Za-z0-9_]*)\s*=/,
      /^export\s+function\s+([A-Z][A-Za-z0-9_]*)\s*\(/,
      /^export\s+function\s+(use[A-Z][A-Za-z0-9_]*)\s*\(/,
      /^export\s+class\s+([A-Z][A-Za-z0-9_]*)\s*(?:extends|\{)/
    ].freeze

    PASCAL_TOKEN_PATTERN = /\b([A-Z][A-Za-z0-9_]*)\b/
    HOOK_TOKEN_PATTERN   = /\b(use[A-Z][A-Za-z0-9_]*)\b/
    LIB_CALL_PATTERN     = /\b([a-z][A-Za-z0-9_]{2,})\s*\(/

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
      return [] unless content

      symbols = []
      DEFINITION_PATTERNS.each do |pattern|
        content.scan(pattern) { |m| symbols << m[0] }
      end
      symbols.uniq
    end

    def extract_usages(content)
      return [] unless content

      local_syms = Set.new
      DEFINITION_PATTERNS.each { |p| content.scan(p) { |m| local_syms << m[0] } }

      used = []

      content.scan(PASCAL_TOKEN_PATTERN) do |match|
        sym = match[0]
        used << sym unless local_syms.include?(sym)
      end

      content.scan(HOOK_TOKEN_PATTERN) do |match|
        sym = match[0]
        used << sym unless local_syms.include?(sym)
      end

      content.scan(LIB_CALL_PATTERN) do |match|
        sym = match[0]
        used << sym unless JS_BUILTINS.include?(sym) || local_syms.include?(sym)
      end

      used.uniq
    end
  end
end
