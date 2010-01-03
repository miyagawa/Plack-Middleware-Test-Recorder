use strict;
use Plack::Test;
use Test::More;
use HTTP::Request::Common;

use Plack::Builder;
use Plack::Request;

my $app = sub {
    my $req = Plack::Request->new(shift);
    return [ 200, ["Content-Type","text/html"], [<<HTML] ];
Hello @{[$req->param('name')]}
<form method="post">
Name: <input type="text" name="name" />
<input type="submit"/>
</form>
HTML
};

my $t = builder {
    enable "Test::Recorder";
    $app;
};

test_psgi $t, sub {
    my $cb = shift;

    my $res = $cb->(GET "/recorder/start");
    like $res->content, qr/Recording/;

    $res = $cb->(GET "/?name=foo");
    like $res->content, qr/Hello foo/;

    $res = $cb->(POST "/", [ name => 'bar' ]);
    like $res->content, qr/Hello bar/;

    $res = $cb->(GET "/recorder/stop");
    is $res->content_type, 'text/plain';
};

done_testing;


