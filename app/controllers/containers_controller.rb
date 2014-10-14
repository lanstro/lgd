class ContainersController < ApplicationController
	
	after_filter :verify_authorized, except: [:show]
		
  def new
		@container = Container.new
		authorize @container
  end
	
	def create
		@container = Container.new(user_params)
		authorize @container
		if @container.save
			flash[:success] = "New container created!"
			redirect_to @container
		else
			render 'new'
		end
	end

  def edit
		@container = Container.find_by(id: params[:id])
		authorize @container
		@act = @container.act
  end
	
	def update
		@container = Container.find_by(id: params[:id])
		authorize @container
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
		@container=Container.find_by(id: params[:id])
		authorize @container
		@container.destroy
    flash[:success] = "Container deleted."
    redirect_to containers_url
  end
	
	private
		def user_params
			params.require(:container).permit(:number, :parent_id, :depth, :content, :special_paragraph)
		end
	
	
end
