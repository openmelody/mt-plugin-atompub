use lib qw( t/lib lib extlib plugins/AtomPub/lib plugins/AtomPub/t/lib );

use strict;
use warnings;

BEGIN {
    $ENV{MT_APP} = 'AtomPub::Server';
}

use MT::Test qw( :app :db :data );
use Test::More tests => 8;

use AtomPub::Test qw( basic_auth run_app );
use File::Spec;
use XML::LibXML;


{
    my $bodyfile = File::Spec->catfile($ENV{MT_HOME}, 't', 'images', 'test.gif');
    open my $fh, '<', $bodyfile;
    binmode $fh;
    my $body = eval { local $/; <$fh> };
    close $fh;

    my $resp = run_app('http://www.example.com/plugins/AtomPub/mt-atom.cgi/1.0/blog_id=1', 'POST',
        { 'Content-Type' => 'image/gif', basic_auth() }, $body);
    is($resp->code, 201, "New post request succeeded (HTTP Created)");
    like($resp->header('Content-Type'), qr{ \A application/atom\+xml }xms, "Response creating asset is some Atom document");

    # Uploading an image creates an asset, not an entry.
    is($resp->header('Location'), "http://www.example.com/plugins/AtomPub/mt-atom.cgi/1.0/blog_id=1/asset_id=3",
        "Response creating asset includes API URL of new asset");

    my $doc = XML::LibXML->load_xml( string => $resp->decoded_content );
    my $root = $doc->documentElement;
    is($root->nodeName, 'entry', "Response creating asset is an Atom entry");

    my $xpath = XML::LibXML::XPathContext->new;
    $xpath->registerNs('app', 'http://www.w3.org/2007/app');
    $xpath->registerNs('atom', 'http://www.w3.org/2005/Atom');

    my @contents = $xpath->findnodes('./atom:content', $root);
    is(scalar @contents, 1, "Response creating asset has one content node");
    my ($content) = @contents;
    is($content->getAttribute('type'), 'image/gif', "Created asset content has the right type");
    is($content->getAttribute('src'), 'http://narnia.na/nana/file', "Created asset content refers to src");
    is(scalar @{[ $content->childNodes() ]}, 0, "Created asset content is an empty node");
}


1;
