package Plack::Middleware::Test::Recorder;

use strict;
use 5.008_001;
our $VERSION = '0.01';

use parent qw(Plack::Middleware);
use Carp ();
use Plack::Request;
use Data::Dump;

sub call {
    my($self, $env) = @_;

    if ($env->{PATH_INFO} eq '/recorder/start') {
        Carp::carp("Use a single process server like Standalone to run Test::Recorder middleware")
            if $env->{'psgi.multiprocess'};
        $self->{recording} = 1;
        $self->{requests}  = [];
        return [ 200, ["Content-Type", "text/plain"], [ "Recording..." ] ];
    } elsif ($env->{PATH_INFO} eq '/recorder/stop') {
        $self->{recording} = 0;
        return [ 200, ["Content-Type", "text/plain"], [ $self->generate_test ] ];
    }

    return $self->app->($env) unless $self->{recording};

    my $req = Plack::Request->new($env);
    push @{$self->{requests}}, $self->dump_req($req);

    $self->app->($env);
}

sub dump_req {
    my($self, $req) = @_;
    my $params = $req->method eq 'POST' ? $req->body_parameters : undef;

    # Hack: Plack::Request should support rewindable psgi.input with a temp file
    # also, PerlIO handle doesn't have seek method unless FileHandle.pm is loaded (WTF)
    seek $req->env->{'psgi.input'}, 0, 0;

    return [ lc $req->method, $req->request_uri, $params ];
}

sub generate_test {
    my $self = shift;

    my $test = <<'TEMPLATE';
use strict;
use warnings;
use Test::More;
use Test::WWW::Mechanize::PSGI;

my $app = sub { }; # <- fill in your app here!
my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);

TEMPLATE

    for my $request (@{$self->{requests} || []}) {
        my($method, $uri, $params) = @$request;
        $test .= qq{\$mech->$method('$uri'};
        $test .= ', ' . Data::Dump::dump($params) if $params;
        $test .= ");\n";
    }

    $test .= "\ndone_testing;\n";

    return $test;
}

1;
__END__

=encoding utf-8

=for stopwords

=head1 NAME

Plack::Middleware::Test::Recorder - Record requests to replay as a unit test

=head1 SYNOPSIS

  enable "Test::Recorder";

  # access /recorder/start to start recording
  # access /recorder/stop to stop and save a test file

=head1 DESCRIPTION

Plack::Middleware::Test::Recorder is a Plack middleware component to
record HTTP requests and saves them as a Perl unit test script using
L<Test::WWW::Mechanize::PSGI>.

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

Moritz Onken wrote L<CatalystX::Test::Recorder> which inspires this module.

Leon Brocard wrote L<Test::WWW::Mechanize::PSGI>.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<CatalystX::Test::Recorder> L<Test::WWW::Mechanize::PSGI>

=cut
