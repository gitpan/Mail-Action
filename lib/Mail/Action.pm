package Mail::Action;

use strict;

use vars '$VERSION';
$VERSION = '0.20';

use Carp 'croak';

use Mail::Mailer;
use Mail::Address;
use Mail::Internet;

use Mail::Action::PodToHelp;

use vars '$VERSION';

sub new
{
	my ($class, $address_dir, @options, %options, $fh) = @_;
	croak "No address directory provided\n" unless $address_dir;

	if (@options == 1)
	{
		$fh      = $options[0];
	}
	else
	{
		%options = @options if @options;
		$fh      = $options{Filehandle} if exists $options{Filehandle};
	}

	my $storage  = $class->storage_class();
	$fh        ||= \*STDIN;

	bless
	{
		Storage => $options{Storage} || $options{Addresses}
			                         || $storage->new( $address_dir ),
		Message => $options{Message} || Mail::Internet->new( $fh ),
	}, $class;
}

sub storage
{
	my $self = shift;
	   $self->{Storage};
}

sub message
{
	my $self = shift;
	   $self->{Message};
}

sub fetch_address
{
	my $self      = shift;
	my $alias     = $self->parse_alias( $self->message()->get( 'to' ) );
	my $addresses = $self->storage();

	return unless $addresses->exists( $alias );

	my $addy     = $addresses->fetch( $alias );

	return wantarray ? ( $addy, $alias ) : $addy;
}

sub command_help
{
	my ($self, $pod, @headings) = @_;

	my $from   = $self->address_field( 'from' );
	my $parser = Mail::Action::PodToHelp->new();

	$parser->show_headings( @headings );
	$parser->output_string( \( my $output ));
	$parser->parse_string_document( $pod );

	$output =~ s/(\A\s+|\s+\Z)//g;

	$self->reply({
		To      => $from,
		Subject => ref( $self ) . ' Help'
	}, $output );
}

sub address_field
{
	my ($self, $field) = @_;
	my @values = Mail::Address->parse( $self->message->get( $field ) );
	return wantarray ? @values : $values[0]->format();
}

sub process_body
{
	my ($self, $address) = @_;
	my $attributes       = $address->attributes();
	my $body             = $self->message->body();

	while (@$body and $body->[0] =~ /^(\w+):\s*(.*)$/)
	{
		my ($directive, $value) = (lc( $1 ), $2);
		$address->$directive( $value ) if exists $attributes->{ $directive };
		shift @$body;
	}

	return $self->remove_signature( $body );
}

sub remove_signature
{
	my ($self, $body) = @_;

	my @newbody;

	while (@$body and $body->[0] !~ /^-- $/)
	{
		push @newbody, shift @$body;
	}

	return \@newbody;
}

sub reply
{
	my ($self, $headers, @body) = @_;

	my $mailer = Mail::Mailer->new();
	$mailer->open( $headers );
	$mailer->print( @body );
	$mailer->close();
}

sub find_command
{
	my $self      = shift;
	my ($subject) = $self->message->get('Subject') =~ /^\*(\w+)\*/;

	return unless $subject;

	my $command   = 'command_' . lc $subject;
	return $self->can( $command ) ? $command : '';
}

sub copy_headers
{
	my $self    = shift;
	my $headers = $self->message->head->header_hashref();
	my %copy;
	@copy{ map { ucfirst( $_ ) } keys %$headers } = map {
		my $line = UNIVERSAL::isa( $_, 'ARRAY' ) ? join(', ', @$_) : $_;
		chomp $line;
		$line;
	} values %$headers;

	delete $copy{'From '};
	return \%copy;
}

1;
__END__

=head1 NAME

Mail::Action - base for building modules that act on incoming mail

=head1 SYNOPSIS

	use base 'Mail::Action';

=head1 DESCRIPTION

Sometimes, you just need a really simple mailing address to last for a few
days.  You want it to be easy to create and easy to use, and you want it to be
sufficiently anonymous that your real address isn't ever exposed.

