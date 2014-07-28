require 'spec_helper'

describe Metadata do
  before {
						@scope = FactoryGirl.create(:collection)
						@content = FactoryGirl.create(:collection)
						
						@metadata = Metadata.new(
						anchor_text: 			"defined term",
						meta_type: 				"definition",
						scope: 						@scope,
						metadata_content: @content
					)
					
					
					}
	subject { @metadata }
	
	it { should respond_to(:anchor_text) }
	it { should respond_to(:scope) }
	it { should respond_to(:metadata_content) }
	
	describe "when no metadata type" do
		before {@metadata.meta_type=nil}
		it {should_not be_valid}
	end
	
	describe "when no scope" do
		before {@metadata.scope=nil}
		it {should_not be_valid}
	end
	
	describe "when no contents" do
		before {@metadata.metadata_content=nil}
		it {should_not be_valid}
	end
	
	describe "hyperlink metadata shouldn't need content" do
		before { 	@metadata.metadata_content=nil
							@metadata.meta_type = "external_link" 
							@metadata.external_link = "omgphwar.com"}
		it {should be_valid}
	end
	
	describe "when external link type metadata does not have link" do
		before {@metadata.meta_type="external_link"}
		it {should_not be_valid}
	end
	
	
end
