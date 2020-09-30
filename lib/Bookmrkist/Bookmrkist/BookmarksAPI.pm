package Bookmrkist::Bookmrkist::BookmarksAPI;

use Mojo::Base qw(Mojolicious::Controller);



sub add_link {
  my ($c) = @_;

  my $linkdata = __check_addlink_formdata( $c );

  return __finish_with_error( $c )
    unless $linkdata;

  print STDERR "Got to Bookmrkist::Bookmrkist::BookmarksAPI::adlink";


  return $c->render(json => { done => 0 });
}

sub __check_addlink_formdata {
  my ($c) = @_;

  my %data = ();
  my $errors = 0;

  return $errors ? undef : \%data;
}

sub __finish_with_error { 
  my ($c) = @_;

  return unless $c->res->code() == 200;

  $c->res->code(400);
  $c->render(json => { errors => $c->flash('errors') });
}

1;
