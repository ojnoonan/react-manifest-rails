require "digest"
require "set"
require "tmpdir"

module ReactManifest
  # Generates all ux_*.js Sprockets manifest files.
  #
  # Generates:
  #   ux_shared.js   — requires all files from shared dirs (components/, hooks/, lib/, etc.)
  #   ux_<ctrl>.js   — one per controller subdir, requires ux_shared + controller files
  #
  # All generated files carry the AUTO-GENERATED header and are idempotent
  # (skips write if content unchanged). Writes are atomic (temp-file + rename)
  # to avoid partial reads from concurrent processes.
  #
  # Never touches application.js, application_dev.js, or files in exclude_paths.
  class Generator
    HEADER = <<~JS
      // AUTO-GENERATED — DO NOT EDIT
      // react-manifest-rails %<version>s | %<timestamp>s
      // Run `rails react_manifest:generate` to regenerate.
    JS

    def initialize(config = ReactManifest.configuration)
      @config     = config
      @classifier = TreeClassifier.new(config)
    end

    # Run full generation. Returns array of {path:, status:} hashes.
    def run!
      results        = []
      classification = @classifier.classify

      # 1. Generate ux_shared.js
      results << generate_shared(classification.shared_dirs)

      # 2. Generate one ux_<controller>.js per controller dir
      classification.controller_dirs.each do |ctrl|
        results << generate_controller(ctrl)
      end

      print_summary(results) if @config.verbose?
      results
    end

    private

    # ------------------------------------------------------------------ shared

    def generate_shared(shared_dirs)
      lines     = header_lines
      any_files = false

      shared_dirs.each do |shared_dir|
        files = js_files_in(shared_dir[:path])
        next if files.empty?

        any_files = true
        files.each { |f| lines << "//= require #{relative_require_path(f)}" }
      end

      unless any_files
        lines << "// (no shared files found)"
      end

      bundle_name = @config.shared_bundle
      write_manifest("#{bundle_name}.js", lines.join("\n") + "\n")
    end

    # --------------------------------------------------------------- controller

    def generate_controller(ctrl)
      lines = header_lines
      lines << "//= require #{@config.shared_bundle}"
      lines << ""

      files = js_files_in(ctrl[:path])
      if files.empty?
        lines << "// (no JSX files found in #{ctrl[:name]}/)"
      else
        files.each { |f| lines << "//= require #{relative_require_path(f)}" }
      end

      write_manifest("#{ctrl[:bundle_name]}.js", lines.join("\n") + "\n")
    end

    # --------------------------------------------------------------- write

    def write_manifest(filename, content)
      dest = File.join(@config.abs_output_dir, filename)

      # Safety: never touch files not bearing our AUTO-GENERATED header
      # (unless they don't exist yet)
      if File.exist?(dest) && !auto_generated?(dest)
        return { path: dest, status: :skipped_pinned }
      end

      new_digest = Digest::SHA256.hexdigest(content)

      if File.exist?(dest)
        existing_digest = Digest::SHA256.hexdigest(File.read(dest, encoding: "utf-8"))
        if existing_digest == new_digest
          return { path: dest, status: :unchanged }
        end
      end

      if @config.dry_run?
        $stdout.puts "[ReactManifest] DRY-RUN: would write #{dest}"
        print_diff(dest, content)
        return { path: dest, status: :dry_run }
      end

      FileUtils.mkdir_p(File.dirname(dest))

      # Atomic write: write to a temp file in the same directory then rename,
      # so concurrent readers never see a partially-written manifest.
      tmp = "#{dest}.tmp.#{Process.pid}"
      begin
        File.write(tmp, content, encoding: "utf-8")
        File.rename(tmp, dest)
      rescue => e
        File.unlink(tmp) if File.exist?(tmp)
        raise e
      end

      { path: dest, status: :written }
    end

    # ----------------------------------------------------------- helpers

    def header_lines
      [
        HEADER % { version: ReactManifest::VERSION, timestamp: Time.now.utc.iso8601 },
        ""
      ].flatten
    end

    def js_files_in(dir)
      return [] unless Dir.exist?(dir)

      files = Dir.glob(File.join(dir, "**", "*.{js,jsx}"))
        .reject { |f| File.directory?(f) }
        .reject { |f| auto_generated?(f) }
        .reject { |f| excluded_path?(f) }
        .sort

      # Deduplicate by logical require path: if both foo.js and foo.jsx exist,
      # keep foo.js (sorted first) to avoid duplicate //= require directives
      # that would cause a Sprockets error.
      seen = Set.new
      files.each_with_object([]) do |f, uniq|
        logical = relative_require_path(f)
        next if seen.include?(logical)
        seen << logical
        uniq << f
      end
    end

    # Returns true if the file path contains a component matching any exclude_path.
    # exclude_paths are matched against individual path segments, so "vendor" matches
    # ux/vendor/foo.js but not ux/vendor_custom/foo.js.
    def excluded_path?(abs_path)
      parts = abs_path.split(File::SEPARATOR)
      @config.exclude_paths.any? { |ep| parts.include?(ep) }
    end

    def relative_require_path(abs_path)
      # Build relative to output_dir (configurable) rather than a hardcoded path.
      base = @config.abs_output_dir + File::SEPARATOR
      rel  = abs_path.sub(base, "")
      # Strip Sprockets-understood extensions: .js.jsx → "", .jsx → "", .js → ""
      rel.sub(/\.js\.jsx$/, "").sub(/\.jsx$/, "").sub(/\.js$/, "")
    end

    def auto_generated?(path)
      return false unless File.exist?(path)
      # Read up to first 2 lines — handles empty files (first.to_s returns "")
      # without incorrectly treating them as user-pinned.
      first_two = File.foreach(path).first(2).join
      first_two.include?("AUTO-GENERATED")
    end

    def print_diff(dest, new_content)
      if File.exist?(dest)
        old_lines = File.readlines(dest, encoding: "utf-8")
        new_lines = new_content.lines

        removed = old_lines - new_lines
        added   = new_lines - old_lines

        removed.each { |l| $stdout.puts "  - #{l.chomp}" }
        added.each   { |l| $stdout.puts "  + #{l.chomp}" }
      else
        new_content.each_line { |l| $stdout.puts "  + #{l.chomp}" }
      end
    end

    def print_summary(results)
      counts = results.group_by { |r| r[:status] }.transform_values(&:count)
      $stdout.puts "[ReactManifest] Generated: #{counts[:written] || 0} written, " \
                   "#{counts[:unchanged] || 0} unchanged, " \
                   "#{counts[:skipped_pinned] || 0} skipped (not auto-generated)"
    end
  end
end
