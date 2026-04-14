require "json"
require "zlib"

module ReactManifest
  # Reports per-bundle sizes by reading the Sprockets compiled manifest.
  #
  # Run after `rails assets:precompile` to see:
  #   Bundle                  Raw (KB)   Gzip (KB)
  #   ux_shared.js              420         130
  #   ux_notifications.js        95          31  ✓
  #   ux_reports.js             610         190  ⚠
  class Reporter
    def initialize(config = ReactManifest.configuration)
      @config = config
    end

    def report
      manifest = load_sprockets_manifest
      bundles  = collect_bundles(manifest)

      if bundles.empty?
        puts "[ReactManifest] No ux_*.js bundles found in compiled assets."
        puts "  Run `rails assets:precompile` first."
        return
      end

      print_table(bundles)
    end

    private

    def load_sprockets_manifest
      # Use Rails.public_path to respect non-default public directory config.
      public_assets = Rails.public_path.join("assets")
      manifest_file = Dir.glob(File.join(public_assets, ".sprockets-manifest-*.json")).first ||
                      Dir.glob(File.join(public_assets, "manifest-*.json")).first

      unless manifest_file && File.exist?(manifest_file)
        puts "[ReactManifest] Sprockets manifest not found under #{public_assets}."
        puts "  Run `rails assets:precompile` first."
        return {}
      end

      JSON.parse(File.read(manifest_file, encoding: "utf-8"))["assets"] || {}
    rescue JSON::ParserError => e
      puts "[ReactManifest] Could not parse Sprockets manifest: #{e.message}"
      {}
    end

    def collect_bundles(manifest)
      public_assets = Rails.public_path.join("assets").to_s
      bundles = []

      manifest.each do |logical_path, fingerprinted|
        next unless logical_path.match?(/\Aux_.*\.js\z/)

        abs_path  = File.join(public_assets, fingerprinted)
        gz_path   = "#{abs_path}.gz"

        next unless File.exist?(abs_path)

        raw_kb  = (File.size(abs_path) / 1024.0).round(1)
        gzip_kb = File.exist?(gz_path) ? (File.size(gz_path) / 1024.0).round(1) : nil

        bundles << {
          name: logical_path,
          raw_kb: raw_kb,
          gzip_kb: gzip_kb
        }
      end

      bundles.sort_by { |b| b[:name] }
    end

    def print_table(bundles)
      gzip_available = bundles.any? { |b| b[:gzip_kb] }

      puts "\n#{'Bundle'.ljust(35)} #{'Raw (KB)'.rjust(10)}#{"   #{'Gzip (KB)'.rjust(10)}" if gzip_available}"
      puts "-" * (gzip_available ? 62 : 48)

      bundles.each do |b|
        over_threshold = @config.size_threshold_kb.positive? && b[:raw_kb] > @config.size_threshold_kb
        flag           = over_threshold ? "  ⚠ exceeds #{@config.size_threshold_kb}KB threshold" : ""
        gzip_col       = gzip_available ? "   #{(b[:gzip_kb] || 'n/a').to_s.rjust(10)}" : ""

        puts "#{b[:name].ljust(35)} #{b[:raw_kb].to_s.rjust(10)}#{gzip_col}#{flag}"
      end

      unless gzip_available
        puts "\n  Note: gzip sizes unavailable. Ensure `config.assets.compress = true` in production."
      end

      puts "\n"
    end
  end
end
