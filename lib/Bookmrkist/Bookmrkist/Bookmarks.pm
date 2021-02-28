package Bookmrkist::Bookmrkist::Bookmarks;

use Mojo::Base qw(Mojolicious::Controller);

use Bookmrkist::Db::Bookmark;
use Bookmrkist::Data::Url;

sub list {
  my ($c) = @_;

  my $stash = $c->stash;
  $stash->{pagename} = "List Bookmarks";

  my @url = Bookmrkist::Data::Url->search();

  $stash->{urls} = \@url;

  $c->render( template => 'bookmark/list');
}

sub add_page {
  my ($c) = @_;

  $c->stash->{pagename} = $c->__('page-title--add-link');
  $c->needed_js('bookmarks/api', 'bookmarks/addpage');

  my $formdata = $c->stash->{formdata} ||= {};
  for my $param (qw(url title description tags)) {
    $formdata->{$param} = $c->param($param) || '';
  }

  $c->render( template => 'bookmark/add_page' );
}

sub view {
  my ($c) = @_;

  my $linkhash = $c->stash->{ link_hash };
  my $bookhash = $c->param('bookmark') || '';
  $bookhash = '' if $bookhash =~ m{[^0-9a-z]};

  my $url = Bookmrkist::Data::Url->retrieve( $linkhash, $c->user, $bookhash ); 

  if ( $url ) {
    $c->stash->{url_obj} = $url;

    $c->render( template => 'bookmark/view' );
  } else {
    $c->reply->not_found();
  }

}

1;
