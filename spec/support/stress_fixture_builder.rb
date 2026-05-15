require "fileutils"

module StressFixtureBuilder
  UX_ROOT    = "app/assets/javascripts/ux".freeze
  OUTPUT_DIR = "app/assets/javascripts".freeze

  def self.configure_for(_tmpdir)
    ReactManifest.configure do |c|
      c.ux_root         = UX_ROOT
      c.app_dir         = "app"
      c.output_dir      = OUTPUT_DIR
      c.manifest_subdir = "ux_manifests"
      c.dry_run         = false
      c.verbose         = false
    end
  end

  # Builds N controller dirs under ux/app/, each with `files_per_controller` source files.
  # Also creates a small set of shared components that controller files reference.
  def self.build_flat(tmpdir, controller_count: 100, files_per_controller: 3)
    shared_dir  = File.join(tmpdir, UX_ROOT, "components")
    app_dir     = File.join(tmpdir, UX_ROOT, "app")
    FileUtils.mkdir_p(shared_dir)
    FileUtils.mkdir_p(app_dir)

    shared_symbols = write_shared_components(shared_dir, count: 5)

    controller_count.times do |i|
      n    = i + 1
      ctrl = "ctrl_#{n}"
      dir  = File.join(app_dir, ctrl)
      FileUtils.mkdir_p(dir)

      files_per_controller.times do |j|
        sym = shared_symbols[j % shared_symbols.length]
        File.write(File.join(dir, "#{ctrl}_#{j}.js.jsx"), controller_file_content(sym))
      end
    end
  end

  # Builds 50 shared files × symbols_per_file each (500+ symbols total).
  # One controller to exercise the scan.
  def self.build_symbol_scale(tmpdir, shared_files: 50, symbols_per_file: 10)
    components_dir = File.join(tmpdir, UX_ROOT, "components")
    app_dir        = File.join(tmpdir, UX_ROOT, "app", "main")
    FileUtils.mkdir_p(components_dir)
    FileUtils.mkdir_p(app_dir)

    all_symbols = []
    shared_files.times do |fi|
      file_path = File.join(components_dir, "group_#{fi}.js.jsx")
      symbols   = symbols_per_file.times.map { |si| "Comp#{fi}X#{si}" }
      all_symbols.concat(symbols)
      File.write(file_path, symbols.map { |s| "const #{s} = (props) => null;" }.join("\n"))
    end

    File.write(File.join(app_dir, "main_index.js.jsx"), controller_file_content(all_symbols.first(3).join(", ")))
  end

  # Builds a three-level deep namespace: app/admin/reports/summary/
  def self.build_deep_nesting(tmpdir)
    shared_dir = File.join(tmpdir, UX_ROOT, "components")
    ctrl_dir   = File.join(tmpdir, UX_ROOT, "app", "admin", "reports", "summary")
    FileUtils.mkdir_p(shared_dir)
    FileUtils.mkdir_p(ctrl_dir)

    shared_symbols = write_shared_components(shared_dir, count: 3)
    File.write(File.join(ctrl_dir, "summary_index.js.jsx"), controller_file_content(shared_symbols.first))
    File.write(File.join(ctrl_dir, "summary_show.js.jsx"),  controller_file_content(shared_symbols.last))
  end

  private_class_method def self.write_shared_components(dir, count:)
    count.times.map do |i|
      sym = "SharedComp#{i}"
      File.write(File.join(dir, "shared_comp_#{i}.js.jsx"), "const #{sym} = (props) => null;")
      sym
    end
  end

  private_class_method def self.controller_file_content(symbol)
    "var Ctrl = function(props) { return React.createElement(#{symbol}, null); };"
  end
end
