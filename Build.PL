use Module::Build;

my $build = Module::Build->new(
	module_name => 'Mail::Action',
	license     => 'perl',
	requires    =>
	{
		'Class::Roles'          => '0.30',
		'Email::Address'        => '',
		'Email::MIME'           => '',
		'Email::MIME::Modifier' => '',
		'Email::Simple'         => '',
		'Pod::Simple'           => '',
		'YAML'                  => '0.35',
	},
	build_requires =>
	{
		'IO::File'              => '',
		'Test::Exception'       => '',
		'Test::MockObject'      => '0.11',
		'Test::Simple'          => '0.47',
	},
	dist_version_from => 'lib/Mail/Action.pm',
);

$build->create_build_script();
