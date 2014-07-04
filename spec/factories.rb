FactoryGirl.define do
  factory :user do
		sequence(:name) { |n| "Person #{n}" }
		sequence(:email) { |n| "person_#{n}@example.com"}
    password "foobar"
    password_confirmation "foobar"
		reputation 0
		
    factory :admin do
      admin true
    end
  end
	
	factory :act do
		sequence(:title) { |n| "Test Act #{n}" }
		last_updated do 
			from = Time.now - 2.years
			to = Time.now
			Time.at(from+rand*(to - from))
		end
		jurisdiction ["Commonwealth", "Victoria", "New South Wales", "Queensland", "Northern Territory", "Australian Capital Territory", "Western Australia", "South Australia", "Tasmania"].sample
		sequence(:subtitle) {|n| "Subtitle for Test Act #{n}"}
		act_type ["Act", "Regulations"].sample
		sequence(:year) { |n| 1900+n }
		sequence(:number) { |n| 5+n }
	end
	
	factory :container do
		act
		sequence(:number) { |n| "#{n}"+["", "", "", "", "A"].sample }
		last_updated do 
			from = Time.now - 2.years
			to = Time.now
			Time.at(from+rand*(to - from))
		end
		sequence(:title) { |n| "Title for Test SEction #{n}" }
		container_type ["Regulation", "Section", "Schedule"].sample
		tag ["Subs_1", "Subs_2", "Part", "Division", "Section", "Paragraph"].sample
	end
	
end