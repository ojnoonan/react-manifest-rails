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
      bundle_name = ctrl[:bundle_name]
      # always_include bundles are NOT inlined here: resolve_bundles /
      # react_component deliver them on every page via their own <script> tag,
      # so inlining would load the same file twice and double-declare.
      dep_requires = if @config.auto_shared?
                       promoted_aware_dependency_requires(bundle_name, controller_context)
                     else
                       controller_dependency_requires(bundle_name, controller_context)
                     end
      ext_reqs = controller_context[:external_requires].fetch(bundle_name, Set.new).to_a.sort

      files = js_files_in(ctrl[:path]).reject { |f| promoted.include?(f) }
      own_requires = files.map { |f| relative_require_path(f) }
      all_requires = (dep_requires + ext_reqs + own_requires).uniq

      if all_requires.empty?
        lines << "// (no JSX files found in #{ctrl[:name]}/)"
      else
        all_requires.each { |req| lines << "//= require #{req}" }
      end

      { filename: "#{ctrl[:bundle_name]}.js", content: "#{lines.join("\n")}\n" }
    end

    def build_controller_context(controller_dirs, shared_dirs)
      bundle_files, file_owner, file_defs, symbol_to_bundle, symbol_to_file,
      symbol_definers, bundle_own_symbols = index_controller_symbols(controller_dirs)

      file_uses = Hash.new { |h, k| h[k] = Set.new }
      symbol_used_by_bundles = Hash.new { |h, k| h[k] = Set.new }
      record_symbol_usages(bundle_files, shared_dirs, file_uses, symbol_used_by_bundles)

      collided = symbol_definers.each_with_object(Set.new) do |(sym, files), acc|
        acc << sym if files.size >= 2
      end

      external_symbol_to_require = index_external_symbols(symbol_to_bundle)

      dependencies, external_requires = build_dependency_graph(
        bundle_files, bundle_own_symbols, file_uses, symbol_to_bundle, external_symbol_to_require
      )

      symbol_index = {
        file_defs: file_defs,
        symbol_to_file: symbol_to_file,
        symbol_used_by_bundles: symbol_used_by_bundles
      }
      promoted_files =
        if @config.auto_shared?
          compute_promoted_files(file_owner, file_uses, symbol_index, collided)
        else
          Set.new
        end

      context = {
        bundle_files: bundle_files,
        dependencies: dependencies,
        external_requires: external_requires,
        promoted_files: promoted_files,
        file_uses: file_uses,
        symbol_to_file: symbol_to_file,
        bundle_own_symbols: bundle_own_symbols
      }

      # Bundles guaranteed loaded on every page by always_include (used to exclude
      # them from the legacy whole-bundle inline path and to self-exclude an
      # always_include bundle's own manifest from the skip below).
      context[:always_loaded_bundles] = compute_always_loaded_bundles(dependencies)
      # Symbols actually delivered on every page by the always_include <script>
      # tag(s) — derived from the real files those tags carry, NOT from whole dep
      # bundles (which would over-claim symbols the tag does not load and cause a
      # consumer to skip a definer it still needs). Unused by the legacy path.
      context[:always_provided_symbols] =
        @config.auto_shared? ? compute_always_provided_symbols(context, file_defs) : Set.new

      warn_on_always_include_collisions(context, file_owner, file_defs, collided)

      context
    end

    # Surface the one case dependency arithmetic cannot resolve: an always_include
    # bundle that CONSUMES a collided symbol. Its tag inlines the first-writer
    # definer file, which also lives in that file's own bundle manifest — so on the
    # definer's own page the file loads twice (once via the always_include tag,
    # once via the owning bundle), a duplicate declaration. We cannot auto-fix it
    # (there is no collision-free page-global home for a collided symbol), so we
    # warn with the actionable fix: rename or relocate the symbol.
    def warn_on_always_include_collisions(context, file_owner, file_defs, collided)
      return if collided.empty?

      bundles = @config.always_include.map(&:to_s).reject(&:empty?).uniq
      bundles.each do |always_bundle|
        always_include_foreign_files(always_bundle, context).each do |file|
          owner = file_owner[file]
          next if owner.nil? || owner == always_bundle

          collided_syms = (file_defs.fetch(file, Set.new) & collided).to_a.sort
          next if collided_syms.empty?

          plural = collided_syms.size > 1 ? "s" : ""
          log_warn "always_include bundle '#{always_bundle}' pulls in " \
                   "'#{relative_require_path(file)}' (defines collided symbol#{plural} " \
                   "#{collided_syms.join(', ')}) owned by '#{owner}'. On #{owner}'s own page " \
                   "that file loads twice — once via the #{always_bundle} tag and once via " \
                   "#{owner} — causing a duplicate declaration. Rename the symbol or move it " \
                   "to a uniquely-named shared component."
        end
      end
    end

    # Files an always_include bundle's tag delivers from OTHER bundles: under
    # auto_shared, the exact non-promoted dependency files it inlines; in legacy
    # mode, every file of the dependency bundles it inlines wholesale.
    def always_include_foreign_files(always_bundle, context)
      if @config.auto_shared?
        promoted_aware_dependency_files(always_bundle, context, Set.new)
      else
        transitive_dependencies(always_bundle, context[:dependencies])
          .flat_map { |dep| context[:bundle_files].fetch(dep, []) }
      end
    end

    # Symbols the always_include tag(s) put on every page: for each always_include
    # bundle, the symbols defined by its own non-promoted files plus the canonical
    # dependency files it inlines (its manifest's exact file closure).
    def compute_always_provided_symbols(context, file_defs)
      bundles = @config.always_include.map(&:to_s).reject(&:empty?).uniq
      return Set.new if bundles.empty?

      always_files = Set.new
      bundles.each do |b|
        context[:bundle_files].fetch(b, []).each do |file|
          always_files << file unless context[:promoted_files].include?(file)
        end
        promoted_aware_dependency_files(b, context, Set.new).each { |file| always_files << file }
      end

      always_files.each_with_object(Set.new) { |file, syms| syms.merge(file_defs.fetch(file, Set.new)) }
    end

    # Files that can never be promoted to ux_shared: any file defining a "collided"
    # symbol (a name with 2+ app-dir definers — promoting one copy into the always-
    # loaded shared bundle would double-declare against the other copy on its page),
    # plus any file that transitively depends on such a file (it can't live in shared
    # if a dependency can't). These fall back to legacy per-consumer inlining.
    def unpromotable_files(file_owner, file_defs, file_uses, symbol_to_file, collided)
      unpromotable = Set.new
      file_owner.each_key do |file_path|
        unpromotable << file_path if file_defs[file_path].any? { |s| collided.include?(s) }
      end

      loop do
        added = false
        file_owner.each_key do |file_path|
          next if unpromotable.include?(file_path)

          taints = file_uses.fetch(file_path, Set.new).any? do |sym|
            dep = symbol_to_file[sym]
            dep && unpromotable.include?(dep)
          end
          if taints
            unpromotable << file_path
            added = true
          end
        end
        break unless added
      end

      unpromotable
    end

    # A controller file is promoted to the shared bundle when a symbol it canonically
    # defines is used by a bundle other than its owner, then transitively for anything
    # a promoted file depends on. Collided/tainted files (see unpromotable_files) are
    # never promoted. Records why each file was promoted for react_manifest:analyze.
    #
    # symbol_index bundles {file_defs:, symbol_to_file:, symbol_used_by_bundles:} into
    # one param so this stays under Metrics/ParameterLists (rubocop flags 6 positional
    # args) without changing the underlying algorithm.
    def compute_promoted_files(file_owner, file_uses, symbol_index, collided)
      file_defs = symbol_index[:file_defs]
      symbol_to_file = symbol_index[:symbol_to_file]
      symbol_used_by_bundles = symbol_index[:symbol_used_by_bundles]
      unpromotable = unpromotable_files(file_owner, file_defs, file_uses, symbol_to_file, collided)
      promoted = Set.new
      reasons = Hash.new { |h, k| h[k] = Set.new }

      file_owner.each do |file_path, owner|
        next if unpromotable.include?(file_path)

        forcing = Set.new
        file_defs[file_path].each do |sym|
          # canonical-definer guard: only the file that canonically defines the
          # symbol is eligible (resolves collisions to one file; excludes isolated
          # dirs, which are never registered in symbol_to_file).
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
          next if unpromotable.include?(dep_file)
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
    # symbol_definers, bundle_own_symbols].
    def index_controller_symbols(controller_dirs)
      bundle_files = {}
      file_owner = {}
      file_defs = Hash.new { |h, k| h[k] = Set.new }
      symbol_to_bundle = {}
      symbol_to_file = {}
      symbol_definers = Hash.new { |h, k| h[k] = Set.new }
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
              symbol_definers[sym] << file_path
            end
            bundle_own_symbols[bundle_name] << sym
          end
        end
      end

      [bundle_files, file_owner, file_defs, symbol_to_bundle, symbol_to_file,
       symbol_definers, bundle_own_symbols]
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

    # Under auto_shared, single-definer cross-used files live in ux_shared, so a
    # controller only needs the canonical files for the symbols it uses that are NOT
    # promoted (collided names kept bundle-local, plus their transitive needs).
    # File-level + transitive so we never over-inline a whole dependency bundle
    # (which could double-declare against an always_include bundle's own copy).
    def promoted_aware_dependency_requires(bundle_name, controller_context)
      # Symbols already on every page via an always_include tag. Skipped so a
      # controller never inlines a (possibly colliding) second definer. Disabled
      # when building an always_include bundle's own manifest (it needs its deps).
      always_provided = always_provided_for(bundle_name, controller_context)
      promoted_aware_dependency_files(bundle_name, controller_context, always_provided)
        .map { |f| relative_require_path(f) }
        .uniq
        .sort
    end

    # Absolute paths of the non-promoted files a bundle must inline: for each
    # symbol it uses (transitively) that is neither its own, promoted to shared,
    # nor +always_provided+ on the page, the canonical (first-writer) definer file.
    def promoted_aware_dependency_files(bundle_name, controller_context, always_provided)
      own       = controller_context[:bundle_own_symbols].fetch(bundle_name, Set.new)
      promoted  = controller_context[:promoted_files]
      file_uses = controller_context[:file_uses]
      sym2file  = controller_context[:symbol_to_file]
      own_files = controller_context[:bundle_files].fetch(bundle_name, [])

      needed = Set.new
      seen   = Set.new
      worklist = own_files.flat_map { |f| file_uses.fetch(f, Set.new).to_a }

      until worklist.empty?
        sym = worklist.pop
        next if seen.include?(sym)

        seen << sym
        next if own.include?(sym)
        next if always_provided.include?(sym)

        dep_file = sym2file[sym]
        next unless dep_file
        next if promoted.include?(dep_file) # already served by ux_shared
        next if own_files.include?(dep_file) # own file, added via own_requires
        next if needed.include?(dep_file)

        needed << dep_file
        file_uses.fetch(dep_file, Set.new).each { |s| worklist << s unless seen.include?(s) }
      end

      needed
    end

    def controller_dependency_requires(bundle_name, controller_context)
      deps = transitive_dependencies(bundle_name, controller_context[:dependencies])
      # Drop always_include bundles (and their transitive deps): they load on
      # every page via their own <script> tag, so inlining them here would
      # double-declare. Kept when the current bundle IS an always_include bundle.
      always = controller_context[:always_loaded_bundles]
      deps -= always.to_a unless always.include?(bundle_name)
      deps.flat_map { |dep_bundle| controller_context[:bundle_files].fetch(dep_bundle, []) }
          .map { |abs_path| relative_require_path(abs_path) }
          .uniq
          .sort
    end

    # Symbols delivered on every page by an always_include tag, for +bundle_name+.
    # Empty when building an always_include bundle's own manifest so it still
    # inlines the dependencies it needs.
    def always_provided_for(bundle_name, controller_context)
      return Set.new if controller_context[:always_loaded_bundles].include?(bundle_name)

      controller_context[:always_provided_symbols]
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

    # The set of bundles guaranteed loaded on every page by always_include: each
    # configured always_include bundle plus its transitive dependencies. These
    # arrive via their own <script> tag (resolve_bundles / react_component), so
    # controller manifests must never inline their files or symbols.
    def compute_always_loaded_bundles(dependencies)
      bundles = @config.always_include.map(&:to_s).reject(&:empty?).uniq
      bundles.each_with_object(Set.new) do |always_bundle, acc|
        acc << always_bundle
        transitive_dependencies(always_bundle, dependencies).each { |dep| acc << dep }
      end
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
