# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  email                  :string(255)      default(""), not null
#  encrypted_password     :string(255)      default(""), not null
#  reset_password_token   :string(255)
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0), not null
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :string(255)
#  last_sign_in_ip        :string(255)
#  confirmation_token     :string(255)
#  confirmed_at           :datetime
#  confirmation_sent_at   :datetime
#  unconfirmed_email      :string(255)
#  failed_attempts        :integer          default(0), not null
#  unlock_token           :string(255)
#  locked_at              :datetime
#  admin                  :boolean
#  reputation             :integer
#  comments_total         :integer
#  name                   :string(255)
#  organisation           :string(255)
#  created_at             :datetime
#  updated_at             :datetime
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_unlock_token          (unlock_token) UNIQUE
#

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  #   :timeoutable
	# 
	
  TEMP_EMAIL_PREFIX = 'change@me'
  TEMP_EMAIL_REGEX = /\Achange@me/
	
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :confirmable, :lockable
				 
	devise :omniauthable, :omniauth_providers => [:facebook, :linkedin, :github, :google_oauth2]
				 
	validates :name, presence: true, length: { maximum: 15, minimum: 3 }
	
	has_many :comments
	has_many :identities
	
  def self.find_for_oauth(auth, signed_in_resource = nil)
		
    # Get the identity and user if they exist
    identity = Identity.find_for_oauth(auth)
		
    # If a signed_in_resource is provided it always overrides the existing user
    # to prevent the identity being locked with accidentally created accounts.
    # Note that this may leave zombie accounts (with no associated identity) which
    # can be cleaned up at a later date.
    user = signed_in_resource ? signed_in_resource : identity.user
		
    # Create the user if needed
    if user.nil?
			
      # Get the existing user by email if the provider gives us a verified email.
      # If no verified email was provided we assign a temporary email and ask the
      # user to verify it on the next step via UsersController.finish_signup
      
			email = auth.info.email
      user = User.where(:email => email).first if email
			
      # Create the user if it's a new registration
      if user.nil?
				# TODO medium - send email to user with the password
				# update following flash to explain the temporary password
				# figure out what the finish_signup thing does
				pword = Devise.friendly_token[0, 10]
        user = User.new(
          name: auth.info.name || auth.info.nickname,
          email: email ? email : "#{TEMP_EMAIL_PREFIX}-#{auth.uid}-#{auth.provider}.com",
          password: pword
        )
        user.skip_confirmation!
        user.save!
				
      end
    end
		
    # Associate the identity with the user if needed
    if identity.user != user
      identity.user = user
      identity.save!
    end
    user
  end
	
  def email_verified?
    self.email && self.email !~ TEMP_EMAIL_REGEX
  end
	
  def self.new_with_session(params, session)
    super.tap do |user|
      if data = session["devise.facebook_data"] && session["devise.facebook_data"]["extra"]["raw_info"]
        user.email = data["email"] if user.email.blank?
      end
    end
  end	
end
