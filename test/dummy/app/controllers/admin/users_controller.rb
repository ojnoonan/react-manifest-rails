module Admin
  class UsersController < BaseController
    def index
    end

    def new
    end

    def create
      redirect_to admin_users_path
    end

    def edit
    end

    def update
      redirect_to admin_users_path
    end

    def destroy
      redirect_to admin_users_path
    end
  end
end
