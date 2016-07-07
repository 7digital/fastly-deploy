require 'fastly'
require 'net/http'
require 'colorize'

def deploy_vcl(api_key, service_id, vcl_path, purge_all, include_files)
  login_opts = { api_key: api_key }
  fastly = Fastly.new(login_opts)
  service = fastly.get_service(service_id)

  active_version = service.versions.find(&:active?)
  puts "Active Version: #{active_version.number}"
  domain = fastly.list_domains(service_id: service.id,
                               version: active_version.number).first
  puts "Domain Name: #{domain.name}"

  new_version = active_version.clone
  puts "New Version: #{new_version.number}"

  fastly.list_vcls(service_id: service.id,
                   version: new_version.number)
        .each(&:delete!)

  can_verify_deployment = upload_main_vcl new_version, vcl_path, service_id

  unless include_files.nil?
    include_files.each do |include_file|
      upload_include_vcl new_version, include_file, service_id
    end
  end

  puts 'Validating...'

  validate(new_version)

  puts 'Activating...'
  new_version.activate!

  if can_verify_deployment
    print 'Waiting for changes to take effect.'
    attempts = 1
    deployed_vcl_version_number = 0

    while attempts < 150 && deployed_vcl_version_number != new_version.number.to_s
      sleep 2
      url = URI.parse("http://#{domain.name}.global.prod.fastly.net/vcl_version")
      req = Net::HTTP::Get.new(url.to_s)
      res = Net::HTTP.start(url.host, url.port) do |http|
        http.request(req)
      end
      deployed_vcl_version_number = res.body
      print '.'
      attempts += 1
    end
    puts 'done.'

    if deployed_vcl_version_number != new_version.number.to_s
      STDERR.puts "Verify failed. /vcl_version returned [#{deployed_vcl_version_number}].".red
      exit 1
    end
  end

  if purge_all
    puts 'Purging all...'
    service.purge_all
  end
  puts 'Deployment complete.'.green
end

def upload_main_vcl(version, vcl_path, service_id)
  vcl_name = File.basename(vcl_path, '.vcl')
  can_verify_deployment = upload_vcl version, vcl_path, vcl_name, service_id
  version.vcl(vcl_name).set_main!
  can_verify_deployment
end

def upload_include_vcl(version, vcl_path, service_id)
  vcl_name = File.basename(vcl_path, '.vcl')
  upload_vcl version, vcl_path, vcl_name, service_id
end

def upload_vcl(version, vcl_path, name, service_id)
  vcl_contents_from_file = File.read(vcl_path)
  vcl_contents_with_service_id_injection = inject_service_id vcl_contents_from_file, service_id
  vcl_contents_with_deploy_injection = inject_deploy_verify_code(vcl_contents_with_service_id_injection, version.number)

  puts "Uploading #{name}"
  version.upload_vcl name, vcl_contents_with_deploy_injection

  vcl_contents_with_deploy_injection != vcl_contents_with_service_id_injection
end

def inject_deploy_verify_code(vcl, version_num)
  deploy_recv_vcl = <<-END
  # --------- DEPLOY VERIFY CHECK START ---------
  if (req.url == "/vcl_version") {
    error 902;
  }
  # --------- DEPLOY VERIFY CHECK END ---------
  END

  deploy_error_vcl = <<-END
  # --------- DEPLOY VERIFY CHECK START ---------
  if (obj.status == 902) {
    set obj.status = 200;
    set obj.response = "OK";
    synthetic "#{version_num}";
    return(deliver);
  }
  # --------- DEPLOY VERIFY CHECK END ---------
  END

  vcl.gsub(/#7D_DEPLOY recv/, deploy_recv_vcl)
     .gsub(/#7D_DEPLOY error/, deploy_error_vcl)
end

def inject_service_id(vcl_contents, service_id)
  vcl_contents.gsub(/#7D_FASTLY_SERVICE_ID/, service_id)
end

def validate(version)
  path = version.class.get_path(version.service_id, version.number)
  response = version.fetcher.client.get("#{path}/validate")
  status = response['status']
  raise response['msg'] if status != 'ok'
end
