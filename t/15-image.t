use lib qw( t/lib lib extlib plugins/AtomPub/lib plugins/AtomPub/t/lib );

use strict;
use warnings;

BEGIN {
    $ENV{MT_APP} = 'AtomPub::Server';
}

use MT::Test qw( :app :db :data );
use Test::More tests => 16;

use AtomPub::Test qw( wsse_auth run_app );
use File::Spec;
use XML::LibXML;


{
    my $bodyfile = File::Spec->catfile($ENV{MT_HOME}, 't', 'images', 'test.gif');
    open my $fh, '<', $bodyfile;
    binmode $fh;
    my $body = eval { local $/; <$fh> };
    close $fh;

    my $resp = run_app('http://www.example.com/plugins/AtomPub/mt-atom.cgi/1.0/blog_id=1', 'POST',
        { 'Content-Type' => 'image/gif', wsse_auth() }, $body);
    diag($resp->as_string);
    is($resp->code, 201, "New post request succeeded (HTTP Created)");
    like($resp->header('Content-Type'), qr{ \A application/atom\+xml }xms, "Response creating entry is some Atom document");

    # Uploading an image creates an asset, not an entry.
    is($resp->header('Location'), "http://www.example.com/plugins/AtomPub/mt-atom.cgi/1.0/blog_id=1/asset_id=1",
        "Response creating entry includes API URL of new asset");
}


1;
