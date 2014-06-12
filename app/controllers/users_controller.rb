class UsersController < ApplicationController
  def new
		@user=User.new
  end
  def create
    @user = User.new(user_params)    # Not the final implementation!
    if @user.save
			flash[:success] = "Welcome to my home, take a look around!"
      redirect_to @user
    else
      render 'new'
    end
  end
  def edit
  end
	
	def show
		@user = User.find(params[:id])
	end

  private

    def user_params
      params.require(:user).permit(:name, :email, :password,
                                   :password_confirmation)
    end
	
end
