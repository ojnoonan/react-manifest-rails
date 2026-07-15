require "digest"
require "tmpdir"
require_relative "path_utils"

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
  # Possible +status+ values: +:written+, +:unchanged+, +:skipped_pinned+, +:dry_run+,
  # +:removed_orphan+.
  #
  # Generates:
  #   ux_shared.js   — requires all files from shared dirs (components/, hooks/, lib/, etc.)
  #   ux_<ctrl>.js   — one per controller subdir, requires ux_shared + controller files
  #
  # All generated files carry the AUTO-GENERATED header and are idempotent
  # (skips write if content unchanged). Writes are atomic (temp-file + rename)
  # to avoid partial reads from concurrent processes.
  #
  # Manifests whose ux/app/<controller> dir no longer exists are removed
  # automatically (pinned files are never removed this way).
  #
  # Never touches application.js, application_dev.js, or files in exclude_paths.
  # rubocop:disable Metrics/ClassLength
  class Generator
    include PathUtils
    include ReactManifest::Logging

    HEADER = <<~JS.freeze
      // AUTO-GENERATED — DO NOT EDIT
      // Run `rails react_manifest:generate` to regenerate.
    JS

    def initialize(config = ReactManifest.configuration)
      @config     = config
      @classifier = TreeClassifier.new(config)
    end

    # After a run (or on demand), maps a promoted file's require path to the set of
    # bundle names that forced its promotion. Used by react_manifest:analyze.
    def promotion_reasons
      classification = @classifier.classify
      build_controller_context(classification.controller_dirs, classification.shared_dirs)
      @promotion_reasons || {}
    end

    # Run full generation. Returns array of {path:, status:} hashes.
    #
    # All manifest content is built first (no filesystem writes), then written
    # in a second pass so that a failure midway does not leave some bundles
    # written and others stale/missing.
    def run!
      classification = @classifier.classify
      controller_context = build_controller_context(classification.controller_dirs, classification.shared_dirs)

      # Phase 1: build all content in memory — no I/O.
      shared_manifest = build_shared(classification.shared_dirs, controller_context[:promoted_files])
      manifests = [shared_manifest] + classification.controller_dirs.map do |ctrl|
        build_controller(ctrl, controller_context)
      end

      migrate_legacy_manifests!

      # Phase 2: write — each write is atomic (tmp + rename).
      results = manifests.map { |m| write_manifest(m[:filename], m[:content]) }

      # Phase 3: remove manifests left behind by a controller dir that no
      # longer exists (renamed/deleted ux/app/<controller>). Never touches
      # pinned (non-AUTO-GENERATED) files.
      expected_filenames = manifests.map { |m| m[:filename] }
      results.concat(remove_orphaned_manifests(expected_filenames))

      print_summary(results) if @config.verbose?
      results
    end

    # Remove all AUTO-GENERATED ux_*.js manifests. Silently skips files that
    # disappear between the directory scan and the read (TOCTOU-safe).
    # Returns { removed: N, skipped: N }.
    def clean!
      targets  = [@config.abs_manifest_dir, @config.abs_output_dir].uniq
      removed  = 0
      skipped  = 0

      targets.each do |dir|
        Dir.glob(File.join(dir, "ux_*.js")).each do |file|
          if auto_generated?(file)
            File.delete(file)
            removed += 1
          else
            skipped += 1
          end
        end
      end

      { removed: removed, skipped: skipped }
    end

    private

    # ------------------------------------------------------------------ shared

    def build_shared(shared_dirs, promoted_files = Set.new)
      lines = header_lines
      reqs = (shared_dirs.flat_map { |d| js_files_in(d[:path]) } + promoted_files.to_a)
             .map { |f| normalize_require_path(relative_require_path(f)) }
             .uniq
             .sort

      if reqs.empty?
        lines << "// (no shared JS files found)"
      else
        reqs.each { |req| lines << "//= require #{req}" }
      end

      { filename: "#{@config.shared_bundle}.js", content: "#{lines.join("\n")}\n" }
    end

    # --------------------------------------------------------------- controller

    def build_controller(ctrl, controller_context)
      lines = header_lines
      promoted = controller_context[:promoted_files]
      always_include_reqs = controller_context[:always_include_requires].fetch(ctrl[:bundle_name], [])
      dep_requires = if @config.auto_shared?
                       []
                     else
                       controller_dependency_requires(ctrl[:bundle_name], controller_context)
                     end
      ext_reqs = controller_context[:external_requires].fetch(ctrl[:bundle_name], Set.new).to_a.sort

      files = js_files_in(ctrl[:path]).reject { |f| promoted.include?(f) }
      own_requires = files.map { |f| relative_require_path(f) }
      all_requires = (always_include_reqs + dep_requires + ext_reqs + own_requires).uniq

      if all_requires.empty?
        lines << "// (no JSX files found in #{ctrl[:name]}/)"
      else
        all_requires.each { |req| lines << "//= require #{req}" }
      end

      { filename: "#{ctrl[:bundle_name]}.js", content: "#{lines.join("\n")}\n" }
    end

    def build_controller_context(controller_dirs, shared_dirs)
      bundle_files, file_owner, file_defs, symbol_to_bundle, symbol_to_file, bundle_own_symbols =
        index_controller_symbols(controller_dirs)

      file_uses = Hash.new { |h, k| h[k] = Set.new }
      symbol_used_by_bundles = Hash.new { |h, k| h[k] = Set.new }
      record_symbol_usages(bundle_files, shared_dirs, file_uses, symbol_used_by_bundles)

      external_symbol_to_require = index_external_symbols(symbol_to_bundle)

      dependencies, external_requires = build_dependency_graph(
        bundle_files, bundle_own_symbols, file_uses, symbol_to_bundle, external_symbol_to_require
      )

      promoted_files =
        if @config.auto_shared?
          compute_promoted_files(file_owner, file_defs, file_uses,
                                 symbol_used_by_bundles, symbol_to_file)
        else
          Set.new
        end

      always_include_requires =
        build_always_include_requires(bundle_files, dependencies, promoted_files)

      {
        bundle_files: bundle_files,
        dependencies: dependencies,
        always_include_requires: always_include_requires,
        external_requires: external_requires,
        promoted_files: promoted_files
      }
    end

    # A controller file is promoted to the shared bundle when a symbol it defines
    # is used by any bundle other than its owner (another controller, an
    # always_include bundle, or a shared-dir file), then transitively for anything
    # a promoted file itself depends on. Guarantees each file is emitted once.
    # Also records, per promoted file, the set of bundle names that forced the
    # promotion (into @promotion_reasons) for react_manifest:analyze reporting.
    def compute_promoted_files(file_owner, file_defs, file_uses, symbol_used_by_bundles, symbol_to_file)
      promoted = Set.new
      reasons = Hash.new { |h, k| h[k] = Set.new }

      file_owner.each do |file_path, owner|
        forcing = Set.new
        file_defs[file_path].each do |sym|
          # The symbol_to_file[sym] == file_path guard (a) resolves symbol-name
          # collisions to the single canonical definer and (b) structurally
          # excludes isolated_app_dirs files, which are never registered in
          # symbol_to_file — so an isolated file can never be promoted here.
          next unless symbol_to_file[sym] == file_path

          (symbol_used_by_bundles[sym] - [owner]).each { |b| forcing << b }
        end
        next if forcing.empty?

        promoted << file_path
        reasons[relative_require_path(file_path)] = forcing
      end

      worklist = promoted.to_a
      until worklist.empty?
        current = worklist.pop
        file_uses.fetch(current, Set.new).each do |sym|
          dep_file = symbol_to_file[sym]
          next unless dep_file
          next if promoted.include?(dep_file)

          promoted << dep_file
          reasons[relative_require_path(dep_file)] << "(transitive)"
          worklist << dep_file
        end
      end

      @promotion_reasons = reasons.transform_values(&:to_a)
      promoted
    end

    # Indexes each controller dir's files and the PascalCase symbols they define.
    # Returns [bundle_files, file_owner, file_defs, symbol_to_bundle, symbol_to_file,
    # bundle_own_symbols].
    def index_controller_symbols(controller_dirs)
      bundle_files = {}
      file_owner = {}
      file_defs = Hash.new { |h, k| h[k] = Set.new }
      symbol_to_bundle = {}
      symbol_to_file = {}
      bundle_own_symbols = Hash.new { |h, k| h[k] = Set.new }

      controller_dirs.each do |ctrl|
        bundle_name = ctrl[:bundle_name]
        files = js_files_in(ctrl[:path])
        bundle_files[bundle_name] = files
        isolated = @config.isolated_app_dirs.include?(ctrl[:name])

        files.each do |file_path|
          file_owner[file_path] = bundle_name
          extract_defined_symbols(file_path).each do |sym|
            next unless sym.match?(/\A[A-Z][A-Za-z0-9_]*\z/)

            file_defs[file_path] << sym
            # Isolated dirs never register into the shared symbol index, so no
            # other bundle can ever be inferred to depend on them.
            unless isolated
              symbol_to_bundle[sym] ||= bundle_name
              symbol_to_file[sym]   ||= file_path
            end
            bundle_own_symbols[bundle_name] << sym
          end
        end
      end

      [bundle_files, file_owner, file_defs, symbol_to_bundle, symbol_to_file, bundle_own_symbols]
    end

    # Records, per controller file and per bundle, which symbols are used —
    # plus a pseudo-bundle entry (config.shared_bundle) for any controller
    # symbol referenced from a shared-dir file (shared code loads on every
    # page, so that symbol's owning file must be treated as externally used).
    def record_symbol_usages(bundle_files, shared_dirs, file_uses, symbol_used_by_bundles)
      bundle_files.each do |bundle_name, files|
        files.each do |file_path|
          extract_used_component_symbols(file_path).each do |sym|
            file_uses[file_path] << sym
            symbol_used_by_bundles[sym] << bundle_name
          end
        end
      end

      shared_dirs.each do |dir|
        js_files_in(dir[:path]).each do |file_path|
          extract_used_component_symbols(file_path).each do |sym|
            symbol_used_by_bundles[sym] << @config.shared_bundle
          end
        end
      end
    end

    # Indexes symbols from external_roots dirs, then lets explicit
    # external_providers win over scanned roots on symbol conflicts.
    def index_external_symbols(symbol_to_bundle)
      external_symbol_to_require = {}

      @config.external_roots.each do |root_path|
        abs_root = abs_external_root(root_path)
        external_js_files_in(abs_root).each do |file_path|
          req_path = relative_require_path(file_path)
          warn_on_external_controller_references(file_path, symbol_to_bundle)
          extract_defined_symbols(file_path).each do |sym|
            external_symbol_to_require[sym] ||= req_path
          end
        end
      end

      @config.external_providers.each do |sym, req_path|
        external_symbol_to_require[sym] = req_path
      end

      external_symbol_to_require
    end

    # Cross-app dependency graph + external requires (dependencies kept for
    # reporting). Returns [dependencies, external_requires].
    def build_dependency_graph(bundle_files, bundle_own_symbols, file_uses, symbol_to_bundle,
                               external_symbol_to_require)
      dependencies = Hash.new { |h, k| h[k] = Set.new }
      external_requires = Hash.new { |h, k| h[k] = Set.new }

      bundle_files.each do |bundle_name, files|
        own_symbols = bundle_own_symbols[bundle_name]
        files.each do |file_path|
          file_uses[file_path].each do |sym|
            next if own_symbols.include?(sym)

            dep_bundle = symbol_to_bundle[sym]
            dependencies[bundle_name] << dep_bundle if dep_bundle && dep_bundle != bundle_name

            req_path = external_symbol_to_require[sym]
            external_requires[bundle_name] << req_path if req_path
          end
        end
      end

      [dependencies, external_requires]
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

    def build_always_include_requires(bundle_files, dependencies, promoted_files)
      bundles = @config.always_include.map(&:to_s).reject(&:empty?).uniq
      return Hash.new { |h, k| h[k] = [] } if bundles.empty?

      requires_by_bundle = Hash.new { |h, k| h[k] = [] }

      bundle_files.each_key do |bundle_name|
        requires = Set.new

        bundles.each do |always_bundle|
          next if always_bundle == bundle_name

          transitive = [always_bundle] + transitive_dependencies(always_bundle, dependencies)
          transitive.each do |dep_bundle|
            bundle_files.fetch(dep_bundle, []).each do |abs_path|
              next if promoted_files.include?(abs_path)

              requires << relative_require_path(abs_path)
            end
          end
        end

        requires_by_bundle[bundle_name] = requires.to_a.sort
      end

      requires_by_bundle
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
        log_info "DRY-RUN: would write #{dest}"
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
          log_info "DRY-RUN: would move #{legacy} -> #{target}"
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

    # Remove AUTO-GENERATED manifests that no longer correspond to any
    # current shared/controller bundle (e.g. a ux/app/<controller> dir was
    # deleted or renamed). Skips pinned files and, in dry-run mode, only
    # logs what would be removed.
    def remove_orphaned_manifests(expected_filenames)
      Dir.glob(File.join(@config.abs_manifest_dir, "ux_*.js")).filter_map do |file|
        next if expected_filenames.include?(File.basename(file))
        next unless auto_generated?(file)

        if @config.dry_run?
          log_info "DRY-RUN: would remove orphaned manifest #{file}"
          { path: file, status: :dry_run }
        else
          File.delete(file)
          { path: file, status: :removed_orphan }
        end
      end
    end

    # ----------------------------------------------------------- helpers

    def header_lines
      [HEADER, ""]
    end

    def js_files_in(dir)
      return [] unless Dir.exist?(dir)

      files = Dir.glob(File.join(dir, "**", @config.extensions_glob))
                 .reject { |f| File.directory?(f) }
                 .reject { |f| auto_generated?(f) }
                 .reject { |f| @config.excluded_path?(f) }
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

    def relative_require_path(abs_path)
      # Build relative to output_dir (configurable) rather than a hardcoded path.
      base = @config.abs_output_dir + File::SEPARATOR
      rel  = abs_path.sub(base, "")
      strip_asset_extension(rel)
    end

    def extract_defined_symbols(file_path)
      content = File.read(file_path, encoding: "utf-8")
      SymbolExtractor.extract_definitions(content, file_path: file_path)
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
      []
    end

    def extract_used_component_symbols(file_path)
      content = File.read(file_path, encoding: "utf-8")
      SymbolExtractor.extract_usages(content, file_path: file_path)
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
      []
    end

    def external_js_files_in(dir)
      return [] unless Dir.exist?(dir)

      Dir.glob(File.join(dir, "**", @config.extensions_glob))
         .reject { |f| File.directory?(f) }
         .reject { |f| @config.excluded_path?(f) }
         .sort
    end

    def abs_external_root(path)
      return path if Pathname.new(path).absolute?

      Rails.root.join(path).to_s
    end

    def normalize_require_path(path)
      strip_asset_extension(path)
    end

    def warn_on_external_controller_references(file_path, symbol_to_bundle)
      extract_used_component_symbols(file_path).each do |sym|
        dep_bundle = symbol_to_bundle[sym]
        next unless dep_bundle

        log_warn "External file '#{relative_require_path(file_path)}' references " \
                 "controller-only symbol '#{sym}' (#{dep_bundle}). " \
                 "Move '#{sym}' to a shared ux dir to avoid duplicate runtime declarations."
      end
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

        removed.each { |l| log_info "  - #{l.chomp}" }
        added.each   { |l| log_info "  + #{l.chomp}" }
      else
        new_content.each_line { |l| log_info "  + #{l.chomp}" }
      end
    end

    def print_summary(results)
      counts = results.group_by { |r| r[:status] }.transform_values(&:count)
      log_info "Generated: #{counts[:written] || 0} written, " \
               "#{counts[:unchanged] || 0} unchanged, " \
               "#{counts[:skipped_pinned] || 0} skipped (not auto-generated), " \
               "#{counts[:removed_orphan] || 0} orphaned removed"
    end
  end
  # rubocop:enable Metrics/ClassLength
end
