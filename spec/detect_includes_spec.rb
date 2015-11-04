require 'rspec'
require_relative '../lib/detect_includes.rb'

RSpec.describe "get_includes" do

  it "should return empty array if there are no includes" do
    expect(get_includes("spec/vcls/detect_includes_vcls/no_includes.vcl", "spec/vcls/includes")).to be_empty
  end

  it "should return the include if there is one include at top of vcl" do
    includes = get_includes("spec/vcls/detect_includes_vcls/one_include_at_top.vcl", "spec/vcls/includes")
    expect(includes.length).to eq(1)
    expect(includes).to include("spec/vcls/includes/new_test_include.vcl")
  end

  it "should return all includes" do
    includes = get_includes("spec/vcls/detect_includes_vcls/multiple_includes.vcl", "spec/vcls/includes")
    expect(includes.length).to eq(3)
    expect(includes).to include("spec/vcls/includes/new_test_include.vcl")
    expect(includes).to include("spec/vcls/includes/test_include.vcl")
    expect(includes).to include("spec/vcls/includes/not_uploaded_again_include.vcl")
  end

  it "should look for includes in includes" do
    includes = get_includes("spec/vcls/detect_includes_vcls/include_with_include.vcl", "spec/vcls/includes")
    expect(includes.length).to eq(2)
    expect(includes).to include("spec/vcls/includes/has_include.vcl")
    expect(includes).to include("spec/vcls/includes/test_include.vcl")
  end

  it "should only list each include once" do
    includes = get_includes("spec/vcls/detect_includes_vcls/two_includes_with_same_include.vcl", "spec/vcls/includes")
    expect(includes.length).to eq(3)
    expect(includes).to include("spec/vcls/includes/has_include.vcl")
    expect(includes).to include("spec/vcls/includes/has_same_include.vcl")
    expect(includes).to include("spec/vcls/includes/test_include.vcl")
  end

  it "should look for includes in includes for multiple levels" do
    includes = get_includes("spec/vcls/detect_includes_vcls/multi_level_includes.vcl", "spec/vcls/includes")
    expect(includes.length).to eq(5)
    expect(includes).to include("spec/vcls/includes/level_one_include.vcl")
    expect(includes).to include("spec/vcls/includes/level_two_include.vcl")
    expect(includes).to include("spec/vcls/includes/level_three_include.vcl")
    expect(includes).to include("spec/vcls/includes/level_four_include.vcl")
    expect(includes).to include("spec/vcls/includes/test_include.vcl")
  end
end  