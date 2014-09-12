class ContainersController < ApplicationController
	
	before_action :admin_user,     only: [:new, :edit, :update, :create, :destroy]
	
	def index
		@containers=Container.paginate(page: params[:page])
	end
	
  def new
		@container = Container.new
  end
	
	def create
		@container = Container.new(user_params)
		if @container.save
			flash[:success] = "New container created!"
			redirect_to @container
		else
			render 'new'
		end
	end

  def edit
		@container = Container.find_by(id: params[:id])
		@act = @container.act
  end
	
	def update
		@container = Container.find_by(id: params[:id])
		if @container.update_attributes(user_params)
			flash[:success] = "Section updated"
			redirect_to @container
		else
			render 'edit'
		end
	end

  def show
		@container = Container.find_by(id: params[:id])
		@act = @container.act
  end

  def destroy
		Container.find_by(id: params[:id]).destroy
    flash[:success] = "Container deleted."
    redirect_to containers_url
  end
	
	def user_params
		params.require(:container).permit(:number, :parent_id, :depth, :content, :special_paragraph)
	end
	
	
end
