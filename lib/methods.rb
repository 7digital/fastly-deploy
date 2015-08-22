require 'fastly'
require 'net/http'
require 'colorize'

def deploy_vcl(api_key, service_id, vcl_path, purge_all)

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
  puts "VCL: #{main_vcl.name}"

  new_version = active_version.clone
  puts "New Version: #{new_version.number}"

  vcl_contents = File.read(vcl_path)
  new_vcl_contents = inject_deploy_verify_code(vcl_contents, new_version.number)
  deploy_vcl_inserted = new_vcl_contents != vcl_contents

  puts "Uploading..."
  new_vcl = new_version.vcl(main_vcl.name)
  new_vcl.content = new_vcl_contents
  new_vcl.save!

  puts "Validating..."
  new_version.validate

  puts "Activating..."
  new_version.activate!

  if deploy_vcl_inserted then
    print "Waiting for changes to take effect."
    attempts = 1
    deployed_vcl_version_number = 0

    while attempts < 30 && deployed_vcl_version_number != new_version.number.to_s do
      sleep 2
      url = URI.parse("http://#{domain.name}.global.prod.fastly.net/vcl_version")
      req = Net::HTTP::Get.new(url.to_s)
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      deployed_vcl_version_number = res.body
      print "."
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

