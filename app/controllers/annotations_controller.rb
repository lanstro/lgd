class AnnotationsController < ApplicationController
	
	# just a json API for the marionette front-end at acts#show

	after_filter :verify_authorized
	
	respond_to :json
	
  def index
		container = Container.find_by_id(params[:container_id])
		if container
			@annotations = container.annotations
			authorize @annotations
			respond_to { |format| format.json { render :json => @annotations } }
		else
			respond_to { |format| format.json { render :json => "No such root container found." } }
		end
  end

  def create
		@annotation=Annotation.new(user_params)
		authorize @annotation
		respond_to do |format|
			if @annotation.save
				format.json { render :json => { success: true, message: "Annotation saved"} }
			else
				format.json { render :json => { success: false, errors: @annotation.errors.messages.to_json} }
			end	
		end
		
	end

  def update
		@annotation = Annotation.find(params[:id])
		if @annotation
			authorize @annotation
			respond_to do |format|
				if @annotation.update_attributes(user_params)
					format.json { render :json => {success: true} }
				else
					format.json { render :json => {success: false, errors: @annotation.errors.messages } }
				end
			end
		else
			# need something to authorize
			respond_to { |format| format.json { render :json => { success: false, errors: "No annotation found." } } }
		end
  end

  def destroy
		@annotation = Annotation.find(params[:id])
		if @annotation
			authorize @annotation
			destroy @annotation
			#respond_with {success: true, message: "Annotation deleted" }
		else
			#respond_with {success: false, errors: "Annotation "+params[:id].inspect+" not found" }
		end
  end
	
	private

	def user_params
		params.require(:annotation).permit(:metadatum_id, :anchor, :container_id, :position, :category)
	end
	
end
