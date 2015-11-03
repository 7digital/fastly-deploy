require 'rspec'
require_relative '../lib/methods.rb'
require 'fastly'

RSpec.describe "fastly-deploy" do

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
    
  end

  context "main vcl exists in initial version" do
    before(:each) do
      upload_main_vcl_to_version(@version, 'spec/vcls/test_no_wait.vcl')
      @version.activate!

      puts "Activated service. Running test."
    end  

    context "deploying a new VCL version" do
      it "increments the version number exposed by /vcl_version" do
        deploy_vcl @api_key, @service.id, "spec/vcls/test_no_wait.vcl", false, nil
        expect(Integer(get_active_version.number)).to be > Integer(@version.number)
      end

      it 'gets the active version not the latest version' do
        non_active_version = create_non_active_version_with_another_domain

        expect(number_of_domains_for_version(@version)).to eq(1)
        expect(number_of_domains_for_version(non_active_version)).to eq(2)
        
        deploy_vcl @api_key, @service.id, "spec/vcls/test_no_wait.vcl", false, nil

        new_active_version = get_active_version()
        expect(new_active_version.number).not_to eq(@version.number)
        expect(number_of_domains_for_version(new_active_version)).to eq(1)
      end

      it 'sets the name of the main vcl to the name of the file' do
        deploy_vcl @api_key, @service.id, "spec/vcls/test_no_wait.vcl", false, nil
        active_version = get_active_version
        expect_vcl_to_contain(active_version, "test_no_wait", /400/)
      end  

      it 'uploads include alongside main vcl' do
        version_with_include = @version.clone
        upload_include_vcl_to_version version_with_include, "spec/vcls/includes/test_include.vcl", "Include"
        version_with_include.activate!

        new_include_to_upload = [{path:"spec/vcls/includes/new_test_include.vcl", name:"Include"}]

        deploy_vcl @api_key, @service.id, "spec/vcls/test_no_wait.vcl", false, new_include_to_upload

        active_version = get_active_version
        new_include_vcl = active_version.vcl("Include")
        expect(new_include_vcl.content).to match(/563/) 
      end

      it 'uploads multiple includes alongside main vcl and removes unused includes' do
        version_with_include = @version.clone

        includes_to_upload = [ {path:"spec/vcls/includes/test_include.vcl", name:"Include"},
                               {path:"spec/vcls/includes/test_include_2.vcl", name:"Include2"},
                               {path:"spec/vcls/includes/not_uploaded_again_include.vcl", name:"NotUsed"}]

        includes_to_upload.each  do | include_vcl | 
          upload_include_vcl_to_version version_with_include, include_vcl[:path], include_vcl[:name]
        end 
        version_with_include.activate!
        expect_vcl_to_contain(version_with_include, "NotUsed", /111/)

        new_includes_to_upload = [ {path:"spec/vcls/includes/new_test_include.vcl", name:"Include"}, 
                                   {path:"spec/vcls/includes/new_test_include_2.vcl", name:"Include2"}]

        deploy_vcl @api_key, @service.id, "spec/vcls/test_no_wait.vcl", false, new_includes_to_upload

        active_version = get_active_version
        expect_vcl_to_contain(active_version, "Include", /563/)
        expect_vcl_to_contain(active_version, "Include2", /2965/)

        begin
          active_version.vcl("NotUsed")
          fail "Should have thrown exception about non existent vcl" 
        rescue Fastly::Error => fastlyError
          expect(JSON.parse(fastlyError.message)["detail"]).to match(/Couldn't find/)
        end

        
      end

      it 'uploads includes that have not been created before' do
        new_include_to_upload = [{path:"spec/vcls/includes/new_test_include.vcl", name:"Include"}]

        deploy_vcl @api_key, @service.id, "spec/vcls/test_no_wait.vcl", false, new_include_to_upload

        active_version = get_active_version
        new_include_vcl = active_version.vcl("Include")
        expect(new_include_vcl.content).to match(/563/) 
      end

      it 'errors if main file is invalid' do
        expect{deploy_vcl @api_key, @service.id, "spec/vcls/error_test.vcl", false, nil}.to raise_error(/Message from VCC-compiler/)
      end

      it "injects the service id in the vcls" do
        include_to_upload = [{path:"spec/vcls/includes/service_id_injection_include.vcl", name:"Include"}]
        deploy_vcl @api_key, @service.id, "spec/vcls/service_id_injection.vcl", false, include_to_upload
        
        active_version = get_active_version
        expect_vcl_to_contain active_version, "service_id_injection", /set obj.response = "#{@service.id}"/
        expect_vcl_not_to_contain active_version, "service_id_injection", /#FASTLY_SERVICE_ID/

        expect_vcl_to_contain active_version, "Include", /set obj.response = "#{@service.id}"/
        expect_vcl_not_to_contain active_version, "Include", /#FASTLY_SERVICE_ID/
      end

      it "injects deployment confirmation and waits for confirmation" do
        expect {deploy_vcl @api_key, @service.id, "spec/vcls/wait_for_deployment_confirmation.vcl", false, nil}.to output(/Waiting for changes to take effect/).to_stdout
        
      end
    end
  end

  context "main vcl does not exists in inital version" do
    before(:each) do
      @version.activate!
      puts "Activated service. Running test."
    end  

    it "uploads an inital version of the main vcl" do
      deploy_vcl @api_key, @service.id, "spec/vcls/test_no_wait.vcl", false, nil
      expect(Integer(get_active_version.number)).to be > Integer(@version.number)
      active_version = get_active_version
      main_vcl = @fastly.list_vcls(:service_id => @service.id, 
                                  :version => active_version.number)
                              .find{|vcl| vcl.main}
      expect(main_vcl).not_to be_nil
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

def upload_main_vcl_to_version(version, file_path)
  upload_vcl_to_version(version, file_path, "Main")
  version.vcl("Main").set_main!
end 

def upload_include_vcl_to_version(version, file_path, name)
  upload_vcl_to_version(version, file_path, name)
end  

def upload_vcl_to_version(version, file_path, name)
  vcl_contents = File.read(file_path)
  version.upload_vcl name, vcl_contents
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

def expect_vcl_to_contain(version, name, regex)
  vcl = version.vcl(name)
  expect(vcl.content).to match(regex)
end  

def expect_vcl_not_to_contain(version, name, regex)
  vcl = version.vcl(name)
  expect(vcl.content).not_to match(regex)
end 

