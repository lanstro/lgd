require 'spec_helper'

describe Comment do

  let(:user) { FactoryGirl.create(:user) }
	let(:container) {FactoryGirl.create(:container) }
	
  before do
    # This code is not idiomatically correct.
    @comment = user.comments.build(content: "Lorem ipsum", reputation: 0)
		@comment.container = container
  end

  subject { @comment }

  it { should respond_to(:content) }
  it { should respond_to(:user_id) }
	it { should respond_to(:container_id) }
	it { should respond_to(:reputation) }
	it { should respond_to(:container) }
	it { should respond_to(:user) }
	it { should respond_to(:parent) }
	it { should respond_to(:act) }
	
	it { should be_valid }
	its(:user) {should eq user }
	its(:container) { should eq container }
		
	describe "when user_id is not present" do
    before { @comment.user_id = nil }
    it { should_not be_valid }
  end
	
	
	describe "when container_id is not present" do
    before { @comment.container_id = nil }
    it { should_not be_valid }
  end
	
	describe "when content is too long" do
		before { @comment.content = "a" * 5001 }
		it { should_not be_valid}
		 
	end
	
end