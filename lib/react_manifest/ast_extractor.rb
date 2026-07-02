require "mini_racer"
require "json"
require_relative "logging"

module ReactManifest
  # AST-based symbol extraction backed by an embedded V8 (mini_racer).
  # Mirrors SymbolExtractor's public interface exactly. Never raises — any
  # parse or runtime failure returns nil (after logging a warning) so the
  # caller (SymbolExtractor's dispatcher) can fall back to regex extraction
  # for that one file.
  module AstExtractor
    VENDOR_SCRIPT = File.expand_path("vendor/ast_extractor.js", __dir__)

    GLUE = <<~JS.freeze
      function __reactManifestExtractDefinitions(content) {
        return JSON.stringify(__astExtractor.extractDefinitions(content));
      }
      function __reactManifestExtractUsages(content) {
        return JSON.stringify(__astExtractor.extractUsages(content));
      }
    JS

    class << self
      include ReactManifest::Logging

      def extract_definitions(content, file_path: nil)
        result = call_js("__reactManifestExtractDefinitions", content)
        return result["definitions"] if result["success"]

        report_error(file_path, result["error"])
        nil
      end

      def extract_usages(content, file_path: nil)
        result = call_js("__reactManifestExtractUsages", content)
        return result["usages"] if result["success"]

        report_error(file_path, result["error"])
        nil
      end

      private

      def context
        @context ||= begin
          ctx = MiniRacer::Context.new
          ctx.eval(File.read(VENDOR_SCRIPT))
          ctx.eval(GLUE)
          ctx
        end
      end

      def call_js(function_name, content)
        JSON.parse(context.call(function_name, content))
      rescue MiniRacer::Error => e
        @context = nil
        { "success" => false, "error" => { "message" => e.message, "line" => nil, "column" => nil } }
      rescue StandardError => e
        { "success" => false, "error" => { "message" => e.message, "line" => nil, "column" => nil } }
      end

      def report_error(file_path, error)
        location = file_path || "unknown file"
        location = "#{location} at line #{error['line']}, column #{error['column']}" if error && error["line"]
        message = error ? error["message"] : "unknown error"
        log_warn "AST parse failed for #{location}: #{message} — falling back to regex extraction for this file."
      end
    end
  end
end
