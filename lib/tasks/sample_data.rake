namespace :db do
  desc "Fill database with sample data"
  task populate: :environment do
    User.create!(name: "a",
                 email: "a@a.a",
                 password: "omgphwar",
                 password_confirmation: "omgphwar",
								 admin: true,
								 reputation: 0)
		User.create!(name: "b",
                 email: "b@b.b",
                 password: "omgphwar",
                 password_confirmation: "omgphwar",
								 admin: false,
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
		99.times do |n|
			title = Faker::Name.name[0..10]+" Act"
			Act.create!( title: title, 
 									 last_updated: "2012-12-04", 
									 jurisdiction: ["Commonwealth", "Victoria", "New South Wales", "Tasmania"].sample,
									 subtitle: title+" subtitle",
									 act_type: ["Act", "Regulations"].sample,
									 year: 1901+rand(114),
									 number: rand(30)+1 )
		
    end
  end
end