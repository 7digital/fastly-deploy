def get_includes(main_vcl_path, includes_dir)
  return get_includes_for_vcl main_vcl_path, includes_dir
end

def get_includes_for_vcl(vcl_path, includes_dir)
  direct_includes = get_includes_directly_in_vcl vcl_path, includes_dir

  inner_includes = direct_includes.map{| include_vcl | get_includes_for_vcl include_vcl, includes_dir}.flatten
  return (direct_includes.concat inner_includes).uniq
end

def get_includes_directly_in_vcl(vcl_path, includes_dir) 
  return File.readlines(vcl_path).select { |line| /^include "(.*)"$/.match(line) }
            .map{ |line| /^include "(.*)"$/.match(line)[1] }
            .map{ |vcl_file_name| File.join(includes_dir, vcl_file_name + ".vcl")}
end