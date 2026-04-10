module ReactManifest
  # Walks the ux/ directory tree and classifies subdirectories into:
  #   - controller_dirs: immediate subdirs of ux/app/ (each gets a ux_<name>.js)
  #   - shared_dirs:     everything else directly under ux/ (feeds ux_shared.js)
  #
  # No hard-coded dir names — anything that is not app_dir is shared.
  class TreeClassifier
    Result = Struct.new(:controller_dirs, :shared_dirs, keyword_init: true)

    def initialize(config = ReactManifest.configuration)
      @config = config
    end

    def classify
      controller_dirs = []
      shared_dirs     = []

      unless Dir.exist?(@config.abs_ux_root)
        warn "[ReactManifest] ux_root does not exist: #{@config.abs_ux_root}"
        return Result.new(controller_dirs: [], shared_dirs: [])
      end

      Dir.children(@config.abs_ux_root).sort.each do |entry|
        full_path = File.join(@config.abs_ux_root, entry)
        next unless File.directory?(full_path)

        if entry == @config.app_dir
          # Walk one level deeper — each subdir is a controller bundle
          Dir.children(full_path).sort.each do |ctrl_entry|
            ctrl_path = File.join(full_path, ctrl_entry)
            next unless File.directory?(ctrl_path)
            next if @config.ignore.include?(ctrl_entry)

            controller_dirs << {
              name: ctrl_entry,
              path: ctrl_path,
              bundle_name: "ux_#{ctrl_entry}"
            }
          end
        else
          # Any other top-level dir under ux/ is a shared dir
          shared_dirs << {
            name: entry,
            path: full_path
          }
        end
      end

      Result.new(controller_dirs: controller_dirs, shared_dirs: shared_dirs)
    end

    # All directories that should be watched for changes
    def watched_dirs
      result = classify
      dirs = [File.join(@config.abs_ux_root, @config.app_dir)]
      dirs += result.shared_dirs.map { |d| d[:path] }
      dirs.select { |d| Dir.exist?(d) }
    end
  end
end
