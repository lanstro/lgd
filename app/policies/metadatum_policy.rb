class MetadatumPolicy < ApplicationPolicy
	
	attr_reader :user, :metadatum

	def initialize(user, metadatum)
		@user         = user
		@metadatum    = metadatum
	end
	
	def new?
		user.admin?
	end

	def edit?
		user.admin?
	end

	def delete?
		user.admin?
	end

	def update?
		user.admin?
	end

	def create?
		user.admin?
	end

	def show?
		user.admin?
	end

	def index?
		user.admin?
	end
	
  class Scope < Scope
    def resolve
      scope
    end
  end
end
