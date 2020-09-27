package Bookmrkist::Bookmrkist::Bookmarks;

use Mojo::Base qw(Mojolicious::Controller);

use Bookmrkist::Db::Bookmark;

sub list {
  my ($c) = @_;

  my $stash = $c->stash;
  $stash->{pagename} = "List Bookmarks";

  Bookmrkist::Db::Bookmark->retrieve(1);

  $c->render( template => 'bookmark/list');
}

sub add_page {
  my ($c) = @_;

  $c->stash->{pagename} = $c->__('page-title--add-link');
  $c->stash->{needed_js}->{addpage} = undef;

  my $formdata = $c->stash->{formdata} ||= {};
  for my $param (qw(url title description tags)) {
    $formdata->{$param} = $c->param($param) || '';
  }

  $c->render( template => 'bookmark/add_page' );
}

1;
