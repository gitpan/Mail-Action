#!/usr/bin/perl -w

BEGIN
{
	chdir 't' if -d 't';
	use lib '../lib', '../blib/lib';
}

use strict;
use Test::More tests => 20;
use Test::Exception;

use File::Path;
use File::Spec;

my $module = 'Mail::Action::Storage';
use_ok( $module ) or exit;

mkdir 'storage' unless -d 'storage';

END
{
	rmtree 'storage' unless @ARGV;
}

can_ok( $module, 'new' );
throws_ok { $module->new() } qr/No storage directory/,
	'new() should throw exception without directory given';

my $s = $module->new( 'storage' );
isa_ok( $s, $module, 'new() should return new object, given directory' );

can_ok( $module, 'storage_dir' );
is( $s->storage_dir(), 'storage',
	'storage_dir() should return directory set in constructor' );

can_ok( $module, 'stored_class' );
is( $module->stored_class(), '', 'stored_class() should be blank' );

can_ok( $module, 'storage_extension' );
is( $module->storage_extension(), 'mas',
	'storage_extension() should be mas' );

can_ok( $module, 'storage_file' );
is( $s->storage_file( 'foo' ), File::Spec->catfile( 'storage', 'foo.mas' ),
	'storage_file() should return directory path of file with extension' );

can_ok( $module, 'create' );
# empty body, just exists

can_ok( $module, 'exists' );
ok( ! $s->exists( 'foo' ),
	'exists() should return false unless stored object exists' );

can_ok( $module, 'save' );
$s->save( { foo => 'bar', baz => 'quux', name => 'eks' }, 'eks' );
ok( $s->exists( 'eks' ), 'save() should store file checkable with exists' );

# test fetch()
package Mail::Action::RealAddress;

sub new
{
	my ($class, %args) = @_;
	bless \%args, $class;
}

package Mail::Action::StorageSub;

use base 'Mail::Action::Storage';

sub stored_class
{
	'Mail::Action::RealAddress';
}

package main;

$s = Mail::Action::StorageSub->new( 'storage' );

can_ok( $module, 'fetch' );
my $result = $s->fetch( 'eks' );
is_deeply( $result, { foo => 'bar', baz => 'quux', name => 'eks' },
	'fetch() should return loaded data' );
isa_ok( $result, $s->stored_class(), '... blessed into storage class' );
