require 'rspec'
require_relative '../bin/deploy.rb'
require_relative 'spec_helpers.rb'

RSpec.describe "deploy" do
  before(:each) do
    puts "Creating test service..."

    @api_key = ENV["FASTLY_SANDBOX_API_KEY"]
    @fastly = Fastly.new({api_key: @api_key})
    random_suffix = ('a'..'z').to_a.shuffle[0,8].join
    @service = @fastly.create_service(name: "DeployTestService-#{random_suffix}")
    @version = @service.version
    @fastly.create_domain(service_id: @service.id,
                         version: @version.number,
                         name: "deploytestservice-#{random_suffix}.com")
    @fastly.create_backend(service_id: @service.id,
                          version: @version.number,
                          name: "DeployTestBackend",
                          ipv4: "192.0.43.10",
                          port: 80)

    upload_main_vcl_to_version(@version, 'spec/vcls/test_no_wait.vcl')
      @version.activate!

    puts "Test service created"
  end


  it "should" do
    argv = ["-k", "#{@api_key}", "-s", "#{@service.id}", "-v", "spec/vcls/test_no_wait.vcl", "-i", "spec/vcls/includes"]

    deploy argv

    active_version = get_active_version
    expect_vcl_to_contain active_version, "test_no_wait", /900/
    expect_vcl_to_contain active_version, "new_test_include", /563/
  end 



end  