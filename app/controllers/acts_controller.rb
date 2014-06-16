class ActsController < ApplicationController
  def new
		@act = Act.new
  end

	def create
		@act = Act.new(params)
    if @act.save
			flash[:success] = "New act created!"
      redirect_to @act
    else
      render 'new'
    end
	end
	
  def edit
		
  end
	
	def index
		@acts=Act.paginate(page: params[:page])
	end
	
	def update
		
	end

  def show
		@act = Act.find(params[:id])
  end

  def destroy
		Act.find(params[:id]).destroy
    flash[:success] = "Act deleted."
    redirect_to acts_url
  end
end
