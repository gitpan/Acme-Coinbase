#!/usr/bin/perl -w 
# vim: set ts=4 sw=4 expandtab showmatch

use strict;
use Getopt::Long; 
use Acme::Coinbase::DefaultAuth;
use Acme::Coinbase::Config;
use File::Basename;
use Digest::SHA qw(hmac_sha256_hex); 
use LWP::UserAgent;
use Data::Dumper;
use Carp;

my $prog = basename($0);
my $verbose;
my $auth = Acme::Coinbase::DefaultAuth->new();
my $nonce = time();
my $config_file = $ENV{HOME} . "/.acmecoinbase.ini";

# Usage() : returns usage information
sub Usage {
    "$prog [--verbose] [--config=CONF.ini]\n";
}

# call main()
main();

# main()
sub main {
    GetOptions(
        "verbose!" => \$verbose,
        "config-file=s" => \$config_file,
    ) or die Usage();
    #$SIG{__WARN__} = sub { Carp::confess $_[0] };
    #$SIG{__DIE__} = sub { Carp::confess $_[0] };

    #print "$prog: NONCE: $nonce\n";
    my $base = "https://api.coinbase.com/api";
    my $url  = "$base/v1/account/balance";

    my $config = Acme::Coinbase::Config->new( config_file => $config_file );
    $config->read_config();
    my $api_key    = $config->get_param("default", "api_key")    || $auth->api_key(); 
    my $api_secret = $config->get_param("default", "api_secret") || $auth->api_secret();
    print "$prog: using API key $api_key\n";

    perform_request( $url, $api_key, $api_secret, $verbose );
}


sub perform_request {
    my ( $url, $api_key, $api_secret, $verbose ) = @_;
    if (0) {
        # USE CURL TO DO BASIC REQUEST
        my $sig  = hmac_sha256_hex($nonce . $url, $api_secret); # this is wrong
        my $curl = "curl";
        if ($verbose) { $curl .= " --verbose"; }
        my $cmd = "$curl " . 
                    " -H 'Accept: */*' " . 
                    " -H 'Host: coinbase.com' " . 
                    " -H 'ACCESS_KEY: $api_key' " . 
                    " -H 'ACCESS_NONCE: $nonce' " .
                    " -H 'ACCESS_SIGNATURE: $sig' " .
                    " $url";
        print "$cmd\n";
        system( $cmd );
        print "\n";
    } else {
        # use LWP::UserAgent
        my $ua = LWP::UserAgent->new();
        $ua->default_headers->push_header( Accept       => "*/*" );
        $ua->default_headers->push_header( ACCESS_KEY   => $api_key );
        $ua->default_headers->push_header( ACCESS_NONCE => $nonce );
        $ua->default_headers->push_header( Host         => "coinbase.com" );

        # add ACCESS_SIGNATURE in a request_prepare handler so we can set it knowing the request content
        # ... it doesn't matter for GETs though because the content should be blank (like we see in our code)
        $ua->add_handler( 
            request_prepare => sub { 
                my($request, $ua, $h) = @_; 
                my $content = $request->decoded_content();  # empty string.
                $content = "" unless defined($content);
                my $sig = hmac_sha256_hex( $nonce . $url . $content, $api_secret ); # this conforms to spec but is wrong. won't validate
                #print "$prog: in callback, setting header ACCESS_SIGNATURE => $sig\n";
                $request->headers->push_header( ACCESS_SIGNATURE => $sig );
            }
        );

        # a handler to dump out the request for debugging
        #$ua->add_handler( request_send => sub { shift->dump; return });

        my $response = $ua->get( $url );

        if ($response->is_success) {
            print( "$prog: Success: " . $response->decoded_content );  # or whatever
        } else {
            die ("$prog: Error: " . $response->status_line . ", content: " . $response->decoded_content);
        }
    }
}

__END__
GET /api/v1/account/balance HTTP/1.1
Accept: */*
User-Agent: Ruby
ACCESS_KEY: <YOUR-API-KEY>
ACCESS_SIGNATURE: <YOUR-COMPUTED-SIGNATURE>
ACCESS_NONCE: <YOUR-UPDATED-NONCE>
Connection: close
Host: coinbase.com

