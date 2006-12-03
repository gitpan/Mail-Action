#! perl -T

use strict;
use warnings;

use Test::More 'no_plan'; # tests => 1;

my $module = 'Mail::Action::Request';
use_ok( $module ) or exit;
