class MetadatumController < ApplicationController
	
	# just a json API for the marionette front-end at acts#show
	
	after_filter :verify_authorized, except: :index
	before_action :set_metadatum_and_authorize, except: [:new, :index, :create]
	
	respond_to :json
	
  def destroy
		@metadatum.destroy
		flash[:success] = "Metadatum deleted."
    redirect_to metadata_url
  end

  def update
		if @metadatum
			authorize @metadatum
			respond_to do |format|
				if @metadatum.save_and_check_dependencies(user_params)
					format.json { render :json => {success: true } }
				else
					format.json { render :json => {success: false, errors: @metadatum.errors.messages } }
				end
			end
		else
			# need something to authorize
			respond_to { |format| format.json { render :json => { success: false, errors: "No metadatum found." } } }
		end
  end

  def create
		@metadatum = Metadatum.new(user_params)
		authorize @metadatum
		respond_to do |format|
			if @metadatum.save
				if @metadatum.universal_scope
					Container.find_each do |c|
						c.recalculate_annotations if c.process_metadata_anchors(false, [@metadatum])
					end
				else
					# run through the scope, and add any new hyperlinks/annotations
					@metadatum.scope.subtree.find_each do | c|
						c.process_metadata_anchors(false, [@metadatum])
						c.recalculate_annotations
					end
				end
				format.json { render :json => { success: true, message: "Metadatum created"} }
			else
				format.json { render :json => { success: false, errors: @metadatum.errors.messages.to_json} }
			end	
		end
  end

  def index
		container = Container.find_by_id(params[:container_id])
		if container
			@metadata = container.contents
			respond_to { |format| format.json { render :json => @metadata } }
		else
			respond_to { |format| format.json { render :json => "No such root container found." } }
		end
		
  end
	
	private
		def set_metadatum_and_authorize
			@metadatum = Metadatum.find_by(id: params[:id])
			authorize @metadatum
		end
		
		def user_params
			params.require(:metadatum).permit(:scope_id, :scope_type, :content_id, :content_type, :anchor, :category, :universal_scope)
		end
		
end
