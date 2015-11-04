sub vcl_include_test{
  set obj.status = 563;
  set obj.response = "#7D_FASTLY_SERVICE_ID";
}