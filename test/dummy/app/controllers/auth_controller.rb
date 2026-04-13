class AuthController < ApplicationController
  def login
  end

  def create
    redirect_to root_path
  end

  def register
  end

  def signup
    redirect_to root_path
  end

  def destroy
    redirect_to login_path
  end
end
