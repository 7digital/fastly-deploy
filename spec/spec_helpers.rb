def active_service_version
  service = @fastly.get_service(@service.id)
  active_version = service.versions.find(&:active?)
  active_version
end

def upload_main_vcl_to_version(version, file_path)
  upload_vcl_to_version(version, file_path, 'Main')
  version.vcl('Main').set_main!
end

def upload_vcl_to_version(version, file_path, name)
  vcl_contents = File.read(file_path)
  version.upload_vcl name, vcl_contents
end

def expect_vcl_to_contain(version, name, regex)
  vcl = version.vcl(name)
  expect(vcl.content).to match(regex)
end

def delete_test_service
  puts 'Deleting test service...'
  @service = @fastly.get_service(@service.id)
  active_version = @service.versions.find(&:active?)
  active_version.deactivate!
  @service.delete!
  puts 'Deleted.'
end

def create_test_service
  puts 'Creating test service...'

  @api_key = ENV['FASTLY_SANDBOX_API_KEY']
  @fastly = Fastly.new(api_key: @api_key)
  random_suffix = ('a'..'z').to_a.sample(8).join
  @service = @fastly.create_service(name: "DeployTestService-#{random_suffix}")
  @version = @service.version
  @fastly.create_domain(
    service_id: @service.id,
    version: @version.number,
    name: "deploytestservice-#{random_suffix}.com"
  )
  @fastly.create_backend(
    service_id: @service.id,
    version: @version.number,
    name: 'DeployTestBackend',
    ipv4: '192.0.43.10',
    port: 80
  )
end
