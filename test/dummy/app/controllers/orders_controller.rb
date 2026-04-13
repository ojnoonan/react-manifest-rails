class OrdersController < ApplicationController
  def index
  end

  def show
  end

  def new
  end

  def create
    redirect_to orders_path
  end
end
