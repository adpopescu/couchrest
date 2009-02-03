require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

# check the following file to see how to use the spec'd features.
require File.join(FIXTURE_PATH, 'more', 'card')
require File.join(FIXTURE_PATH, 'more', 'invoice')

describe "ExtendedDocument properties" do
  
  before(:each) do
    @card = Card.new(:first_name => "matt")
  end
  
  it "should be accessible from the object" do
    @card.properties.should be_an_instance_of(Array)
    @card.properties.map{|p| p.name}.should include("first_name")
  end
  
  it "should let you access a property value (getter)" do
    @card.first_name.should == "matt"
  end
  
  it "should let you set a property value (setter)" do
    @card.last_name = "Aimonetti"
    @card.last_name.should == "Aimonetti"
  end
  
  it "should not let you set a property value if it's read only" do
    lambda{@card.read_only_value = "test"}.should raise_error
  end
  
  it "should let you use an alias for an attribute" do
    @card.last_name = "Aimonetti"
    @card.family_name.should == "Aimonetti"
    @card.family_name.should == @card.last_name
  end
  
  describe "validation" do
    
    before(:each) do
      @invoice = Invoice.new(:client_name => "matt", :employee_name => "Chris", :location => "San Diego, CA")
    end
    
    it "should be able to be validated" do
      @card.should be_valid
    end
    
    it "should let you validate the presence of an attribute" do
      @card.first_name = nil
      @card.should_not be_valid
      @card.errors.should_not be_empty
      @card.errors.on(:first_name).should == ["First name must not be blank"]
    end
    
    it "should validate the presence of 2 attributes" do
      @invoice.clear
      @invoice.should_not be_valid
      @invoice.errors.should_not be_empty
      @invoice.errors.on(:client_name).should == ["Client name must not be blank"]
      @invoice.errors.on(:employee_name).should_not be_empty
    end
    
    it "should let you set an error message" do
      @invoice.location = nil
      @invoice.valid?
      @invoice.errors.on(:location).first.should == "Hey stupid!, you forgot the location"
    end
  
  end
  
end