Mail::TempAddress, Mail::TempAddress::Addresses, and Mail::TempAddress::Address
make it easy to create a temporary mailing address system.

=head1 USING ADDRESSES

=head2 INSTALLING

Please see the README file in this distribution for installation and
configuration instructions.  You'll need to configure your mail server and your
DNS, but you only need to do it once.  The rest of these instructions assume
you've installed Mail::TempAddress to handle all mail coming to addresses in
the subdomain C<tempmail.example.com>.

=head2 CREATING AN ADDRESS 

To create a new temporary address, send an e-mail to the address
C<new@tempmail.example.com>.  In the subject of the message, include the phrase
C<*new*>.  You will receive a response informing you that the address has been
created.  The message will include the new address.  In this case, it might be
C<3abfeec@tempmail.example.com>.

Simply provide this address when required to register at a web site (for
example).

You can specify additional directives when creating an address.  Please see
L<Directives> for more information.

=head2 RECEIVING MESSAGES FROM A TEMPORARY ADDRESS

Every message sent to your temporary address will be resent to the address you
used to create the address.  The sender will not see your actual address.

=head2 REPLYING TO MESSAGES RECEIVED AT A TEMPORARY ADDRESS

Every message relayed to your actual address will contain a special C<Reply-To>
header keyed to the sender.  Thus, a message from C<news@example.com> may have
a C<Reply-To> header of C<3abfeec+3f974d46@tempmail.example.com>.  Be sure to
send any replies to this address so that the message may be relayed from your
temporary address.

=head1 DIRECTIVES

Temporary addresses have two attributes.  You can specify these attributes by
including directives when you create a new address.

Directives go in the body of the creation message.  They take the form:

	Directive: option

=head2 Expires

This directive governs how long the address will last.  After its expiration
date has passed, no one may send a message to the address.  Everyone will then
receive an error message indicating that the address does not exist.

This attribute is not set by default; addresses do not expire.  To enable it,
use the directive form:

	Expires: 7d2h

This directive will cause the address to expire in seven days and two hours.
Valid time units are:

=over 4

=item * C<m>, for minute.  This is sixty (60) seconds.

=item * C<h>, for hour.  This is sixty (60) minutes.

=item * C<d>, for day.  This is twenty-four (24) hours.

=item * C<w>, for week. This is seven (7) days.

=item * C<M>, for month.  This is thirty (30) days.

=back

This should suffice for most purposes.

=head2 Description

This is a single line that describes the purpose of the address.  If provided,
it will be sent in the C<X-MTA-Description> header in all messages sent to the
address.  By default, it is blank.  To set a description, use the form:

	Description: This address was generated to enter a contest.

=head1 METHODS

=over 4

=item * new( $address_directory,
	[ Filehandle => $fh, Addresses => $addys, Message => $mess ] )

C<new()> takes one mandatory argument and three optional arguments.
C<$address_directory> is the path to the directory where address data is
stored.  You can usually get by with just the mandatory argument.

C<$fh> is a filehandle (or a reference to a glob) from which to read an
incoming message.  If not provided, M::TA will read from C<STDIN>, as that is
how mail filters work.

C<$addys> should be an Addresses object (which manages the storage of temporary
addresses).  If not provided, M::TA will use L<Mail::TempAddress::Addresses> by
default.

C<$mess> should be a Mail::Internet object (representing an incoming e-mail
message) to the constructor.  If not provided, M::TA will use L<Mail::Internet>
by default.

=item * process()

Processes one incoming message.

=back

=head1 SEE ALSO

L<Mail::SimpleList> and L<Mail::TempAddress> for example uses.

See L<Mail::Action::Storage>, L<Mail::Action::Address>, and
L<Mail::Action::PodToHelp> for related modules.

=head1 AUTHOR

chromatic, C<chromatic@wgz.org>.

=head1 BUGS

No known bugs.

=head1 COPYRIGHT

Copyright (c) 2003, chromatic.  All rights reserved.  This module is
distributed under the same terms as Perl itself, in the hope that it is useful
but certainly under no guarantee.  Hey, it's free.
