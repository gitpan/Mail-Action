#!/usr/bin/perl -w

BEGIN
{
	chdir 't' if -d 't';
	use lib '../lib', '../blib/lib';
}

use strict;

use IO::File;
use Email::MIME;
use Email::MIME::Modifier;

use Test::More tests => 50;
use Test::MockObject;
my $mock_mail = Test::MockObject->new();
$mock_mail->fake_module( 'Mail::Mailer', new => sub { $mock_mail } );

my $module = 'Mail::Action';
use_ok( $module ) or exit;

can_ok( $module, 'new' );
can_ok( $module, 'storage' );
can_ok( $module, 'message' );

my $ma;
{
	local *Mail::Action::storage_class;
	*Mail::Action::storage_class = sub { 'Foo' };

	package Foo;
	sub new { 'a foo:' . $_[1] };

	package main;

	my $message = <<'END_HERE';
From: me@home
To: you@house
Subject: Hi there

Hello!

Well, bye.
END_HERE

	$ma   = $module->new( 'dir', $message );

	like( $ma->message->body(), qr/Hello!/,
		'... should set messsage from string given only two arguments' );

	my $fh  = IO::File->new_tmpfile();
	my $pos = $fh->getpos();
	$fh->print( $message );
	$fh->setpos( $pos );

	$ma   = $module->new( 'dir', $fh );
	like( $ma->message->body(), qr/Hello!/,
		'... or from filehandle, given only two arguments' );

	$fh->setpos( $pos );
	my %options = ( Filehandle => $fh );
	$ma   = $module->new( 'dir', %options );
	like( $ma->message->body(), qr/Hello!/,
		'... or from filehandle, when passed as Filehandle option' );

	$options{Filehandle} = $message;
	$ma   = $module->new( 'dir', %options );
	like( $ma->message->body(), qr/Hello!/,
		'... or from string, when passed as Filehandle option (yow!)' );

	$ma   = $module->new( 'dir', %options );
	like( $ma->storage(), qr/^a foo/,
		'new() should default to storage_class() storage object' ); 

	is( $ma->storage(), 'a foo:dir', '... passing address directory' );

	$options{Addresses} = 'addresses';
	$ma    = $module->new( 'dir', %options );
	is( $ma->storage(), 'addresses', '... or Addresses option' ); 

	$options{Storage} = 'storage';
	$ma    = $module->new( 'dir', %options );
	is( $ma->storage(), 'storage', '... preferring Storage option' ); 

	close STDIN;
	SKIP:
	{
		$fh  = IO::File->new_tmpfile();
		skip( 'Cannot reuse fd 1', 1 ) unless fileno( $fh ) == 0;

		$pos = $fh->getpos();
		$fh->print( $message );
		$fh->setpos( $pos );

		$ma   = $module->new( 'dir', $fh );
		like( $ma->message->body(), qr/Hello!/,
			'... or should read from STDIN, given only one argument' );
	}
}

can_ok( $module, 'fetch_address' );

my $mock_store = Test::MockObject->new()
	->set_series( exists => 0, 1, 1 )
	->set_always( fetch  => 'addy'  );

$ma->{Storage} = $mock_store;

{
	local *Mail::Action::parse_alias;
	*Mail::Action::parse_alias = sub { return 'alias' };

	is( $ma->fetch_address(), undef,
		'fetch_address() should return undef unless address exists' );
	is( $ma->fetch_address(), 'addy',
		'... or existing address, in scalar context' );

	is_deeply( [ $ma->fetch_address() ], [qw( addy alias )],
		'... or address and alias, in list context' );
}

can_ok( $module, 'command_help' );

$mock_mail->set_true( 'open' )
	->set_true( 'print' )
	->set_true( 'close' );

my $pod =<<END_HERE;
=head1 FOO

some text

=head1 USING LISTS

more text

=head1 DIRECTIVES

Yet More Text.

=head1 CREDITS

no one of consequence
END_HERE

$ma->message->header_set( 'From', 'some@here' );
$ma->command_help( $pod, 'USING LISTS', 'DIRECTIVES' );

my ($method, $args) = $mock_mail->next_call();
is( $args->[1]{To},      '<some@here>',
	'command_help() should reply to sender' );
