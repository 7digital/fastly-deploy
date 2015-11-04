def get_active_version
  service = @fastly.get_service(@service.id)
  active_version = service.versions.find{|ver| ver.active?}
  return active_version
end  

def upload_main_vcl_to_version(version, file_path)
  upload_vcl_to_version(version, file_path, "Main")
  version.vcl("Main").set_main!
end 

def upload_vcl_to_version(version, file_path, name)
  vcl_contents = File.read(file_path)
  version.upload_vcl name, vcl_contents
end 

def expect_vcl_to_contain(version, name, regex)
  vcl = version.vcl(name)
  expect(vcl.content).to match(regex)
end  