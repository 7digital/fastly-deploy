require 'rspec'
require_relative 'spec_helpers.rb'
load (File.join File.dirname(__FILE__), '../bin/fastly-deploy')

RSpec.describe 'deploy' do
  before(:each) do
    create_test_service
    upload_main_vcl_to_version(@version, 'spec/vcls/test_no_wait.vcl')
      @version.activate!

    puts 'Test service created'
  end

  it 'should upload a main vcl and any includes' do
    argv = ['-k', "#{@api_key}", '-s', "#{@service.id}", '-v', 'spec/vcls/deploy_test.vcl', '-i', 'spec/vcls/includes']

    deploy argv

    active_version = get_active_version
    expect_vcl_to_contain active_version, 'deploy_test', /900/
    expect_vcl_to_contain active_version, 'new_test_include', /563/
  end

  after(:each) do
    delete_test_service
  end

end
