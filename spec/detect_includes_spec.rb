require 'rspec'
require_relative '../lib/detect_includes.rb'

RSpec.describe "get_includes" do

  it "should return empty array if there are no includes" do
    expect(get_includes("spec/vcls/detect_includes_vcls/no_includes.vcl")).to be_empty
  end

  it "should return the include if there is one include at top of vcl" do
    includes = get_includes("spec/vcls/detect_includes_vcls/one_include_at_top.vcl")
    expect(includes.length).to eq(1)
    expect(includes[0]).to eq("new_test_include")
  end
end  