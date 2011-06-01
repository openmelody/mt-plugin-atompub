use lib qw( t/lib lib extlib plugins/AtomPub/lib plugins/AtomPub/t/lib );

use strict;
use warnings;

BEGIN {
    $ENV{MT_APP} = 'AtomPub::Server';
}

use MT::Test qw( :app :db :data );
use Test::More tests => 18;

use AtomPub::Test qw( basic_auth run_app );
use File::Spec;
use XML::LibXML;


sub load_test_gif {
    my $bodyfile = File::Spec->catfile($ENV{MT_HOME}, 't', 'images', 'test.gif');
    open my $fh, '<', $bodyfile;
    binmode $fh;
    my $body = eval { local $/; <$fh> };
    close $fh;

    return $body;
}

{
    my $body = load_test_gif();
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

# 'Slug' header used for filename with raw uploads
{
    my $body = load_test_gif();
    my $resp = run_app('http://www.example.com/plugins/AtomPub/mt-atom.cgi/1.0/blog_id=1', 'POST', {
        'Content-Type' => 'image/gif',
        'Slug' => 'super-awesome-mega-gif.gif',
        basic_auth()
    }, $body);
    is($resp->code, 201, "New post request succeeded (HTTP Created)");
    like($resp->header('Content-Type'), qr{ \A application/atom\+xml }xms, "Response creating asset is some Atom document");

    is($resp->header('Location'), 'http://www.example.com/plugins/AtomPub/mt-atom.cgi/1.0/blog_id=1/asset_id=4',
        "Response creating new asset includes API URL of new asset");

    my $doc = XML::LibXML->load_xml( string => $resp->decoded_content );
    my $root = $doc->documentElement;
    my $xpath = XML::LibXML::XPathContext->new;
    $xpath->registerNs('app', 'http://www.w3.org/2007/app');
    $xpath->registerNs('atom', 'http://www.w3.org/2005/Atom');

    my ($content) = $xpath->findnodes('./atom:content', $root);
    is($content->getAttribute('src'), 'http://narnia.na/nana/super-awesome-mega-gif.gif',
        "Created asset's file used Slug header for filename");
}

# blog posts that refer to assets cause MT::ObjectAsset associations
{
    my $body = <<'EOF';
<?xml version="1.0" encoding="utf-8"?>
<entry xmlns="http://www.w3.org/2005/Atom">
    <title>Super Awesome Mega Post</title>
    <content type="html">&lt;p&gt;This is the post content that goes in the post.&lt;/p&gt;</content>
    <link rel="related" href="http://www.example.com/plugins/AtomPub/mt-atom.cgi/1.0/blog_id=1/asset_id=4"/>
</entry>
EOF
    my $resp = run_app('http://www.example.com/plugins/AtomPub/mt-atom.cgi/1.0/blog_id=1', 'POST', {
        'Content-Type' => 'application/atom+xml;type=entry',
        'Slug' => 'super-awesome-mega-post',
        basic_auth()
    }, $body);
    is($resp->code, 201, "New post request succeeded (HTTP Created)");
    like($resp->header('Content-Type'), qr{ \A application/atom\+xml }xms, "Response creating post is some Atom document");

    my $location = $resp->header('Location');
    is($location, 'http://www.example.com/plugins/AtomPub/mt-atom.cgi/1.0/blog_id=1/entry_id=24',
        "Response creating new asset includes API URL of new asset");

    my $doc = XML::LibXML->load_xml( string => $resp->decoded_content );
    my $root = $doc->documentElement;
    my $xpath = XML::LibXML::XPathContext->new;
    $xpath->registerNs('app', 'http://www.w3.org/2007/app');
    $xpath->registerNs('atom', 'http://www.w3.org/2005/Atom');

    my ($content) = $xpath->findnodes('./atom:content', $root);
    is($content->getAttribute('type'), 'html', "New post posted as HTML");
    is($content->textContent(), qq{<img alt="" src="http://narnia.na/nana/super-awesome-mega-gif.gif" width="233" height="68"  /><br style="clear: left;" />\n\n<p>This is the post content that goes in the post.</p>}, "New post had intended HTML content");

    my $oa = MT::ObjectAsset->load({
        blog_id => 1,
        asset_id => 4,
        object_id => 24,
        object_ds => 'entry',
    });
    ok($oa, "Creating a new post that linked to a created asset associated them");
}


1;
