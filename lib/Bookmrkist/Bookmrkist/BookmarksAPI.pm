package Bookmrkist::Bookmrkist::BookmarksAPI;

use Mojo::Base qw(Mojolicious::Controller);

sub add_link {
  my ($c) = @_;

  print STDERR "Got to Bookmrkist::Bookmrkist::BookmarksAPI::adlink";


  return $c->render(json => { done => 0 });
}

1;
