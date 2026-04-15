namespace :react_manifest do
  desc "One-step setup: patch application.js, layout files, then generate manifests"
  task setup: :environment do
    dry = ENV["DRY_RUN"].to_s =~ /\A(1|true|yes)\z/i || ReactManifest.configuration.dry_run?
    ReactManifest.configure { |c| c.dry_run = true } if dry

    config = ReactManifest.configuration

    puts ""
    puts "=== react-manifest-rails setup ==="
    puts "(DRY-RUN — no files will be written)\n" if config.dry_run?
    puts ""

    # 1. Confirm ux_root exists
    puts "1) Checking ux_root..."
    unless Dir.exist?(config.abs_ux_root)
      puts "   ! Not found: #{config.ux_root}"
      puts "   Create #{config.ux_root}/app/<controller>/ with your JSX files, then re-run."
      puts ""
      next
    end
    puts "   ✓ #{config.ux_root} found"

    # 2. Patch application.js (remove ux requires, keep vendor)
    puts "\n2) Patching application.js..."
    migrator = ReactManifest::ApplicationMigrator.new(config)
    mig_results = migrator.migrate!
    if mig_results.empty?
      puts "   No application*.js files found — nothing to migrate."
    else
      mig_results.each do |r|
        case r[:status]
        when :already_clean then puts "   ✓ #{r[:file].sub("#{Rails.root}/", '')} — already clean"
        when :migrated      then puts "   ✓ #{r[:file].sub("#{Rails.root}/", '')} — migrated (backup at .bak)"
        when :dry_run       then puts "   ~ #{r[:file].sub("#{Rails.root}/", '')} — (dry-run preview above)"
        when :backup_failed then puts "   ✗ #{r[:file].sub("#{Rails.root}/", '')} — backup failed: #{r[:error]}"
        end
      end
    end

    # 3. Patch Sprockets manifest.js (add link_tree for ux_manifests)
    puts "\n3) Patching Sprockets asset manifest..."
    sm_glob = ReactManifest::SprocketsManifestPatcher::MANIFEST_GLOB
    sm_result = ReactManifest::SprocketsManifestPatcher.new(config).patch!
    case sm_result.status
    when :patched         then puts "   ✓ #{sm_result.file.sub("#{Rails.root}/", '')}"
    when :already_patched then puts "   ✓ #{sm_glob} — already has link_tree"
    when :dry_run         then puts "   ~ #{sm_glob} — (dry-run preview above)"
    when :not_found       then puts "   ! #{sm_result.detail}"
    end

    # 4. Patch layout files (insert react_bundle_tag)
    puts "\n4) Patching layout files..."
    patcher = ReactManifest::LayoutPatcher.new(config)
    patch_results = patcher.patch!
    if patch_results.empty?
      puts "   No layout files found."
      puts "   Add <%= react_bundle_tag defer: true %> to your layout manually."
    else
      patch_results.each do |r|
        case r.status
        when :patched           then puts "   ✓ #{r.file.sub("#{Rails.root}/", '')}"
        when :already_patched   then puts "   ✓ #{r.file.sub("#{Rails.root}/", '')} — already has react_bundle_tag"
        when :dry_run           then puts "   ~ #{r.file.sub("#{Rails.root}/", '')} — (dry-run preview above)"
        when :no_injection_point then puts "   ! #{r.file.sub("#{Rails.root}/", '')} — #{r.detail}"
        end
      end
    end

    # 5. Generate manifests
    puts "\n5) Generating ux_*.js manifests..."
    gen_results = ReactManifest::Generator.new(config).run!
    written   = gen_results.count { |r| r[:status] == :written }
    unchanged = gen_results.count { |r| r[:status] == :unchanged }
    dry_count = gen_results.count { |r| r[:status] == :dry_run }

    if config.dry_run?
      puts "   ~ #{dry_count} manifest(s) would be written"
    else
      puts "   ✓ #{written} written, #{unchanged} unchanged"
    end

    # Done
    puts "\n=== Setup #{'(dry-run) ' if config.dry_run?}complete ==="
    puts "Start your Rails server — react_bundle_tag will serve the right JS per controller." unless config.dry_run?
    puts ""
  end

  desc "Generate all ux_*.js Sprockets manifests from the ux/ directory tree"
  task generate: :environment do
    config = ReactManifest.configuration

    unless Dir.exist?(config.abs_ux_root)
      puts "[ReactManifest] ux_root not found: #{config.abs_ux_root}"
      puts "[ReactManifest] Create it (for example: app/assets/javascripts/ux) then run this task again."
      next
    end

    results = ReactManifest::Generator.new(config).run!

    written   = results.count { |r| r[:status] == :written }
    unchanged = results.count { |r| r[:status] == :unchanged }
    skipped   = results.count { |r| r[:status] == :skipped_pinned }
    dry       = results.count { |r| r[:status] == :dry_run }

    if ReactManifest.configuration.dry_run?
      puts "[ReactManifest] DRY-RUN complete: #{dry} manifest(s) would be written"
    else
      puts "[ReactManifest] Done: #{written} written, #{unchanged} unchanged, #{skipped} skipped"
      if (written + unchanged + skipped).zero?
        puts "[ReactManifest] No manifests generated. Ensure ux/app/<controller>/ contains .js or .jsx files."
      end
    end

    # Print any scanner warnings # warnings are printed inline by scanner via $stdout in verbose mode

    unless ReactManifest::SprocketsManifestPatcher.new(config).already_patched?
      puts "[ReactManifest] NOTICE: app/assets/config/manifest.js is missing the link_tree directive."
      puts "[ReactManifest] Run `rails react_manifest:setup` to add it automatically."
    end
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
    targets   = [config.abs_manifest_dir, config.abs_output_dir].uniq
    removed   = 0
    skipped   = 0

    targets.each do |dir|
      Dir.glob(File.join(dir, "ux_*.js")).each do |file|
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
