require "digest"

module ReactManifest
  # Generates all ux_*.js Sprockets manifest files.
  #
  # Generates:
  #   ux_shared.js   — requires all files from shared dirs (components/, hooks/, lib/, etc.)
  #   ux_<ctrl>.js   — one per controller subdir, requires ux_shared + controller files
  #
  # All generated files carry the AUTO-GENERATED header and are idempotent
  # (skips write if content unchanged).
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
      File.write(dest, content, encoding: "utf-8")
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
      # Match .js and .js.jsx files; sort alphabetically for determinism
      Dir.glob(File.join(dir, "**", "*.{js,jsx}"))
         .reject { |f| File.directory?(f) }
         # Exclude files that are themselves manifests (AUTO-GENERATED)
         .reject { |f| auto_generated?(f) }
         .sort
    end

    def relative_require_path(abs_path)
      base = Rails.root.join("app", "assets", "javascripts").to_s + "/"
      rel  = abs_path.sub(base, "")
      # Strip Sprockets-understood extensions: .js.jsx → "", .js → ""
      rel.sub(/\.js\.jsx$/, "").sub(/\.jsx$/, "").sub(/\.js$/, "")
    end

    def auto_generated?(path)
      return false unless File.exist?(path)
      first_line = File.foreach(path).first.to_s
      first_line.include?("AUTO-GENERATED")
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
