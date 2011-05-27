use lib qw( t/lib lib extlib plugins/AtomPub/lib );

use strict;
use warnings;

BEGIN {
    $ENV{MT_APP} = 'AtomPub::Server';
}

use MT::Test qw( :app :db :data );
use Test::More tests => 9;

use Digest::SHA1 qw( sha1 );
use HTTP::Response 5;
use LWP::Authen::Wsse;
use MIME::Base64 qw( encode_base64 );
use XML::LibXML;


out_like(
    'AtomPub::Server',
    {},
    qr{ Status:\s200 \b .* \b 1 \z }xms,
    "Just a 1 on the root URL",
);

out_like(
    'AtomPub::Server',
    {
        __test_path_info => q{1.0},
    },
    qr{ Status:\s401 }xms,
    "Unauthorized on the weblogs URL",
);
like(get_last_output(), qr{ X-WSSE }xms, "Unauthorized error message on the weblogs URL");

{
    local $ENV{HTTP_AUTHORIZATION} = q{Derp herp="derp"};
    out_like(
        'AtomPub::Server',
        {
            __test_path_info => q{1.0},
        },
        qr{ Status:\s401 }xms,
        "Unauthorized on the weblogs URL with bad auth",
    );
    like(get_last_output(), qr{ X-WSSE }xms, "Unauthorized error message on the weblogs URL with bad auth");
}

sub wsse_auth {
    my $username = "Chuck D";
    my $password = "seecret";
    my $nonce_raw = LWP::Authen::Wsse->make_nonce();
    my $created = LWP::Authen::Wsse->now_w3cdtf();

    my $digest = encode_base64(sha1($nonce_raw . $created . $password), q{});
    my $nonce = encode_base64($nonce_raw, q{});

    return (
        Authorization => q{WSSE profile="UsernameToken"},
        'X-WSSE' => qq{UsernameToken Username="$username", PasswordDigest="$digest", Nonce="$nonce", Created="$created"},
    );
}

sub run_app {
    my ($url, $method, $headers, $body) = @_;
    if ($url !~ m{ \A \w+:// ([^/]+) (/.* mt-atom\.cgi ) (.*)? \z }xms) {
        die "Couldn't parse AtomPub url parts out of URL '$url'";
    }
    my ($host, $path, $extra) = ($1, $2, $3);

    local %ENV = %ENV;
    $ENV{HTTP_HOST} = $host;
    $ENV{REQUEST_URI} = $path;

    $headers ||= {};
    while (my ($header, $value) = each %$headers) {
        my $env_header = uc $header;
        $env_header =~ tr/-/_/;
        $ENV{"HTTP_$env_header"} = $value;
    }

    my $app = _run_app('AtomPub::Server', { __test_path_info => $extra });
    my $out = delete $app->{__test_output};

    my $resp = HTTP::Response->parse($out);
    return $resp;
}

{
    my $resp = run_app('http://www.example.com/plugins/AtomPub/mt-atom.cgi/1.0', 'GET', { wsse_auth() });
    is($resp->code, 200, "Authorized weblogs request succeeded");
    like($resp->header('Content-Type'), qr{ \A application/atomsvc\+xml }xms, "Authorized weblogs response is a service document");

    my $doc = XML::LibXML->load_xml(string => $resp->decoded_content);
    my $root = $doc->documentElement;
    is($root->nodeName, 'service', "Service document starts with a service tag");

    my $xpath = XML::LibXML::XPathContext->new;
    $xpath->registerNs('app', 'http://www.w3.org/2007/app');
    my @collections = $xpath->findnodes('//app:collection', $root);
    is(scalar @collections, 1, "Service document lists two collections");
    my ($coll) = @collections;
    is($coll->getAttribute('href'), q{http://www.example.com/plugins/AtomPub/mt-atom.cgi/1.0/blog_id=1}, "Collection has blog 1's AtomPub endpoint");
}


1;
