require "digest"
require "json"
require "set"

module ReactManifest
  # The component-symbol -> bundle maps behind react_component bundle resolution.
  #
  # Parsing ux/app needs a V8 context (tens of MB per process), so the generator
  # writes the maps to a JSON sidecar next to the generated manifests and the
  # runtime loads that instead. The sidecar carries a fingerprint of everything the
  # maps are derived from (gem version, config, controller dirs, file paths and
  # contents); a missing, unreadable or mismatching sidecar falls back to parsing.
  module ComponentIndex
    FILENAME = "component_index.json".freeze

    module_function

    def path(config)
      File.join(config.abs_manifest_dir, FILENAME)
    end

    # Sidecar maps when fresh, else freshly parsed ones.
    def maps(config)
      controller_dirs = TreeClassifier.new(config).classify.controller_dirs
      load_fresh(config, controller_dirs) || build(config, controller_dirs)
    end

    # Write the sidecar (skipped when unchanged). Returns the path.
    def write!(config, controller_dirs)
      dest = path(config)
      json = JSON.generate(serialize(config, controller_dirs, build(config, controller_dirs)))
      return dest if File.exist?(dest) && File.read(dest, encoding: "utf-8") == json

      FileUtils.mkdir_p(File.dirname(dest))
      File.write(dest, json, encoding: "utf-8")
      dest
    end

    def build(config, controller_dirs)
      symbol_to_bundle = {}
      bundle_own_symbols = Hash.new { |h, k| h[k] = Set.new }
      bundle_files = Hash.new { |h, k| h[k] = [] }
      bundle_dependencies = Hash.new { |h, k| h[k] = Set.new }

      controller_dirs.each do |ctrl|
        bundle_name = ctrl[:bundle_name]
        files = js_files_in_controller(ctrl[:path], config)
        bundle_files[bundle_name].concat(files)
        isolated = config.isolated_app_dirs.include?(ctrl[:name])

        files.each do |file_path|
          extract(file_path, :extract_definitions).each do |symbol|
            next unless symbol.match?(/\A[A-Z][A-Za-z0-9_]*\z/)

            # Keep first writer to ensure deterministic behavior if a symbol is duplicated.
            # Isolated dirs never register into the shared symbol index (see
            # Generator#build_controller_context for the full rationale).
            symbol_to_bundle[symbol] ||= bundle_name unless isolated
            bundle_own_symbols[bundle_name] << symbol
          end
        end
      end

      bundle_files.each do |bundle_name, files|
        own_symbols = bundle_own_symbols[bundle_name]

        files.each do |file_path|
          extract(file_path, :extract_usages).each do |symbol|
            # A symbol the bundle defines itself is always satisfied locally —
            # never attribute it to another bundle just because that symbol
            # name happens to collide with something defined elsewhere.
            next if own_symbols.include?(symbol)

            dep_bundle = symbol_to_bundle[symbol]
            next unless dep_bundle && dep_bundle != bundle_name

            bundle_dependencies[bundle_name] << dep_bundle
          end
        end
      end

      { symbol_to_bundle: symbol_to_bundle, bundle_dependencies: bundle_dependencies }
    end

    def load_fresh(config, controller_dirs)
      data = JSON.parse(File.read(path(config), encoding: "utf-8"))
      return unless data["fingerprint"] == fingerprint(config, controller_dirs)

      bundle_dependencies = Hash.new { |h, k| h[k] = Set.new }
      data["bundle_dependencies"].each { |bundle, deps| bundle_dependencies[bundle] = deps.to_set }
      { symbol_to_bundle: data["symbol_to_bundle"], bundle_dependencies: bundle_dependencies }
    rescue StandardError
      nil
    end

    def serialize(config, controller_dirs, maps)
      {
        "fingerprint" => fingerprint(config, controller_dirs),
        "symbol_to_bundle" => maps[:symbol_to_bundle],
        "bundle_dependencies" => maps[:bundle_dependencies].transform_values { |deps| deps.to_a.sort }
      }
    end

    # Digest of every input the maps depend on. File paths are relative to ux_root so
    # a relocated release dir stays valid; contents (not mtimes) so a checkout that
    # rewrites timestamps cannot make a stale sidecar look fresh or a fresh one stale.
    def fingerprint(config, controller_dirs)
      digest = Digest::SHA256.new
      digest << JSON.generate([VERSION, config.extensions, config.isolated_app_dirs])
      controller_dirs.each do |ctrl|
        digest << "\0" << ctrl[:bundle_name]
        js_files_in_controller(ctrl[:path], config).each do |file|
          digest << "\0" << file.delete_prefix(config.abs_ux_root) << "\0" << File.binread(file)
        rescue SystemCallError
          digest << "\0unreadable"
        end
      end
      digest.hexdigest
    end

    def js_files_in_controller(dir, config)
      return [] unless Dir.exist?(dir)

      Dir.glob(File.join(dir, "**", config.extensions_glob))
         .reject { |f| File.directory?(f) }
         .sort
    end

    def extract(file_path, method)
      content = File.read(file_path, encoding: "utf-8")
      SymbolExtractor.public_send(method, content, file_path: file_path)
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError
      []
    end
  end
end
