class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  include Pundit
	protect_from_forgery with: :exception
	rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
	
	before_filter :configure_permitted_parameters, if: :devise_controller?
	
	
	def configure_permitted_parameters
		
		devise_parameter_sanitizer.for(:sign_up) { |u| u.permit(:email, :password, :password_confirmation, :name) }
		devise_parameter_sanitizer.for(:account_update) { |u| u.permit(:email, :password, :password_confirmation, :name, :current_password) }
		
	end
	
	def ensure_signup_complete
		# Ensure we don't go into an infinite loop
		return if action_name == 'finish_signup'
		
		# Redirect to the 'finish_signup' page if the user
		# email hasn't been verified yet
		if current_user && !current_user.email_verified?
			redirect_to finish_signup_path(current_user)
		end
	end
	
	private
	
	def user_not_authorized
		flash[:error] = "Only admins authorized to perform this action."
		redirect_to(request.referrer || root_path)
	end
	
end
