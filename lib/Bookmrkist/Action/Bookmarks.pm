package Bookmrkist::Action::Bookmarks;

use Mojo::Base qw(Mojolicious::Controller);

use Mojo::URL;

use Bookmrkist::Db::Bookmark;
use Bookmrkist::Data::Url;
use Bookmrkist::Data::Paging;

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

  $filters{ user } = $c->user();

  __add_sort_links( $c, \%filters );

  my @url         = Bookmrkist::Data::Url->search( %filters );
  my $page_count  = Bookmrkist::Data::Url->page_count( %filters );

  $stash->{urls} = \@url;
  $stash->{paging} = Bookmrkist::Data::Paging->new(
                        cur_page      => ($page || 1),
                        total_pages   => ($page_count || 1),
                        base_url      => $c->req->url,
                      );

  $c->render( template => 'bookmark/list');
}

sub __add_sort_links {
  my ($c, $filters) = @_;

  my $uname   = $filters->{username};
  my $tag     = $filters->{tag};
  my $srecent = ($filters->{order}||'' eq 'recent' ) ? 1 : 0;

  my @sorts;
  $c->stash->{sort_links} = \@sorts;

  if ( $srecent ) {
    my $lnk = '';
    if ($uname and $tag) {
      $lnk = "/user/$uname/$tag";

    } elsif ($uname) {
      $lnk = "/user/$uname";

    } elsif ($tag) { 
      $lnk = "/tag/$tag";

    } else {
      $lnk = "/";
    }

    @sorts = (
      { label => $c->translate("list-links--sort-top"),
        href  => $lnk,
      },{
        label => $c->translate("list-links--sort-recent"),
      }
    );
  } else {
    my $lnk = '';
    if ($uname and $tag) {
      $lnk = "/recent/u/$uname/$tag";

    } elsif ($uname) {
      $lnk = "/recent/u/$uname";

    } elsif ($tag) { 
      $lnk = "/recent/$tag";

    } else {
      $lnk = "/recent";
    }

    @sorts = (
      {
        label => $c->translate("list-links--sort-top"),
      },{
        label => $c->translate("list-links--sort-recent"),
        href  => $lnk,
      }
    );

  }

  return;
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

  if ( $url and $url->highlight ) {
    $c->stash->{url_obj} = $url;
    $c->stash->{pagename}
      = $c->__('page-title--view-bookmark', 
          url_title => ($url->page_title || 'bookmark'),
        ) || $url->page_title || 'View Bookmark';

    $c->render( template => 'bookmark/view' );
  } else {
    $c->reply->not_found();
  }

}

sub goto {
  my ($c) = @_;

  my $linkhash  = $c->stash->{ link_hash };

  my $referer   = $c->req->headers->header('Referer');
  my $is_ok = 0;
  if ($referer) {
    my $hostname  = $c->req->url->to_abs->host;
    my $referhost = Mojo::URL->new( $referer )->host;

    if ($hostname eq $referhost) {
      $is_ok = 1

    } else {
      $c->evlog('goto.jump.invalid_referal', $referer);
    }
  } else {
    $c->evlog('goto.jump.missing_referal', 1);
    $is_ok = 1; #may need to change (or become a config)
  }
 
  my $jump_to = $c->url_for('/');
  if ( $is_ok ) {
    my $url = Bookmrkist::Data::Url->retrieve( $linkhash, $c->user );

    if ( $url ) {
      $jump_to = $url->url;
      $c->evlog('goto.jump.jumping', 1);

    } else {
      $c->evlog('goto.jump.url_missing', 1);
      return $c->reply->not_found;
    }
  }
  
  return $c->redirect_to( $jump_to );
}

1;
