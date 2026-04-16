require "digest"
require "tmpdir"

module ReactManifest
  # Generates all ux_*.js Sprockets manifest files.
  #
  # Instantiate with a {Configuration} and call {#run!}:
  #
  #   ReactManifest::Generator.new(ReactManifest.configuration).run!
  #
  # Returns an array of result hashes:
  #   [{path: "/abs/path/ux_shared.js", status: :written}, ...]
  #
  # Possible +status+ values: +:written+, +:unchanged+, +:skipped_pinned+, +:dry_run+.
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
  # rubocop:disable Metrics/ClassLength
  class Generator
    HEADER = <<~JS.freeze
      // AUTO-GENERATED — DO NOT EDIT
      // react-manifest-rails %<version>s
      // Run `rails react_manifest:generate` to regenerate.
    JS

    def initialize(config = ReactManifest.configuration)
      @config     = config
      @classifier = TreeClassifier.new(config)
    end

    # Run full generation. Returns array of {path:, status:} hashes.
    #
    # All manifest content is built first (no filesystem writes), then written
    # in a second pass so that a failure midway does not leave some bundles
    # written and others stale/missing.
    def run!
      classification = @classifier.classify
      controller_context = build_controller_context(classification.controller_dirs)

      # Phase 1: build all content in memory — no I/O.
      manifests = []
      manifests << build_shared(classification.shared_dirs)
      classification.controller_dirs.each { |ctrl| manifests << build_controller(ctrl, controller_context) }

      migrate_legacy_manifests!

      # Phase 2: write — each write is atomic (tmp + rename).
      results = manifests.map { |m| write_manifest(m[:filename], m[:content]) }

      print_summary(results) if @config.verbose?
      results
    end

    private

    # ------------------------------------------------------------------ shared

    def build_shared(shared_dirs)
      lines     = header_lines
      any_files = false

      shared_dirs.each do |shared_dir|
        files = js_files_in(shared_dir[:path])
        next if files.empty?

        any_files = true
        files.each { |f| lines << "//= require #{relative_require_path(f)}" }
      end

      lines << "// (no shared files found)" unless any_files

      { filename: "#{@config.shared_bundle}.js", content: "#{lines.join("\n")}\n" }
    end

    # --------------------------------------------------------------- controller

    def build_controller(ctrl, controller_context)
      lines = header_lines
      dep_requires = controller_dependency_requires(ctrl[:bundle_name], controller_context)
      ext_reqs = controller_context[:external_requires].fetch(ctrl[:bundle_name], Set.new).to_a.sort

      files = js_files_in(ctrl[:path])
      own_requires = files.map { |f| relative_require_path(f) }
      all_requires = (dep_requires + ext_reqs + own_requires).uniq

      if all_requires.empty?
        lines << "// (no JSX files found in #{ctrl[:name]}/)"
      else
        all_requires.each { |req| lines << "//= require #{req}" }
      end

      { filename: "#{ctrl[:bundle_name]}.js", content: "#{lines.join("\n")}\n" }
    end

    def build_controller_context(controller_dirs)
      bundle_files = {}
      symbol_to_bundle = {}
      external_symbol_to_require = {}
      dependencies = Hash.new { |h, k| h[k] = Set.new }
      external_requires = Hash.new { |h, k| h[k] = Set.new }

      # Index controller-defined symbols for cross-app detection
      controller_dirs.each do |ctrl|
        bundle_name = ctrl[:bundle_name]
        files = js_files_in(ctrl[:path])
        bundle_files[bundle_name] = files

        files.each do |file_path|
          extract_defined_symbols(file_path).each do |sym|
            next unless sym.match?(/\A[A-Z][A-Za-z0-9_]*\z/)

            symbol_to_bundle[sym] ||= bundle_name
          end
        end
      end

      # Index symbols from external_roots dirs
      @config.external_roots.each do |root_path|
        abs_root = abs_external_root(root_path)
        external_js_files_in(abs_root).each do |file_path|
          req_path = relative_require_path(file_path)
          extract_defined_symbols(file_path).each do |sym|
            external_symbol_to_require[sym] ||= req_path
          end
        end
      end

      # Explicit external_providers win over scanned roots on symbol conflicts
      @config.external_providers.each do |sym, req_path|
        external_symbol_to_require[sym] = req_path
      end

      # Compute per-bundle cross-app and external dependencies
      bundle_files.each do |bundle_name, files|
        files.each do |file_path|
          extract_used_component_symbols(file_path).each do |sym|
            dep_bundle = symbol_to_bundle[sym]
            dependencies[bundle_name] << dep_bundle if dep_bundle && dep_bundle != bundle_name

            req_path = external_symbol_to_require[sym]
            external_requires[bundle_name] << req_path if req_path
          end
        end
      end

      {
        bundle_files: bundle_files,
        dependencies: dependencies,
        external_requires: external_requires
      }
    end

    def controller_dependency_requires(bundle_name, controller_context)
      deps = transitive_dependencies(bundle_name, controller_context[:dependencies])
      deps.flat_map { |dep_bundle| controller_context[:bundle_files].fetch(dep_bundle, []) }
          .map { |abs_path| relative_require_path(abs_path) }
          .uniq
          .sort
    end

    def transitive_dependencies(bundle_name, dependency_map)
      ordered = []
      visiting = Set.new
      visited = Set.new

      walk = lambda do |current|
        return if visited.include?(current) || visiting.include?(current)

        visiting << current
        dependency_map.fetch(current, Set.new).each { |dep| walk.call(dep) }
        visiting.delete(current)

        visited << current
        ordered << current unless current == bundle_name
      end

      walk.call(bundle_name)
      ordered
    end

    # --------------------------------------------------------------- write

    def write_manifest(filename, content)
      dest = File.join(@config.abs_manifest_dir, filename)

      # Safety: never touch files not bearing our AUTO-GENERATED header
      # (unless they don't exist yet)
      return { path: dest, status: :skipped_pinned } if File.exist?(dest) && !auto_generated?(dest)

      new_digest = Digest::SHA256.hexdigest(content)

      if File.exist?(dest)
        existing_digest = Digest::SHA256.hexdigest(File.read(dest, encoding: "utf-8"))
        return { path: dest, status: :unchanged } if existing_digest == new_digest
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
      rescue StandardError => e
        FileUtils.rm_f(tmp)
        raise e
      end

      { path: dest, status: :written }
    end

    def migrate_legacy_manifests!
      legacy_dir   = @config.abs_output_dir
      manifest_dir = @config.abs_manifest_dir
      return if legacy_dir == manifest_dir

      legacy_files = Dir.glob(File.join(legacy_dir, "ux_*.js"))
      return if legacy_files.empty?

      if @config.dry_run?
        legacy_files.each do |legacy|
          target = File.join(manifest_dir, File.basename(legacy))
          $stdout.puts "[ReactManifest] DRY-RUN: would move #{legacy} -> #{target}"
        end
        return
      end

      FileUtils.mkdir_p(manifest_dir)
      legacy_files.each do |legacy|
        target = File.join(manifest_dir, File.basename(legacy))
        if File.exist?(target)
          # Prevent double-definition conflicts: if a legacy root manifest is
          # auto-generated and a manifest-dir equivalent exists, drop the legacy file.
          FileUtils.rm_f(legacy) if auto_generated?(legacy)
          next
        end

        FileUtils.mv(legacy, target)
      end
    end

    # ----------------------------------------------------------- helpers

    def header_lines
      [
        format(HEADER, version: ReactManifest::VERSION),
        ""
      ].flatten
    end

    def js_files_in(dir)
      return [] unless Dir.exist?(dir)

      files = Dir.glob(File.join(dir, "**", @config.extensions_glob))
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
      # Strip Sprockets-understood extensions: .js.jsx/.jsx/.js -> logical path.
      rel.sub(/\.js\.jsx$/, "").sub(/\.jsx$/, "").sub(/\.js$/, "")
    end

    def extract_defined_symbols(file_path)
      content = File.read(file_path, encoding: "utf-8")
      symbols = []
      ReactManifest::Scanner::DEFINITION_PATTERNS.each do |pattern|
        content.scan(pattern) { |m| symbols << m[0] }
      end
      symbols.uniq
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
      []
    end

    def extract_used_component_symbols(file_path)
      content = File.read(file_path, encoding: "utf-8")

      # Collect locally-defined symbols to avoid self-reference false positives
      local_syms = Set.new
      ReactManifest::Scanner::DEFINITION_PATTERNS.each do |pattern|
        content.scan(pattern) { |m| local_syms << m[0] }
      end

      symbols = []
      content.scan(ReactManifest::Scanner::PASCAL_TOKEN_PATTERN) do |m|
        symbols << m[0] unless local_syms.include?(m[0])
      end
      content.scan(ReactManifest::Scanner::HOOK_TOKEN_PATTERN) do |m|
        symbols << m[0] unless local_syms.include?(m[0])
      end

      symbols.uniq
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
      []
    end

    def external_js_files_in(dir)
      return [] unless Dir.exist?(dir)

      Dir.glob(File.join(dir, "**", @config.extensions_glob))
         .reject { |f| File.directory?(f) }
         .reject { |f| excluded_path?(f) }
         .sort
    end

    def abs_external_root(path)
      return path if Pathname.new(path).absolute?

      Rails.root.join(path).to_s
    end

    def auto_generated?(path)
      # Avoid TOCTOU: don't check existence separately — just attempt the read
      # and treat a missing/unreadable file as not auto-generated.
      first_two = File.foreach(path).first(2).join
      first_two.include?("AUTO-GENERATED")
    rescue Errno::ENOENT, Errno::EACCES
      false
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
  # rubocop:enable Metrics/ClassLength
end
