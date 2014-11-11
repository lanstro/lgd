class ContainersController < ApplicationController
	
	after_filter :verify_authorized, except: [:show, :show_json]
	before_action :set_container, except: [:new, :create]
		
	# TODO HIGH - need to convert to JSON interface
		
  def new
		@container = Container.new
		authorize @container
  end
	
	def create
		@container = Container.new(user_params)
		authorize @container
		if @container.save
			flash[:success] = "New container created!"
			@container.parse_definitions
			@container.parse_anchors
			@container.recalculate_annotations
			redirect_to @container
		else
			render 'new'
		end
	end

  def edit
		authorize @container
		@act = @container.act
  end
	
	def update
		authorize @container
		if @container.update_attributes(user_params)
			flash[:success] = "Section updated"
			redirect_to @container
		else
			render 'edit'
		end
	end


  def destroy
		authorize @container
		@container.destroy
    flash[:success] = "Container deleted."
    redirect_to containers_url
  end
	
	def show_json
		respond_to do |format|
			format.json { render :json => { annotated_content: @container.annotated_content} }
		end
	end
	
	private
		
		def set_container
			@container=Container.find_by(id: params[:id])
		end
		
		def user_params
			params.require(:container).permit(:number, :parent_id, :depth, :content, :special_paragraph)
		end
	
	
end
