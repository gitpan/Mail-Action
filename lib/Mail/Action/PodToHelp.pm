package Mail::Action::PodToHelp;

use strict;
use base 'Pod::Simple::Text';

sub show_headings
{
	my $parser = shift;
	$parser->{_show_headings} = { map { $_ => 1 } @_ };
}

sub start_head1
{
	my $parser = shift;
	$parser->{_in_head1} = 1;
	$parser->SUPER::start_head1( @_ );
}

sub start_item_bullet
{
	my $parser = shift;
	return unless $parser->{_show};
	$parser->SUPER::start_item_bullet( @_ );
}

sub end_item_bullet
{
	my $parser = shift;
	return unless $parser->{_show};
	$parser->SUPER::end_item_bullet( @_ );
}

sub handle_text
{
	my ($parser, $text) = @_;

	if ( $parser->{_in_head1} )
	{
		$parser->{_show} = exists $parser->{_show_headings}{$text} ? 1 : 0;
	}

	return unless $parser->{_show};
	$parser->SUPER::handle_text( $text );
}

sub end_head1
{
	my $parser = shift;
	$parser->{_in_head1} = 0;
	$parser->SUPER::end_head1( @_ );
}

1;
__END__

=head1 NAME

Mail::SimpleList::PodToHelp - module to produce help messages from the MSL docs

=head1 SEE ALSO

L<Pod::Simple>, L<Pod::Simple::Text>

=head1 COPYRIGHT

Copyright (c) 2003, chromatic.  All rights reserved.  This module is
distributed under the same terms as Perl itself, in the hope that it is useful
but certainly under no guarantee.  Hey, it saved retyping.
