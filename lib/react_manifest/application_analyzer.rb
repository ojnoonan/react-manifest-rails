module ReactManifest
  # Analyzes existing application*.js files to classify each directive as:
  #   :vendor   — vendor lib require (keep)
  #   :ux_code  — UX/app code require (remove — will be served by ux_*.js bundles)
  #   :unknown  — needs manual review
  #
  # Produces a human-readable report without writing anything.
  class ApplicationAnalyzer
    DIRECTIVE_PATTERN = /^\s*\/\/=\s+(require(?:_tree|_directory)?)\s+(.+)$/.freeze

    # Libs we recognise as vendor (case-insensitive partial match on the require path)
    VENDOR_HINTS = %w[
      react react-dom react_dom reactdom
      mui material-ui
      redux redux-thunk
      axios lodash underscore
      jquery backbone handlebars
      turbo stimulus
      vendor
    ].freeze

    ClassifiedDirective = Struct.new(:original_line, :directive, :path, :classification, :note, keyword_init: true)

    Result = Struct.new(:file, :directives, keyword_init: true) do
      def vendor_lines;   directives.select { |d| d.classification == :vendor };   end
      def ux_code_lines;  directives.select { |d| d.classification == :ux_code };  end
      def unknown_lines;  directives.select { |d| d.classification == :unknown };  end
      def clean?;         ux_code_lines.empty? && unknown_lines.empty?;             end
    end

    def initialize(config = ReactManifest.configuration)
      @config = config
    end

    # Returns array of Result objects, one per application*.js found
    def analyze
      application_files.map { |f| analyze_file(f) }
    end

    # Pretty-print the analysis report to stdout
    def print_report(results = analyze)
      puts "\n=== ReactManifest: Application Manifest Analysis ===\n"

      if results.empty?
        puts "No application*.js files found in #{@config.abs_output_dir}"
        return
      end

      results.each do |result|
        rel = result.file.sub(Rails.root.to_s + "/", "")
        status = result.clean? ? "✓ already clean" : "⚠ needs migration"
        puts "\n#{rel} [#{status}]"
        puts "-" * 60

        result.directives.each do |d|
          icon = case d.classification
                 when :vendor   then "  ✓ KEEP   "
                 when :ux_code  then "  ✗ REMOVE "
                 when :unknown  then "  ? REVIEW "
                 end
          puts "#{icon} #{d.original_line.strip}"
          puts "           → #{d.note}" if d.note
        end
      end

      puts "\n"
      puts "Run `rails react_manifest:migrate_application` to apply changes."
      puts "Use `--dry-run` (or config.dry_run = true) to preview first.\n\n"
    end

    private

    def application_files
      Dir.glob(File.join(@config.abs_output_dir, "application*.js"))
         .reject { |f| f.end_with?(".bak") }
         .sort
    end

    def analyze_file(file_path)
      directives = []

      File.foreach(file_path, encoding: "utf-8") do |line|
        raw = line.chomp
        match = raw.match(DIRECTIVE_PATTERN)

        unless match
          # Non-directive lines (comments, blank) — pass through as :vendor (keep)
          directives << ClassifiedDirective.new(
            original_line:  raw,
            directive:      nil,
            path:           nil,
            classification: :passthrough,
            note:           nil
          )
          next
        end

        directive = match[1]  # require, require_tree, require_directory
        path      = match[2].strip

        classification, note = classify_directive(directive, path)

        directives << ClassifiedDirective.new(
          original_line:  raw,
          directive:      directive,
          path:           path,
          classification: classification,
          note:           note
        )
      end

      Result.new(file: file_path, directives: directives)
    end

    def classify_directive(directive, path)
      # require_tree is almost always too greedy
      if directive.include?("tree") || directive.include?("directory")
        if path_is_ux?(path)
          return [:ux_code, "require_tree over ux/ — will be replaced by ux_*.js bundles"]
        else
          return [:unknown, "require_tree/require_directory — review manually: #{path}"]
        end
      end

      # Explicit require
      if path_is_ux?(path)
        return [:ux_code, "ux/ code — will be served by ux_*.js bundles"]
      end

      if path_is_vendor?(path)
        return [:vendor, nil]
      end

      [:unknown, "Could not auto-classify — review manually"]
    end

    def path_is_ux?(path)
      ux_prefix = @config.ux_root.split("/").last  # e.g. "ux"
      path.include?(ux_prefix) ||
        path.start_with?("./ux") ||
        path.start_with?("ux/")
    end

    def path_is_vendor?(path)
      normalised = path.downcase
      VENDOR_HINTS.any? { |hint| normalised.include?(hint) } ||
        @config.exclude_paths.any? { |ep| normalised.include?(ep.downcase) }
    end
  end
end
