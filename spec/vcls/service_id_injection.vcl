sub vcl_error {
#FASTLY error
  set obj.response = "#7D_FASTLY_SERVICE_ID";
}