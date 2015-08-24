require 'rspec'
require_relative '../lib/methods.rb'
require 'fastly'

RSpec.describe "fastly-deploy" do

  before(:each) do

    puts "Creating test service..."

    @api_key = ENV["FASTLY_TEST_API_KEY"]
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
    vcl_contents = File.read("spec/test.vcl")
    @version.upload_vcl "Main", vcl_contents
    @version.vcl("Main").set_main!
    @version.activate!

    puts "Activated service. Running test."

  end

  context "deploying a new VCL version" do

    it "increments the version number exposed by /vcl_version" do

      deploy_vcl @api_key, @service.id, "spec/test.vcl", false

    end

  end

  after(:each) do

    puts "Deleting test service..."
    @service = @fastly.get_service(@service.id)
    active_version = @service.versions.find{|ver| ver.active?}
    active_version.deactivate!
    @service.delete!

    puts "Deleted."

  end

end

