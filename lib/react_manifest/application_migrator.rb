module ReactManifest
  # Rewrites application*.js files to remove UX/app code requires,
  # while preserving all non-UX directives.
  #
  # Safety:
  #   - Creates a .bak backup before any write; aborts if backup fails
  #   - Dry-run mode: prints what would change, writes nothing
  #   - Never removes :vendor or :passthrough lines
  #   - Adds a managed-by comment at the top
  class ApplicationMigrator
    MANAGED_COMMENT = <<~JS.freeze
      // Non-UX libraries — loaded on every page.
      // React app code is now served per-controller via react_bundle_tag.
      // Managed by react-manifest-rails — do not add require_tree.
    JS

    LEGACY_MANAGED_COMMENT = <<~JS.freeze
      // Vendor libraries — loaded on every page.
      // React app code is now served per-controller via react_bundle_tag.
      // Managed by react-manifest-rails — do not add require_tree.
    JS

    def initialize(config = ReactManifest.configuration)
      @config   = config
      @analyzer = ApplicationAnalyzer.new(config)
    end

    # Migrate all application*.js files. Returns array of {file:, status:} hashes.
    def migrate!
      results = @analyzer.analyze

      if results.empty?
        $stdout.puts "[ReactManifest] No application*.js files found to migrate."
        return []
      end

      results.map do |result|
        if result.clean?
          $stdout.puts "[ReactManifest] #{short(result.file)} — already clean, skipping."
          { file: result.file, status: :already_clean }
        else
          rewrite(result)
        end
      end
    end

    private

    def rewrite(result)
      file        = result.file
      new_content = build_new_content(result)

      if @config.dry_run?
        $stdout.puts "\n[ReactManifest] DRY-RUN: #{short(file)}"
        print_diff(file, new_content)
        return { file: file, status: :dry_run }
      end

      # Backup first — abort if backup cannot be created to avoid data loss.
      bak_path = "#{file}.bak"
      begin
        FileUtils.cp(file, bak_path)
        File.chmod(0o600, bak_path)
        $stdout.puts "[ReactManifest] Backup: #{short(bak_path)}"
      rescue StandardError => e
        $stdout.puts "[ReactManifest] ERROR: Could not create backup of #{short(file)}: #{e.message}"
        $stdout.puts "[ReactManifest] Migration aborted for #{short(file)} — original file unchanged."
        return { file: file, status: :backup_failed, error: e.message }
      end

      File.write(file, new_content, encoding: "utf-8")
      $stdout.puts "[ReactManifest] Migrated: #{short(file)}"

      { file: file, status: :migrated, backup: bak_path }
    end

    def build_new_content(result)
      kept_lines = result.directives
                         .reject do |d|
        d.classification == :ux_code
      end
                                          .map(&:original_line)

      strip_managed_header!(kept_lines)

      # Remove leading blank lines from kept_lines
      kept_lines.shift while kept_lines.first&.strip&.empty?

      lines = []
      lines << MANAGED_COMMENT
      lines += kept_lines
      lines << "" # trailing newline

      lines.join("\n")
    end

    def strip_managed_header!(lines)
      managed_variants = [MANAGED_COMMENT, LEGACY_MANAGED_COMMENT].map { |comment| comment.lines.map(&:chomp) }

      loop do
        matched = managed_variants.any? { |managed_lines| starts_with_lines?(lines, managed_lines) }
        break unless matched

        header_len = managed_variants.find { |managed_lines| starts_with_lines?(lines, managed_lines) }.length
        lines.shift(header_len)
        lines.shift while lines.first&.strip&.empty?
      end
    end

    def starts_with_lines?(lines, prefix)
      return false if lines.length < prefix.length

      lines.first(prefix.length) == prefix
    end

    def print_diff(file, new_content)
      old_lines = File.readlines(file, encoding: "utf-8").map(&:chomp)
      new_lines = new_content.lines.map(&:chomp)

      removed = old_lines - new_lines
      added   = new_lines - old_lines

      removed.each { |l| $stdout.puts "  - #{l}" }
      added.each   { |l| $stdout.puts "  + #{l}" }
    end

    def short(path)
      path.to_s.sub("#{Rails.root}/", "")
    end
  end
end