is( $args->[1]{Subject}, 'Mail::Action Help',
	'... with appropriate subject' );
($method, $args) = $mock_mail->next_call();
is( $args->[1],
	"USING LISTS\n\n    more text\n\nDIRECTIVES\n\n    Yet More Text.",
	'... with text extracted from passed-in POD' );

can_ok( $module, 'address_field' );
$ma->message->header_set( 'From', 'some@here, guy@there' );
is( $ma->address_field( 'From' ), '<some@here>',
	'address_field() should return first formatted address in scalar context' );

my @addresses = map { Email::Address->parse( $_ ) } 'some@here', 'guy@there';
my @found     = $ma->address_field( 'From' ) ;
is( @found, 2, '... or a list of Email::Address objects in list context' );
is_deeply( [ map { $_->format() } @found ], [ map { $_->format() } @addresses ],
	'... in the proper order' );

can_ok( $module, 'process_body' );

$mock_store->set_always( attributes => { foo => 1, bar => 1 } )
	->set_true( 'foo' )
	->set_true( 'bar' )
	->clear();

$ma->message->body_set(
	"Foo: foo\nCar: vroom\nbaR: b a r\n\nMy: friend\nhi\n-- \nFOO: moo"
);

is_deeply( $ma->process_body( $mock_store ), [ '', 'My: friend', 'hi' ],
	'process_body() should return message without directives or signature' );
($method, $args) = $mock_store->next_call( 2 );
is( $method,    'foo',   '... calling directive found' );
is( $args->[1], 'foo',   '... passing directive value found' );
($method, $args) = $mock_store->next_call();
isnt( $method,  'car',   '... not calling unknown directive' );
is( $method,    'bar',   '... lowercasing directive name' );
is( $args->[1], 'b a r', '... passing entire directive value found' );

can_ok( $module, 'remove_sig' );

$ma->message->body_set( "some\nlines\n-- \nmy sig" );
is_deeply( $ma->remove_sig(), [ 'some', 'lines' ],
	'remove_sig() should return sig lines from message' );

$ma->message->body_set( "some\nlines\n-- \nmy sig" );
my $part = Email::MIME->new( "more\nlines\n" );
$ma->message->parts_set( [ $ma->message(), $part ] );
is_deeply( $ma->remove_sig(), [ 'some', 'lines' ],
	'... including MIME messages with multiple parts' );

can_ok( $module, 'reply' );

$mock_mail->clear();

$ma->reply( 'headers', 'body', 'lines' );
($method, $args) = $mock_mail->next_call();
is( $method,    'open',    'reply() should open a Mail::Mailer object' );
is( $args->[1], 'headers', '... passing headers' );

($method, $args)    = $mock_mail->next_call();
is( $method,    'print',               '... printing body' );
is( "@$args", "$mock_mail body lines", '... all lines passed' );
is( $mock_mail->next_call(), 'close',  '... closing message' );

can_ok( $module, 'find_command' );

is( $ma->find_command(), undef,
	'find_command() should return undef without a valid command' );
$ma->message->header_set( 'Subject', '*help*' );
is( $ma->find_command(), 'command_help',
	'... or the name of the command sub, if it exists' );
$ma->message->header_set( 'Subject', '*hElP*' );
is( $ma->find_command(), 'command_help', '... regardless of capitalization' );
$ma->message->header_set( 'Subject', '*drinkME*' );
is( $ma->find_command(), '',
	'... or an empty string if command does not match' );

can_ok( $module, 'copy_headers' );

$ma->message->header_set( 'Subject', '*help*' );
$ma->message->header_set( 'From', 'me@home' );
$ma->message->header_set( 'From ', 1 );
$ma->message->{head}{'cC'}    = [ 1 ];
delete $ma->message->{head}{'Content-Type'};

my $result = $ma->copy_headers();

isnt( $result, $ma->message->{head}, 'copy_headers() should make a new hash' );
is_deeply( $result,
	{ From => 'me@home', Subject => '*help*', To => 'you@house', Cc => 1 },
	'... cleaning header names' );
ok( ! exists $result->{'From '}, '... removing mbox From header' );
