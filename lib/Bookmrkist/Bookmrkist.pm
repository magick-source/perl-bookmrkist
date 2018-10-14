package Bookmrkist::Bookmrkist;

use Mojo::Base qw(Mojolicious::Plugin);

sub register {
  my ($self, $app, $conf) = @_;

  

  print STDERR "Registering bookmrkist\n";

  return $self;
}

sub post_register {
  my ($self, $app) = @_;	

  print STDERR "Called post_register\n";

  $app->register_themes('bookmrkist');
}

1;
