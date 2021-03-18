package Bookmrkist::Bookmrkist::Bookmarks;

use Mojo::Base qw(Mojolicious::Controller);

use Bookmrkist::Db::Bookmark;
use Bookmrkist::Data::Url;

sub list {
  my ($c) = @_;

  my $stash = $c->stash;
  $stash->{pagename} = "List Bookmarks";

  my %filters = ();

  if ( $stash->{tag} ) {
    $filters{ tag } = $stash->{tag };
  }
  if ( $stash->{ username }) {
    $filters{ username } = $stash->{username}; 
  }

  if ($stash->{recent}) {
    $filters{ order } = 'recent'
  }

  my $page = $c->param('page');
  if ($page and $page =~ m{\A\d+\z}) {
    $filters{ page } = $page;
  }

  my $min_score;
  my $user  = $c->user;
  if (!$user or $user->is_anonymous) {
    $min_score = 1;
  } else {
    # TODO: make min score a user preference/param?
    $min_score = 0;

    if ($filters{username} and $user->username eq $filters{username}) {
      $min_score = -999; #we should not have anything lower than this
      $filters{ own_links } = 1;
    }
  }
  $filters{ min_score } = $min_score;

  my @url         = Bookmrkist::Data::Url->search( %filters );
  my $page_count  = Bookmrkist::Data::Url->page_count( %filters );

  $stash->{urls} = \@url;
  $stash->{pages} = $page_count;

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
