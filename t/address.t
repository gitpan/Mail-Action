#!/usr/bin/perl -w

BEGIN
{
	chdir 't' if -d 't';
	use lib '../lib', '../blib/lib';
}

use strict;
use Test::More tests => 21;

my $module = 'Mail::Action::Address';
use_ok( $module ) or exit;

my $add = bless {}, $module;

can_ok( $module, 'description' );
is( $add->description(), '',
	'description() should be blank unless set in constructor' );

$add->{description} = 'now set';
is( $add->description(), 'now set',
	'... or whatever is set in constructor' );

$add->description( 'set here' );
is( $add->description(), 'set here',
	'... and should be able to set description' );

can_ok( $module, 'name' );
is( $add->name(), undef, 'name() should be undef unless set in constructor' );

$add->{name} = 'newname';
is( $add->name(), 'newname', '... or whatever is set' );

$add->name( '!my Name$ ' );
is( $add->name(), 'myName',  '... or cleaned name, if mutator' );

can_ok( $add, 'process_time' );
is( $add->process_time( 100 ), 100,
	                      'process_time() should return raw seconds directly' );
is( $add->process_time( '1d' ), 24 * 60 * 60,
	                      '... processing days correctly' );
is( $add->process_time( '2w' ), 2 * 7 * 24 * 60 * 60,
	                      '... processing weeks correctly' );
is( $add->process_time( '4h' ), 4 * 60 * 60,
	                      '... processing hours correctly' );
is( $add->process_time( '8m' ), 8 * 60,
	                      '... processing minutes correctly' );
is( $add->process_time( '16M' ), 16 * 30 * 24 * 60 * 60,
	                      '... processing months correctly' );
is( $add->process_time( '1M2w3d4h5m' ),
	   30 * 24 * 60 * 60 +
	2 * 7 * 24 * 60 * 60 +
	3     * 24 * 60 * 60 +
	4     * 60 * 60 +
	5          * 60,     '... even in a nice list' );

can_ok( $add, 'expires' );
$add->{expires} = 1003;
is( $add->expires(), 1003,
	'expires() should report expiration time from constructor' );
my $expiration = time() + 100;
$add->expires( 100 );
ok( $add->expires() - $expiration < 10, '... and should set expiration' )
	or diag "Possible clock skew: (" . $add->expires() . ") [$expiration]\n";

my $time = time() + 7 * 24 * 60 * 60;
is( $add->expires( '7d' ), $time, '... parsing days correctly' );
