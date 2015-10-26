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
    upload_vcl_to_version(@version, 'spec/test.vcl')
    @version.activate!

    puts "Activated service. Running test."

  end

  context "deploying a new VCL version" do

    it "increments the version number exposed by /vcl_version" do

      deploy_vcl @api_key, @service.id, "spec/test.vcl", false

    end

    it 'gets the active version not the latest version' do
      non_active_version = create_non_active_version_with_another_domain

      expect(number_of_domains_for_version(@version)).to eq(1)
      expect(number_of_domains_for_version(non_active_version)).to eq(2)
      

      deploy_vcl @api_key, @service.id, "spec/test.vcl", false

      new_active_version = get_active_version()
      expect(new_active_version.number).not_to eq(@version.number)
      expect(number_of_domains_for_version(new_active_version)).to eq(1)
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

def upload_vcl_to_version(version, file_path) 
  vcl_contents = File.read(file_path)
  version.upload_vcl "Main", vcl_contents
  version.vcl("Main").set_main!
end  

def create_non_active_version_with_another_domain
  non_active_version = @version.clone
  random_suffix = ('a'..'z').to_a.shuffle[0,8].join
  @fastly.create_domain(service_id: @service.id,
                        version: non_active_version.number,
                        name: "deploytestservice2-#{random_suffix}.com")
  return non_active_version
end 

def number_of_domains_for_version(version)
  return @fastly.list_domains(service_id: @service.id, version: version.number).length
end

def get_active_version
  service = @fastly.get_service(@service.id)
  active_version = service.versions.find{|ver| ver.active?}
  return active_version
end  

