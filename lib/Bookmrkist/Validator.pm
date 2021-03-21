package Bookmrkist::Validator;

use Mojo::Base 'Mojolicious::Validator';

sub new {
  my $self = shift->SUPER::new( @_ );

  $self->add_check( url   => \&_c_url );
  $self->add_check( tags  => \&_c_tags );
  $self->add_check( vote_type  => \&_c_vote_type );
  $self->add_check( link_hash  => \&_c_link_hash );

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

sub _c_vote_type {
  my ($v, $name, $value) = @_;

  return ['invalid-vote'] unless $value =~ m{\A\w+\z};

  return 0;
}

sub _c_link_hash {
  my ($v, $name, $value) = @_;

  return ['invalid-bookmark'] unless $value =~ m{\A[0-9a-h]{30}\z};

  return 0;
}

1;
