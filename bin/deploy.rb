require_relative '../lib/methods'
require 'optparse'

options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: deploy.rb [options]"
  opts.on("-k", "--api-key API_KEY", "Fastly API Key") do |api_key|
    options[:api_key] = api_key
  end
  opts.on("-s", "--service-id SERVICE_ID", "Service ID") do |service_id|
    options[:service_id] = service_id
  end
  opts.on("-v", "--vcl-path FILE", "VCL Path") do |vcl_path|
    options[:vcl_path] = vcl_path
  end
  options[:purge_all] = false
  opts.on("-p", "--purge-all", "Purge All") do |purge_all|
    options[:purge_all] = true
  end
  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
end
optparse.parse!

if options[:api_key].nil? ||
    options[:service_id].nil? ||
    options[:vcl_path].nil? then
  puts optparse
  exit 1
end

deploy_vcl options[:api_key],
  options[:service_id],
  options[:vcl_path],
  options[:purge_all]

