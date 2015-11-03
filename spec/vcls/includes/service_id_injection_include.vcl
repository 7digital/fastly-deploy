sub vcl_include_test{
  set obj.status = 563
  set obj.response = "#FASTLY_SERVICE_ID";
}