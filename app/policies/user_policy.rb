class UserPolicy < ApplicationPolicy
	
	attr_reader :user, :profile

	def initialize(user, profile)
		@user       = user
		@profile    = profile
	end
	
	def destroy?
		user.admin?
	end
	
  class Scope < Scope
    def resolve
      scope
    end
  end
end
