class ActsController < ApplicationController
	
	after_filter :verify_authorized, except: [:show, :index, :containers_json]
	before_action :set_act, except: [:new, :index, :create]
	
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
		authorize @act
  end
	
	def index
		@acts=policy_scope(Act)
		if @acts
			@acts=@acts.paginate(page: params[:page])
		end
	end
	
	def update
		authorize @act
    if @act.update_attributes(user_params)
			flash[:success] = "Act updated"
      redirect_to @act
    else
      render 'edit'
    end
	end

  def show
  end

  def destroy
		authorize @act
		@act.destroy
    flash[:success] = "Act deleted."
    redirect_to acts_url
  end
	
	def parse  
		authorize @act
		@act.parse
		redirect_to @act
	end
	
	def reset_parsing
		authorize @act
		@act.containers.destroy_all
		redirect_to @act
	end
	
	def containers_json
		respond_to do |format|
			format.json { render :json => @act.containers.arrange_serializable.to_json}
			#format.json { render :json => @act.containers.roots[0].subtree.arrange_serializable.to_json}
			# TODO HIGH: indicate when not everything has been loaded
		end
	end
	
	def publish
		authorize @act
		@act.published=true
		@act.save
	end
	
	def unpublish
		authorize @act
		@act.published=false
		@act.save
	end
	
	private
		
		def set_act
			@act = Act.find_by_id(params[:id])
		end
		
		def user_params
			params.require(:act).permit(:title, :subtitle, :year, :number, :act_type, :jurisdiction, :last_updated, :comlawID)
		end
	
end

