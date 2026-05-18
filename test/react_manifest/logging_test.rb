require "test_helper"

class LoggingTest < Minitest::Test
  def setup
    ReactManifest.configure { |c| c.stdout_logging = false }
    @host_class = Class.new { include ReactManifest::Logging }
    @host = @host_class.new
  end

  def teardown
    ReactManifest.reset!
  end

  def test_log_info_delegates_to_rails_logger_info_with_prefix
    Rails.logger.expects(:info).with("[ReactManifest] started")
    @host.log_info("started")
  end

  def test_log_info_also_writes_to_stdout_when_stdout_logging_enabled
    ReactManifest.configure { |c| c.stdout_logging = true }
    $stdout.expects(:puts).with("[ReactManifest] started")
    @host.log_info("started")
  end

  def test_log_info_does_not_write_to_stdout_when_stdout_logging_disabled
    $stdout.expects(:puts).never
    @host.log_info("started")
  end

  def test_log_debug_delegates_to_rails_logger_debug_with_prefix
    Rails.logger.expects(:debug).with("[ReactManifest] verbose detail")
    @host.log_debug("verbose detail")
  end

  def test_log_debug_does_not_write_to_stdout_when_stdout_logging_disabled
    $stdout.expects(:puts).never
    @host.log_debug("verbose detail")
  end

  def test_log_warn_delegates_to_rails_logger_warn_with_prefix
    Rails.logger.expects(:warn).with("[ReactManifest] uh oh")
    @host.log_warn("uh oh")
  end

  def test_log_warn_also_writes_to_stdout_when_stdout_logging_enabled
    ReactManifest.configure { |c| c.stdout_logging = true }
    $stdout.expects(:puts).with("[ReactManifest] uh oh")
    @host.log_warn("uh oh")
  end
end
