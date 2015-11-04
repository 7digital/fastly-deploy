def get_includes(main_vcl_path)
  return File.readlines(main_vcl_path).select { |line| /^include "(.*)"$/.match(line) }
            .map{ |line| /^include "(.*)"$/.match(line)[1] }
end  