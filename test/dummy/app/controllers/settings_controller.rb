class SettingsController < ApplicationController
  def show
  end

  def update
    redirect_to settings_path
  end
end
