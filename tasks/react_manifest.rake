namespace :react_manifest do
  desc "Generate all ux_*.js Sprockets manifests from the ux/ directory tree"
  task generate: :environment do
    results = ReactManifest::Generator.new.run!

    written   = results.count { |r| r[:status] == :written }
    unchanged = results.count { |r| r[:status] == :unchanged }
    skipped   = results.count { |r| r[:status] == :skipped_pinned }
    dry       = results.count { |r| r[:status] == :dry_run }

    if ReactManifest.configuration.dry_run?
      puts "[ReactManifest] DRY-RUN complete: #{dry} manifest(s) would be written"
    else
      puts "[ReactManifest] Done: #{written} written, #{unchanged} unchanged, #{skipped} skipped"
    end

    # Print any scanner warnings
    results # warnings are printed inline by scanner via $stdout in verbose mode
  end

  desc "Print the JSX dependency map and warnings without writing any files"
  task analyze: :environment do
    config     = ReactManifest.configuration
    classifier = ReactManifest::TreeClassifier.new(config)
    scanner    = ReactManifest::Scanner.new(config)

    classification = classifier.classify
    scan_result    = scanner.scan(classification)
    dep_map        = ReactManifest::DependencyMap.new(scan_result)
    dep_map.print_report

    unless scan_result.warnings.empty?
      puts "Warnings (#{scan_result.warnings.size}):"
      scan_result.warnings.each { |w| puts "  ⚠  #{w}" }
      puts
    end
  end

  desc "Analyze application*.js files — show what migrate_application would change"
  task analyze_application: :environment do
    analyzer = ReactManifest::ApplicationAnalyzer.new
    results  = analyzer.analyze
    analyzer.print_report(results)
  end

  desc "Rewrite application*.js files to remove UX code (creates .bak backups)"
  task migrate_application: :environment do
    migrator = ReactManifest::ApplicationMigrator.new
    migrator.migrate!
  end

  desc "Print per-bundle raw and gzip sizes from compiled public/assets/"
  task report: :environment do
    ReactManifest::Reporter.new.report
  end

  desc "Remove all AUTO-GENERATED ux_*.js manifests"
  task clean: :environment do
    config    = ReactManifest.configuration
    output    = config.abs_output_dir
    removed   = 0
    skipped   = 0

    Dir.glob(File.join(output, "ux_*.js")).each do |file|
      first_line = File.foreach(file).first.to_s
      if first_line.include?("AUTO-GENERATED")
        File.delete(file)
        puts "[ReactManifest] Removed: #{file.sub("#{Rails.root}/", '')}"
        removed += 1
      else
        puts "[ReactManifest] Skipped (not auto-generated): #{file.sub("#{Rails.root}/", '')}"
        skipped += 1
      end
    end

    puts "[ReactManifest] Clean complete: #{removed} removed, #{skipped} skipped"
  end

  desc "Start the file watcher in the foreground (for debugging)"
  task watch: :environment do
    puts "[ReactManifest] Starting file watcher (Ctrl-C to stop)..."
    ReactManifest::Watcher.start(ReactManifest.configuration)
    # Block the process
    sleep
  rescue Interrupt
    ReactManifest::Watcher.stop
    puts "\n[ReactManifest] Watcher stopped."
  end
end
