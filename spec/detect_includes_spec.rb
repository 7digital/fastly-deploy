require 'rspec'
require_relative '../lib/detect_includes.rb'

RSpec.describe "get_includes" do

  it "should return empty array if there are no includes" do
    expect(get_includes("spec/vcls/detect_includes_vcls/no_includes.vcl")).to be_empty
  end

  it "should return the include if there is one include at top of vcl" do
    includes = get_includes("spec/vcls/detect_includes_vcls/one_include_at_top.vcl")
    expect(includes.length).to eq(1)
    expect(includes).to include("new_test_include")
  end

  it "should return all includes" do
    includes = get_includes("spec/vcls/detect_includes_vcls/multiple_includes.vcl")
    expect(includes.length).to eq(3)
    expect(includes).to include("new_test_include")
    expect(includes).to include("test_include")
    expect(includes).to include("not_uploaded_again_include")
  end
end  