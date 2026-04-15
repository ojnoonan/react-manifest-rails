module ReactManifest
  # Patches the Sprockets asset manifest (app/assets/config/manifest.js) to add a
  # `link_tree` directive for the ux_manifests directory.
  #
  # This is required so Sprockets knows to compile and serve the generated ux_*.js
  # bundle files. Without it, javascript_include_tag raises AssetNotPrecompiledError.
  #
  # Usage:
  #   ReactManifest::SprocketsManifestPatcher.new(config).patch!
  class SprocketsManifestPatcher
    MANIFEST_GLOB = "app/assets/config/manifest.js".freeze

    Result = Struct.new(:file, :status, :detail, keyword_init: true)

    def initialize(config = ReactManifest.configuration)
      @config = config
    end

    # Patch the Sprockets manifest file. Returns a Result.
    def patch!
      path = manifest_path
      unless path
        return Result.new(
          file: nil,
          status: :not_found,
          detail: "#{MANIFEST_GLOB} not found — create it and add //= link_tree ../javascripts/ux_manifests .js"
        )
      end

      content = File.read(path, encoding: "utf-8")
      directive = link_tree_directive

      if content.include?(directive.strip)
        return Result.new(file: path, status: :already_patched, detail: "link_tree directive already present")
      end

      new_content = append_directive(content, directive)

      if @config.dry_run?
        $stdout.puts "[ReactManifest] DRY-RUN: would patch #{short(path)}"
        $stdout.puts "  + #{directive.strip}"
        return Result.new(file: path, status: :dry_run, detail: nil)
      end

      File.write(path, new_content, encoding: "utf-8")
      $stdout.puts "[ReactManifest] Patched Sprockets manifest: #{short(path)}"
      Result.new(file: path, status: :patched, detail: nil)
    end

    # Returns the directive string that should be present.
    def link_tree_directive
      subdir = normalize_subdir
      "//= link_tree ../javascripts/#{subdir} .js\n"
    end

    # Returns true if the manifest file already contains the link_tree directive.
    def already_patched?
      path = manifest_path
      return false unless path

      File.read(path, encoding: "utf-8").include?(link_tree_directive.strip)
    rescue Errno::ENOENT, Errno::EACCES
      false
    end

    private

    def manifest_path
      candidate = Rails.root.join(MANIFEST_GLOB).to_s
      File.exist?(candidate) ? candidate : nil
    end

    def normalize_subdir
      # Strip leading/trailing slashes from manifest_subdir for path safety.
      @config.manifest_subdir.to_s.gsub(%r{^/+|/+$}, "")
    end

    def append_directive(content, directive)
      # Insert after last //= line for clean ordering.
      lines = content.lines
      last_directive_idx = lines.rindex { |l| l.strip.start_with?("//=") }

      if last_directive_idx
        new_lines = lines.dup
        new_lines.insert(last_directive_idx + 1, directive)
        new_lines.join
      else
        content + directive
      end
    end

    def short(path)
      path.to_s.sub("#{Rails.root}/", "")
    end
  end
end
