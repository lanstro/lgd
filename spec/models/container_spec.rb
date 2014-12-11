# == Schema Information
#
# Table name: containers
#
#  id                :integer          not null, primary key
#  number            :text
#  last_updated      :date
#  updating_acts     :text
#  regulations       :integer
#  created_at        :datetime
#  updated_at        :datetime
#  act_id            :integer
#  content           :text
#  level             :integer
#  special_paragraph :string(255)
#  position          :integer
#  ancestry          :string(255)
#  ancestry_depth    :integer
#  annotated_content :text
#  definition_parsed :datetime
#  references_parsed :datetime
#  annotation_parsed :datetime
#  definition_zone   :boolean
#  flags_count       :integer
#
# Indexes
#
#  container_uniqueness                   (content,act_id,ancestry,number,position) UNIQUE
#  index_containers_on_act_id_and_number  (act_id,number)
#  index_containers_on_ancestry           (ancestry)
#

require 'spec_helper'
require 'factory_girl' 

describe Container do
  
	let(:act) { FactoryGirl.create(:act) }
	
	before { @container = act.containers.build( number: "2A",
																					last_updated: "2013-07-12",
																					updating_acts: "1 2 4",
																					level: 5,
																					regulations: 6) }
	
	subject { @container }
	 
	
	it { should respond_to(:act) }
	it { should respond_to(:number) }
	it { should respond_to(:last_updated) }
	it { should respond_to(:updating_acts) }
	it { should respond_to(:content) }
	it { should respond_to(:regulations) }
	it { should respond_to(:level) }
	it { should respond_to(:comments) }
	
	its(:act) {should eq act}
	
	describe "when no owning act" do
		before {@container.act_id=nil}
		it {should_not be_valid}
	end
	
	describe "owning act should exist" do
		before {@container.act_id=10000000000 }
		it {should_not be_valid}
	end
	
	describe "when no level" do
		before {@container.level=nil}
		it {should_not be_valid}
	end
	
	describe "when level is invalid" do
		before {@container.level="lawl"}
		it {should_not be_valid}
	end
	
	describe "when level is valid" do
		before {@container.level=7}
		it {should be_valid}
	end
end
