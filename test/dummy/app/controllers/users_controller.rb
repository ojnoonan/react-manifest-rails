class UsersController < ApplicationController
  def index
  end

  def show
  end

  def edit
  end

  def new
  end

  def create
    redirect_to users_path
  end

  def update
    redirect_to user_path(params[:id])
  end

  def destroy
    redirect_to users_path
  end
end
