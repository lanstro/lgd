class ActsController < ApplicationController
	
	before_action :admin_user,     only: [:new, :edit, :update, :create, :destroy]
	
  def new
		@act = Act.new
  end

	def create
		@act = Act.new(user_params)
    if @act.save
			flash[:success] = "New act created!"
      redirect_to @act
    else
      render 'new'
    end
	end
	
  def edit
		@act = Act.find(params[:id])
  end
	
	def index
		@acts=Act.paginate(page: params[:page])
	end
	
	def update
		@act = Act.find(params[:id])
    if @act.update_attributes(user_params)
			flash[:success] = "Act updated"
      redirect_to @act
    else
      render 'edit'
    end
	end

  def show
		@act = Act.find(params[:id])
  end

  def destroy
		Act.find(params[:id]).destroy
    flash[:success] = "Act deleted."
    redirect_to acts_url
  end
	
	def parse  ## make this admin only
		@act=Act.find(params[:id])
		@act.parse
		redirect_to @act
	end
	
	def reset_parsing ## make admin only
		@act=Act.find(params[:id])
		@act.containers.destroy_all
		redirect_to @act
	end
	
	def user_params
		params.require(:act).permit(:title, :subtitle, :year, :number, :act_type, :jurisdiction, :last_updated)
	end
	
end

