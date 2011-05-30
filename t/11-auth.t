use lib qw( t/lib lib extlib plugins/AtomPub/lib plugins/AtomPub/t/lib );

use strict;
use warnings;

BEGIN {
    $ENV{MT_APP} = 'AtomPub::Server';
}

use MT::Test qw( :app :db :data );
use Test::More tests => 6;

use AtomPub::Test qw( wsse_auth run_app );
use XML::LibXML;


{
    my $resp = run_app('http://www.example.com/plugins/AtomPub/mt-atom.cgi/1.0', 'GET');
    is($resp->code, 401, "Weblogs URL with no auth returns Unauthorized");
    like($resp->decoded_content, qr{ X-WSSE }xms, "Unauthorized error message mentions X-WSSE header");
}

{
    my $resp = run_app('http://www.example.com/plugins/AtomPub/mt-atom.cgi/1.0', 'GET', {
        Authorization => q{Derp herp="derp"},
    });
    is($resp->code, 401, "Weblogs URL with made-up auth returns Unauthorized");
    like($resp->decoded_content, qr{ X-WSSE }xms, "Unauthorized error message mentions X-WSSE header");
}

{
    my $resp = run_app('http://www.example.com/plugins/AtomPub/mt-atom.cgi/1.0', 'GET', { wsse_auth() });
    is($resp->code, 200, "WSSE authorized weblogs request succeeded");
    like($resp->header('Content-Type'), qr{ \A application/atomsvc\+xml }xms, "Authorized weblogs response is a service document");
}


1;
