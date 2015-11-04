include "has_include";
include "new_test_include";

sub vcl_recv {
#FASTLY recv
  
  error 900;
}

sub vcl_error {
#FASTLY error
  call has_include_vcl_include_test;
  call test_include_vcl_include_test;
  call new_test_include_vcl_include_test;
  if(obj.status == 900) {
    set obj.status = 400;
    set obj.response = "BAD REQUEST";
    synthetic "ERROR";
    return(deliver);
  }
}