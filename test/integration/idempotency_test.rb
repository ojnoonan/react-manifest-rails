require "test_helper"

class IdempotencyTest < ReactManifestTest
  def setup
    super
    @config = ReactManifest.configuration
    @generator = ReactManifest::Generator.new(@config)
  end

  def test_second_run_reports_all_manifests_as_unchanged
    @generator.run!
    results = @generator.run!
    unchanged = results.select { |r| r[:status] == :unchanged }
    assert_equal results.length, unchanged.length
  end

  def test_second_run_does_not_rewrite_any_files
    @generator.run!
    mtimes_before = Dir.glob(File.join(@config.abs_manifest_dir, "ux_*.js"))
                       .to_h { |f| [f, File.mtime(f)] }
    sleep 0.01
    @generator.run!
    mtimes_after = Dir.glob(File.join(@config.abs_manifest_dir, "ux_*.js"))
                      .to_h { |f| [f, File.mtime(f)] }

    mtimes_before.each do |path, mtime|
      assert_equal mtime, mtimes_after[path], "#{File.basename(path)} was rewritten on second run"
    end
  end

  def test_second_run_produces_identical_file_content
    @generator.run!
    contents_before = Dir.glob(File.join(@config.abs_manifest_dir, "ux_*.js"))
                         .to_h { |f| [File.basename(f), File.read(f)] }
    @generator.run!
    contents_after = Dir.glob(File.join(@config.abs_manifest_dir, "ux_*.js"))
                        .to_h { |f| [File.basename(f), File.read(f)] }

    assert_equal contents_before, contents_after
  end
end
