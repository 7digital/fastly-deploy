require 'rspec'
require_relative '../lib/methods.rb'
require_relative 'spec_helpers.rb'
require 'fastly'

RSpec.describe 'fastly-deploy' do
  before(:each) do
    create_test_service
  end

  context 'main vcl exists in initial version' do
    before(:each) do
      upload_main_vcl_to_version(@version, 'spec/vcls/test_no_wait.vcl')
      @version.activate!

      puts 'Activated service. Running test.'
    end

    context 'deploying a new VCL version' do
      it 'increments the version number exposed by /vcl_version' do
        deploy_vcl @api_key, @service.id, 'spec/vcls/test_no_wait.vcl', false, nil
        expect(Integer(active_service_version.number)).to be > Integer(@version.number)
      end

      it 'gets the active version not the latest version' do
        non_active_version = create_non_active_version_with_another_domain

        expect(number_of_domains_for_version(@version)).to eq(1)
        expect(number_of_domains_for_version(non_active_version)).to eq(2)

        deploy_vcl @api_key, @service.id, 'spec/vcls/test_no_wait.vcl', false, nil

        new_active_version = active_service_version
        expect(new_active_version.number).not_to eq(@version.number)
        expect(number_of_domains_for_version(new_active_version)).to eq(1)
      end

      it 'sets the name of the main vcl to the name of the file' do
        deploy_vcl @api_key, @service.id, 'spec/vcls/test_no_wait.vcl', false, nil
        active_version = active_service_version
        expect_vcl_to_contain(active_version, 'test_no_wait', /400/)
      end

      it 'uploads include alongside main vcl' do
        version_with_include = @version.clone
        upload_include_vcl_to_version version_with_include, 'spec/vcls/includes/test_include.vcl', 'new_test_include'
        version_with_include.activate!

        new_include_to_upload = ['spec/vcls/includes/new_test_include.vcl']

        deploy_vcl @api_key, @service.id, 'spec/vcls/test_no_wait.vcl', false, new_include_to_upload

        active_version = active_service_version
        expect_vcl_to_contain active_version, 'new_test_include', /563/
      end

      it 'uploads multiple includes alongside main vcl and removes unused includes' do
        version_with_include = @version.clone

        includes_to_upload_original = [{ path: 'spec/vcls/includes/test_include.vcl', name: 'new_test_include' },
                                       { path: 'spec/vcls/includes/test_include_2.vcl', name: 'new_test_include_2' },
                                       { path: 'spec/vcls/includes/not_uploaded_again_include.vcl', name: 'NotUsed' }]

        includes_to_upload_original.each do |include_vcl|
          upload_include_vcl_to_version version_with_include, include_vcl[:path], include_vcl[:name]
        end
        version_with_include.activate!
        expect_vcl_to_contain(version_with_include, 'NotUsed', /111/)

        new_includes_to_upload = ['spec/vcls/includes/new_test_include.vcl',
                                  'spec/vcls/includes/new_test_include_2.vcl']

        deploy_vcl @api_key, @service.id, 'spec/vcls/test_no_wait.vcl', false, new_includes_to_upload

        active_version = active_service_version
        expect_vcl_to_contain(active_version, 'new_test_include', /563/)
        expect_vcl_to_contain(active_version, 'new_test_include_2', /2965/)

        begin
          active_version.vcl('NotUsed')
          raise 'Should have thrown exception about non existent vcl'
        rescue Fastly::Error => fastly_error
          expect(JSON.parse(fastly_error.message)['detail']).to match(/Couldn't find/)
        end
      end

      it 'uploads includes that have not been created before' do
        new_include_to_upload = ['spec/vcls/includes/new_test_include.vcl']

        deploy_vcl @api_key, @service.id, 'spec/vcls/test_no_wait.vcl', false, new_include_to_upload

        active_version = active_service_version
        new_include_vcl = active_version.vcl('new_test_include')
        expect(new_include_vcl.content).to match(/563/)
      end

      it 'errors if main file is invalid' do
        expect { deploy_vcl @api_key, @service.id, 'spec/vcls/error_test.vcl', false, nil }.to raise_error(/Running VCC-compiler failed/)
      end

      it 'injects the service id in the vcls' do
        include_to_upload = ['spec/vcls/includes/service_id_injection_include.vcl']
        deploy_vcl @api_key, @service.id, 'spec/vcls/service_id_injection.vcl', false, include_to_upload
        active_version = active_service_version
        expect_vcl_to_contain active_version, 'service_id_injection', /set obj.response = "#{@service.id}"/
        expect_vcl_not_to_contain active_version, 'service_id_injection', /#7D_FASTLY_SERVICE_ID/

        expect_vcl_to_contain active_version, 'service_id_injection_include', /set obj.response = "#{@service.id}"/
        expect_vcl_not_to_contain active_version, 'service_id_injection_include', /#7D_FASTLY_SERVICE_ID/
      end

      it 'injects deployment confirmation and waits for confirmation' do
        expect { deploy_vcl @api_key, @service.id, 'spec/vcls/wait_for_deployment_confirmation.vcl', false, nil }.to output(/Waiting for changes to take effect/).to_stdout
      end
    end
  end

  context 'main vcl does not exists in inital version' do
    before(:each) do
      @version.activate!
      puts 'Activated service. Running test.'
    end

    it 'uploads an inital version of the main vcl' do
      deploy_vcl @api_key, @service.id, 'spec/vcls/test_no_wait.vcl', false, nil
      expect(Integer(active_service_version.number)).to be > Integer(@version.number)
      active_version = active_service_version
      main_vcl = @fastly.list_vcls(service_id: @service.id,
                                   version: active_version.number)
                        .find(&:main)
      expect(main_vcl).not_to be_nil
    end
  end

  after(:each) do
    delete_test_service
  end
end

def upload_include_vcl_to_version(version, file_path, name)
  upload_vcl_to_version(version, file_path, name)
end

def create_non_active_version_with_another_domain
  non_active_version = @version.clone
  random_suffix = ('a'..'z').to_a.sample(8).join
  @fastly.create_domain(service_id: @service.id,
                        version: non_active_version.number,
                        name: "deploytestservice2-#{random_suffix}.com")
  non_active_version
end

def number_of_domains_for_version(version)
  @fastly.list_domains(service_id: @service.id, version: version.number).length
end

def expect_vcl_not_to_contain(version, name, regex)
  vcl = version.vcl(name)
  expect(vcl.content).not_to match(regex)
end
