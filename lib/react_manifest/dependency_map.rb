module ReactManifest
  # Wraps scanner results into a queryable dependency map.
  # Used by the analyze rake task and reporter for diagnostics.
  class DependencyMap
    attr_reader :symbol_index, :controller_usages, :warnings

    def initialize(scan_result)
      @symbol_index      = scan_result.symbol_index
      @controller_usages = scan_result.controller_usages
      @warnings          = scan_result.warnings
    end

    # All shared files used by the given controller
    def shared_files_for(controller_name)
      @controller_usages.fetch(controller_name, [])
    end

    # Which controllers use a given shared file
    def controllers_using(shared_file)
      @controller_usages.select { |_, files| files.include?(shared_file) }.keys
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
        puts "  #{sym.ljust(40)} #{file}"
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
