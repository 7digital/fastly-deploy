def get_includes(main_vcl_path, includes_dir)
  includes_found = []
  get_includes_for_vcl main_vcl_path, includes_dir, includes_found
  return includes_found
end

def get_includes_for_vcl(vcl_path, includes_dir, includes_found)
  direct_includes = get_includes_directly_in_vcl vcl_path, includes_dir
  direct_includes_not_already_found = direct_includes - includes_found

  direct_includes_not_already_found.map do |include_vcl|
    includes_found.push include_vcl
    get_includes_for_vcl include_vcl, includes_dir, includes_found
  end
end

def get_includes_directly_in_vcl(vcl_path, includes_dir)
  # Using '$' for line ending is os dependent and fails w/windows line endings on linux
  include_pattern = /^include "(.*)";?[\r\n]+/
  return File.readlines(vcl_path).select { |line| include_pattern.match(line) }
            .map{ |line| include_pattern.match(line)[1] }
            .map{ |vcl_file_name| File.join(includes_dir, vcl_file_name + '.vcl')}
end
