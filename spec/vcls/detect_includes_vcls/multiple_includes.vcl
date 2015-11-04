include "new_test_include"
include "not_uploaded_again_include"

sub vcl_recv {
#FASTLY recv
  error 900;
}

include "test_include"

sub vcl_error {
#FASTLY error
  if(obj.status == 900) {
    set obj.status = 400;
    set obj.response = "BAD REQUEST";
    synthetic "ERROR";
    return(deliver);
  }
}