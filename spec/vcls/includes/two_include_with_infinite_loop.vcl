include "one_include_with_infinite_loop";

sub vcl_include_test{
  set obj.status = 201;
}