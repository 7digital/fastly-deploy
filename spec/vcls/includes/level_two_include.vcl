include "level_three_include";

sub vcl_include_test{
  set obj.status = 201;
}