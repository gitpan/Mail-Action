#! perl

use Module::Build;

my $class = Module::Build->subclass(
	class => 'Module::Build::FilterTests',
	code  => <<'END_HERE',
	
	use File::Glob;
	use File::Spec::Functions;
	
	sub ACTION_disttest
	{
		my $self = shift;
		local $ENV{PERL_RUN_ALL_TESTS} = 1;
		$self->SUPER::ACTION_disttest( @_ );
	}
	
	sub find_test_files
	{
		my $self  = shift;
		my $tests = $self->SUPER::find_test_files( @_ );
	    
		return $tests unless $ENV{PERL_RUN_ALL_TESTS};
	
		my $test_pattern = catfile(qw( t developer *.t ) );
		unshift @$tests, File::Glob::bsd_glob( $test_pattern );
		return $tests;
	}
END_HERE
);

my $builder = $class->new(
	module_name => 'Mail::Action',
	license     => 'perl',
	requires    =>
	{
		'Class::Roles'           => '0.30',
		'Email::Address'         => '',
		'Email::MIME'            => '',
		'Email::MIME::Modifier'  => '',
		'Email::Simple'          => '',
		'Email::Simple::Headers' => '',
		'Mail::Mailer'           => '',
		'Pod::Simple'            => '',
		'YAML'                   => '0.35',
	},
	build_requires =>
	{
		'IO::File'               => '',
		'Test::Exception'        => '',
		'Test::MockObject'       => '0.11',
		'Test::Simple'           => '0.47',
        'Test::Class'            => '',
	},
	dist_version_from => 'lib/Mail/Action.pm',
    dist_author         => 'chromatic <chromatic@wgz.org>',
);

$builder->create_build_script();
