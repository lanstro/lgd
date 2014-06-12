namespace :db do
  desc "Fill database with sample data"
  task populate: :environment do
    User.create!(name: "a",
                 email: "a@a.a",
                 password: "omgphwar",
                 password_confirmation: "omgphwar",
								 admin: true,
								 reputation: 0)
    99.times do |n|
      name  = Faker::Name.name[0..10]
      email = "example-#{n+1}@railstutorial.org"
      password  = "password"
      User.create!(name: name,
                   email: email,
                   password: password,
                   password_confirmation: password,
									 admin: false,
									 reputation: 0)
    end
  end
end