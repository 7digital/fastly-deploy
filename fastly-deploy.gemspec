Gem::Specification.new do |s|
  s.name        = 'fastly-deploy'
  s.version     = ENV['VERSION']
  s.date        = '2016-07-06'
  s.summary     = "Automated deploys for Fastly vcl configs"
  s.description = "Automated deploys for Fastly vcl configs"
  s.authors     = ["7digital"]
  s.email       = 'developers@7digital.com'
  s.files       = ["lib/detect_includes.rb", "lib/methods.rb"]
  s.homepage    = 'https://github.com/7digital/fastly-deploy'
  s.executables << 'deploy.rb'
  s.license     = 'MIT'
  s.add_runtime_dependency 'fastly', '~> 1.4'
  s.add_runtime_dependency 'colorize', '~> 0.8'
  s.add_development_dependency 'rspec', '~> 11.2'
  s.add_development_dependency 'rake', '~> 3.5'
end
