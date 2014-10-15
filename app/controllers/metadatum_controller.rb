class MetadatumController < ApplicationController
	
	after_filter :verify_authorized
	before_action :set_type
	before_action :set_metadatum_and_authorize, except: [:new, :index, :create]
	
  def new
		@metadatum = type_class.new
		authorize @metadatum
  end

  def edit
  end

  def destroy
		@metadatum.destroy
		flash[:success] = "Metadatum deleted."
    redirect_to metadata_url
  end

  def update
    if @metadatum.update_attributes(user_params)
			flash[:success] = "Metadatum updated"
      redirect_to @metadatum
    else
      render 'edit'
    end
  end

  def create
		@metadatum = type_class.new(user_params)
		authorize @metadatum
    if @metadatum.save
			flash[:success] = "New metadatum created!"
      redirect_to @metadatum
    else
      render 'new'
    end
  end

  def show
  end

  def index
		@metadata=type_class.all
		@metadata=@metadata.paginate(page: params[:page])
		authorize @metadata
  end
	
	private
		def set_metadatum_and_authorize
			@metadatum = type_class.find_by(id: params[:id])
			authorize @metadatum
		end
		
		def user_params
			params.require(type.downcase.to_sym).permit(:scope_id, :scope_type, :content_id, :content_type, :anchor, :type)
		end
		
		def set_type
			@type = type
		end
		
		def type
			metadatum_types.include?(params[:type]) ? params[:type] : "Metadatum"
		end
		
		def metadatum_types
			['Hyperlink', 'Internal_reference', 'Definition', 'Metadatum']
		end
		
		def type_class
			@type.constantize if @type.in? metadatum_types
		end
		
end
