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
my $config_file;# = $ENV{HOME} . "/.acmecoinbase.ini";
my $use_curl = 0;

# Usage() : returns usage information
sub Usage {
    "$prog [--verbose] [--use-curl] [--nonce=NONCE] [--config=CONF.ini]\n";
}

# call main()
main();

# main()
sub main {
    GetOptions(
        "verbose!" => \$verbose,
        "config-file=s" => \$config_file,
        "use-curl" => \$use_curl,
        "nonce=n" => \$nonce,
    ) or die Usage();
    $SIG{__WARN__} = sub { Carp::confess $_[0] };
    $SIG{__DIE__} = sub { Carp::confess $_[0] };

    #print "$prog: NONCE: $nonce\n";
    my $base = "https://api.coinbase.com/api";
    my $url  = "$base/v1/account/balance";

    my $default_config_file = $ENV{HOME} . "/.acmecoinbase.ini";
    if (!$config_file && -e $default_config_file) {
        $config_file = $default_config_file;
    }
    my $config = Acme::Coinbase::Config->new( );
    if ($config_file && -e $config_file) {
        $config->config_file($config_file);
        $config->read_config();
    }
    my $api_key    = $config->get_param("default", "api_key")    || $auth->api_key(); 
    my $api_secret = $config->get_param("default", "api_secret") || $auth->api_secret();
    #print "$prog: using API key $api_key\n";

    perform_request( $url, $api_key, $api_secret, $verbose );
}


sub perform_request {
    my ( $url, $api_key, $api_secret, $verbose ) = @_;
    if ($use_curl) {
        # use curl to do basic request
        my $sig  = hmac_sha256_hex($nonce . $url . "", $api_secret); 
            # somehow this is different than what we get from non-curl
        print "$prog: in callback, str=$nonce$url, ACCESS_SIGNATURE => $sig\n";
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

                my $to_hmac = $nonce . $url . $content;
                my $sig = hmac_sha256_hex( $to_hmac, $api_secret ); 
                print "$prog: in callback, str=$to_hmac, ACCESS_SIGNATURE => $sig\n";
                $request->headers->push_header( ACCESS_SIGNATURE => $sig );
            }
        );

        if ($verbose) {
            # a handler to dump out the request for debugging
            $ua->add_handler( request_send => sub { 
                    print "$prog: verbose mode: BEGIN dump of request object: ***********\n";
                    shift->dump; 
                    print "$prog: verbose mode: END dump of request object: *************\n";
                    return 
                });
        }

        my $response = $ua->get( $url );

        my $noun = $response->is_success() ? "Success" : "Error";
        print ("$prog: $noun " . $response->status_line . ", content: " . $response->decoded_content . "\n");
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

