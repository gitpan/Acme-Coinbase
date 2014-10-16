package Acme::Coinbase::DefaultAuth;
# vim: set ts=4 sw=4 expandtab showmatch
#
use strict;

# FOR MOOSE
use Moose; # automatically turns on strict and warnings

# these are for our TEST account 
has 'api_key'    => (is => 'rw', isa => 'Str', default=>"pl5Yr4RK487wYpB2");
has 'api_secret' => (is => 'rw', isa => 'Str', default=>"TusAkTDkRqtDJrSXzn06aUCa6e8gt8Bh");

1;
