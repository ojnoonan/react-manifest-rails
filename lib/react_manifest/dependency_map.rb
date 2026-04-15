module ReactManifest
  # Wraps {Scanner} results into a queryable dependency map.
  #
  # Used by +react_manifest:analyze+ rake task and {Reporter} for diagnostics.
  #
  # @example
  #   result = ReactManifest::Scanner.new.scan(classifier.classify)
  #   map    = ReactManifest::DependencyMap.new(result)
  #   map.shared_files_for("users")      # => ["ux/components/...", ...]
  #   map.controllers_using("ux/lib/api_helpers") # => ["users", "admin"]
  class DependencyMap
    attr_reader :symbol_index, :controller_usages, :warnings

    def initialize(scan_result)
      @symbol_index      = scan_result.symbol_index
      @controller_usages = scan_result.controller_usages
      @warnings          = scan_result.warnings

      # Inverted index: shared_file → [controllers] for O(1) lookup
      @controllers_by_file = {}
      @controller_usages.each do |ctrl, files|
        files.each { |f| (@controllers_by_file[f] ||= []) << ctrl }
      end
    end

    # All shared files used by the given controller
    def shared_files_for(controller_name)
      @controller_usages.fetch(controller_name, [])
    end

    # Which controllers use a given shared file (O(1) via inverted index)
    def controllers_using(shared_file)
      @controllers_by_file.fetch(shared_file, [])
    end

    # Symbols defined in shared dirs
    def all_symbols
      @symbol_index.keys
    end

    # Pretty-print for the analyze rake task
    def print_report
      puts "\n=== ReactManifest Dependency Analysis ===\n\n"

      puts "Shared Symbol Index (#{@symbol_index.size} symbols):"
      @symbol_index.each do |sym, file|
        # Strip non-printable/control characters to prevent terminal manipulation
        safe_sym  = sym.gsub(/[^\x20-\x7E]/, "?")
        safe_file = file.gsub(/[^\x20-\x7E]/, "?")
        puts "  #{safe_sym.ljust(40)} #{safe_file}"
      end

      puts "\nPer-Controller Usage:"
      @controller_usages.each do |ctrl, files|
        puts "\n  [#{ctrl}] (#{files.size} shared references)"
        files.each { |f| puts "    #{f}" }
        puts "    (none)" if files.empty?
      end

      unless @warnings.empty?
        puts "\nWarnings (#{@warnings.size}):"
        @warnings.each { |w| puts "  ⚠  #{w}" }
      end

      puts "\n"
    end
  end
end
