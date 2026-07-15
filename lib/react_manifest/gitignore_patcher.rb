require "fileutils"

module ReactManifest
  # Ensures the generated manifest dir is gitignored and that a committed .keep
  # keeps the directory present on a fresh clone. Idempotent and best-effort:
  # a filesystem error logs a warning and never raises.
  class GitignorePatcher
    include ReactManifest::Logging

    Result = Struct.new(:appended, :keep_created, keyword_init: true)

    def initialize(config = ReactManifest.configuration)
      @config = config
    end

    def patch!
      Result.new(appended: ensure_gitignore_entry, keep_created: ensure_keep)
    end

    # Path (relative to Rails.root) that should be ignored, e.g.
    # "app/assets/javascripts/ux_manifests/*.js".
    def pattern
      subdir = @config.normalized_manifest_subdir
      base   = subdir.empty? ? @config.output_dir : File.join(@config.output_dir, subdir)
      File.join(base, "*.js")
    end

    private

    def gitignore_path
      Rails.root.join(".gitignore").to_s
    end

    def ensure_gitignore_entry
      path    = gitignore_path
      line    = pattern
      content = File.exist?(path) ? File.read(path, encoding: "utf-8") : ""
      return false if content.split("\n").map(&:strip).include?(line)

      prefix = content.empty? || content.end_with?("\n") ? "" : "\n"
      File.open(path, "a") { |f| f.write("#{prefix}#{line}\n") }
      log_info "Added #{line} to .gitignore"
      true
    rescue Errno::EACCES, Errno::ENOENT => e
      log_warn "Could not update .gitignore: #{e.message}"
      false
    end

    def ensure_keep
      dir  = @config.abs_manifest_dir
      keep = File.join(dir, ".keep")
      return false if File.exist?(keep)

      FileUtils.mkdir_p(dir)
      FileUtils.touch(keep)
      true
    rescue Errno::EACCES => e
      log_warn "Could not create #{dir}/.keep: #{e.message}"
      false
    end
  end
end
