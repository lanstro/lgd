class ActsController < ApplicationController
	
	after_filter :verify_authorized, except: [:show, :index, :containers_json]
	
  def new
		@act = Act.new
		authorize @act
  end

	def create
		@act = Act.new(user_params)
		authorize @act
    if @act.save
			flash[:success] = "New act created!"
      redirect_to @act
    else
      render 'new'
    end
	end
	
  def edit
		@act = Act.find_by(id: params[:id])
		authorize @act
  end
	
	def index
		
		@acts=policy_scope(Act)
		if @acts
			@acts=@acts.paginate(page: params[:page])
		else
			raise "no @acts.  @acts is "+@acts.inspect
		end
	end
	
	def update
		@act = Act.find_by(id: params[:id])
		authorize @act
    if @act.update_attributes(user_params)
			flash[:success] = "Act updated"
      redirect_to @act
    else
      render 'edit'
    end
	end

  def show
		@act = Act.find_by(id: params[:id])
  end

  def destroy
		@act = Act.find_by(id: params[:id])
		authorize @act
		@act.destroy
    flash[:success] = "Act deleted."
    redirect_to acts_url
  end
	
	def parse  
		@act = Act.find_by(id: params[:id])
		authorize @act
		@act.parse
		redirect_to @act
	end
	
	def reset_parsing
		@act = Act.find_by(id: params[:id])
		authorize @act
		@act.containers.destroy_all
		redirect_to @act
	end
	
	def containers_json
		act = Act.find_by_id(params[:id])
		respond_to do |format|
			format.json { render :json => act.containers.to_depth(7).arrange_serializable.to_json}
			# TODO HIGH: indicate when not everything has been loaded
			# option to show rest of tree like reddit
			# make the 7 into a constant somewhere
		end
	end
	
	def publish
		@act = Act.find_by_id(params[:id])
		authorize @act
		@act.published=true
		@act.save
	end
	
	def unpublish
		@act = Act.find_by_id(params[:id])
		authorize @act
		@act.published=false
		@act.save
	end
	
	def user_params
		params.require(:act).permit(:title, :subtitle, :year, :number, :act_type, :jurisdiction, :last_updated)
	end
	
end

