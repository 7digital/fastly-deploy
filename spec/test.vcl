sub vcl_recv {
#FASTLY recv
#DEPLOY recv
	error 900;
}

sub vcl_error {
#FASTLY error
#DEPLOY error
	if(obj.status == 900) {
		set obj.status = 400;
		set obj.response = "BAD REQUEST";
		synthetic "ERROR";
		return(deliver);
	}
}
