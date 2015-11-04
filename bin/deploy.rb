#!/usr/bin/env ruby

require_relative '../lib/methods'
require 'optparse'

def deploy(argv)
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
    opts.on("-i", "--vcl-includes INCLUDES_DIR", "Includes Directory") do |includes_dir|
      options[:includes] = []
      Dir.entries(includes_dir).select{|file| File.extname(file) == ".vcl" }.each do |file|
        options[:includes].push({path:File.join(includes_dir, file)})
      end
      puts options[:includes]
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
  optparse.parse! argv

  if options[:api_key].nil? ||
     options[:service_id].nil? ||
     options[:vcl_path].nil? then
    puts optparse
    exit 1
  end

  deploy_vcl options[:api_key],
             options[:service_id],
             options[:vcl_path],
             options[:purge_all],
             options[:includes]
  return options[:api_key]
end

# This is only run when run as a script. The FILE bit stops it 
# from being run during the tests
if __FILE__ == $0
  deploy ARGV
end
