package Bookmrkist::Validator;

use Mojo::Base 'Mojolicious::Validator';

sub new {
  my $self = shift->SUPER::new( @_ );

  $self->add_check( url   => \&_c_url );
  $self->add_check( tags  => \&_c_tags );

  return $self;
}

sub _c_url {
  my ($v, $name, $value) = @_;

  # TODO(maybe): limit, if worth it
  return if $value =~ m{\Ahttps?://\w+};
  return 'invalid-schema';
}

sub _c_tags {
  my ($v, $name, $value) = @_;

  my @tags = split /\s*,\s*/, $value;
  for my $tag (@tags) {
    return ['invalid-tag', $tag] if $tag !~ m{\A[\w\s\-\_]{2,}\z};
  }

  return 0;
}

1;
