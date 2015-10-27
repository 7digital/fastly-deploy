require 'fastly'
require 'net/http'
require 'colorize'

def deploy_vcl(api_key, service_id, vcl_path, purge_all, include_files)

  login_opts = { :api_key => api_key }
  fastly = Fastly.new(login_opts)
  service = fastly.get_service(service_id)

  active_version = service.versions.find{|ver| ver.active?}
  puts "Active Version: #{active_version.number}"
  domain = fastly.list_domains(:service_id => service.id,
                               :version => active_version.number).first
  puts "Domain Name: #{domain.name}"
  main_vcl = fastly.list_vcls(:service_id => service.id, 
                              :version => active_version.number)
    .find{|vcl| vcl.main}
  puts "VCL: #{main_vcl ? main_vcl.name : "no main vcl"}"

  new_version = active_version.clone
  puts "New Version: #{new_version.number}"

  can_verify_deployment = false
  if main_vcl != nil
    can_verify_deployment = upload_new_version_of_vcl new_version, vcl_path, main_vcl.name
  else
    upload_new_vcl new_version, vcl_path, "Main"
  end  

  if include_files != nil 
      vcls_from_fastly = fastly.list_vcls(:service_id => service.id,
                                          :version => active_version.number)
    include_files.each do | include_file |
      upload_include vcls_from_fastly, include_file, new_version
    end
  end 

  puts "Validating..."
  
  validate(new_version)

  puts "Activating..."
  new_version.activate!

  if can_verify_deployment then
    print "Waiting for changes to take effect."
    attempts = 1
    deployed_vcl_version_number = 0

    while attempts < 20 && deployed_vcl_version_number != new_version.number.to_s do
      sleep 2
      url = URI.parse("http://#{domain.name}.global.prod.fastly.net/vcl_version")
      req = Net::HTTP::Get.new(url.to_s)
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      deployed_vcl_version_number = res.body
      print "."
      attempts += 1
    end
    puts "done."

    if deployed_vcl_version_number != new_version.number.to_s then
      STDERR.puts "Verify failed. /vcl_version returned [#{deployed_vcl_version_number}].".red
      exit 1
    end
  end

  if purge_all then
    puts "Purging all..."
    service.purge_all
  end
  puts "Deployment complete.".green
end

def upload_new_version_of_vcl(version, vcl_path, vcl_name)
  vcl_contents_from_file = File.read(vcl_path)
  vcl_contents_with_deploy_injection = inject_deploy_verify_code(vcl_contents_from_file, version.number)
  
  puts "Uploading..."
  new_vcl = version.vcl(vcl_name)
  new_vcl.content = vcl_contents_with_deploy_injection
  new_vcl.save!
  return vcl_contents_with_deploy_injection != vcl_contents_from_file
end 

def upload_new_vcl(version, vcl_path, name)
  vcl_contents_from_file = File.read(vcl_path)
  vcl_contents_with_deploy_injection = inject_deploy_verify_code(vcl_contents_from_file, version.number)
  version.upload_vcl name, vcl_contents_with_deploy_injection
end  

def upload_include(vcls_from_fastly, include_file, version)
  if vcls_from_fastly.any?{|vcl| vcl.name == include_file[:name]}
    upload_new_version_of_vcl version, include_file[:path], include_file[:name]
  else
    upload_new_vcl version, include_file[:path], include_file[:name]
  end 
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

  vcl.gsub(/#DEPLOY recv/, deploy_recv_vcl)
    .gsub(/#DEPLOY error/, deploy_error_vcl)
end

def validate(version)
  path = version.class.get_path(version.service_id, version.number)
  response = version.fetcher.client.get("#{path}/validate")
  status = response["status"]
  if status!= "ok"
    raise response["msg"]
  end
end

