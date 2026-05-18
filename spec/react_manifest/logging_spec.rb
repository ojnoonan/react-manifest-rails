require "spec_helper"

RSpec.describe ReactManifest::Logging do
  let(:host_class) do
    Class.new { include ReactManifest::Logging }
  end
  let(:host) { host_class.new }

  before do
    allow(Rails.logger).to receive(:debug)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
  end

  describe "#log_info" do
    it "delegates to Rails.logger.info with [ReactManifest] prefix" do
      host.log_info("started")
      expect(Rails.logger).to have_received(:info).with("[ReactManifest] started")
    end

    context "when stdout_logging is enabled" do
      before { ReactManifest.configure { |c| c.stdout_logging = true } }

      it "also writes to $stdout" do
        expect($stdout).to receive(:puts).with("[ReactManifest] started")
        host.log_info("started")
      end
    end

    context "when stdout_logging is disabled" do
      before { ReactManifest.configure { |c| c.stdout_logging = false } }

      it "does not write to $stdout" do
        expect($stdout).not_to receive(:puts)
        host.log_info("started")
      end
    end
  end

  describe "#log_debug" do
    it "delegates to Rails.logger.debug with [ReactManifest] prefix" do
      host.log_debug("verbose detail")
      expect(Rails.logger).to have_received(:debug).with("[ReactManifest] verbose detail")
    end

    context "when stdout_logging is disabled" do
      before { ReactManifest.configure { |c| c.stdout_logging = false } }

      it "does not write to $stdout" do
        expect($stdout).not_to receive(:puts)
        host.log_debug("verbose detail")
      end
    end
  end

  describe "#log_warn" do
    it "delegates to Rails.logger.warn with [ReactManifest] prefix" do
      host.log_warn("uh oh")
      expect(Rails.logger).to have_received(:warn).with("[ReactManifest] uh oh")
    end

    context "when stdout_logging is enabled" do
      before { ReactManifest.configure { |c| c.stdout_logging = true } }

      it "also writes to $stdout" do
        expect($stdout).to receive(:puts).with("[ReactManifest] uh oh")
        host.log_warn("uh oh")
      end
    end
  end
end
