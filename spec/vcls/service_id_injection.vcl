sub vcl_error {
#FASTLY error
  set obj.response = "#FASTLY_SERVICE_ID";
}