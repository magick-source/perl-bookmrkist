package Bookmrkist::Data::Url;

use Mojo::Base 'Bookmrkist::Data::Base';

use Bookmrkist::Db::Url;
use Bookmrkist::Db::UrlTag;

use Bookmrkist::Data::Bookmark;
use Bookmrkist::Data::Tag;

use SorWeTo::Db::User;

use SorWeTo::Utils::Digests qw(
    hash2uuid
    uuid2hash
  );

__PACKAGE__->db_class('Bookmrkist::Db::Url');

has 'user';
has 'highlight_uuid';

has 'highlight' => \&_load_highlight;

#TODO: fetch the highlighted bookmarks

has bookmarks => \&_load_bookmarks;

sub retrieve {
  my ($class, $link_hash, $user, $book_hash) = @_;

  my $uuid  = ($link_hash =~ m{\-} )? $link_hash : hash2uuid( $link_hash );

  my ($url) = Bookmrkist::Db::Url->retrieve( $uuid );
  return unless $url;

  my %flagged = map { $_ => 1 } $url->flagged('adult');

  return unless $url->flagged('active');

  if ( keys %flagged ) {
    return unless $user and !$user->is_anonymous;

    if ( $flagged{ 'adult' } ) {
      return unless $user->user_can('adult');
    }
  }

  my $self = $class->new(
      db_obj        => $url,
      user          => $user,
      ($book_hash ? (highlight_uuid => hash2uuid( $book_hash )):()),
    );

  return $self;
}

my %orders = (
    score     => 'base_score desc',
    recent    => 'first_added desc',

    b_score   => 'score desc, added asc',
    b_recent  => 'added desc, score desc',

    bt_score  => 'bookmark_score desc, bookmark_time asc',
    bt_recent => 'bookmark_time desc, bookmark_score desc',

    t_score   => 'max_score desc, first_bookmark_time asc',
    t_recent  => 'first_bookmark_time desc, max_score desc',
  );
sub search {
  my ($class, %filters) = @_;

  my ($user) = delete $filters{ user };

  my ($filters,$extra) = $class->_common_search_setup( %filters );
  return unless $filters and $extra;

  my $tag_id   = $filters->{ tag_id };
  my $user_id  = $filters->{ user_id };

  my @urls;
  if ( $user_id ) {
    @urls = $class->_search_by_user( $filters, $extra );

  } elsif ( $tag_id ) {

    @urls = $class->_search_by_tag( $filters, $extra );

  } else {

    $filters->{base_score} = delete $filters->{score} if $filters->{score};
    my $order = delete $extra->{order} || 'score';
    unless ( $extra->{order_by} ) {
      $extra->{order_by} = $orders{ $order };
    }

    @urls = Bookmrkist::Db::Url->search_where( $filters, $extra );

  }

  for my $url ( @urls ) {
    # if $url is blessed, it is a db_obj
    $url = { db_obj => $url } unless ref $url eq 'HASH';

    $url->{user} //= $user if $user;
    if ( $url->{highlight} ) {
      use Data::Dumper;
      print STDERR "building hightlight: ", Dumper($user);
      $url->{highlight} = Bookmrkist::Data::Bookmark->new(
          db_obj  => $url->{highlight},
          ($user  ?  (viewer => $user) : ()),
          url     => $url,
        );
    }
  }

  @urls = map { $class->new( %$_ ) } @urls;

  return @urls;
}

sub page_count {
  my ($class, %filters) = @_;

  my ($user) = delete $filters{ user };

  my ($filters,$extra) = $class->_common_search_setup( %filters );
  return 0 unless $filters and $extra;

  my $pagesize = $extra->{limit};

  my $tag_id   = $filters->{ tag_id };
  my $user_id  = $filters->{ user_id };

  my $count;
  if ( $user_id ) {
    $count = $class->_page_count_user( $filters );

  } elsif ( $tag_id ) {
    $count = $class->_page_count_tag( $filters );

  } else {
    $filters->{base_score} = delete $filters->{score} if $filters->{score};
    $count = Bookmrkist::Db::Url->search_where_count( $filters );
  }

  $count = $count / $pagesize;
  $count =int( $count) + 1 unless  $count == int( $count );

  return $count;
}

sub _common_search_setup {
  my ($class, %filters) = @_;

  my $count     = delete $filters{page_size} || 13;
  $count = 15 if $count < 1 or $count > 50;

  my $page      = delete $filters{page} || 1;
  my $offset    = ($page - 1) * $count;

  my $order     = delete $filters{ order };

  my %extra = (
      limit_dialect => 'LimitOffset',
      limit         => $count,
      offset        => $offset,
    );

  if ( $order ) {
    $extra{order} = $order;
    $extra{order_by} = $orders{ $order } if $orders{ $order };
  }

  if ( exists $filters{min_score} ) {
    $filters{ score } = { '>' => delete $filters{min_score} };
  }

  my $username  = delete $filters{ username };
  my $tag       = delete $filters{ tag };

  if ($username) {
    my ($user) = SorWeTo::Db::User->search_where( username => $username );
    return unless $user;

    $filters{'user_id'} = $user->user_id;
  }
  
  if ( $tag ) {
    my ($otag) = Bookmrkist::Db::Tag->search_where(url  => $tag);
    return unless $otag;

    $filters{ 'tag_id' } = $otag->id;
  }

  unless ( $filters{ flags } ) {
    $filters{ -and } ||= [];

    push @{ $filters{ -and } },
      $class->_find_search_flags( \%filters );
  }
  return ( \%filters, \%extra );
}

sub _find_search_flags {
  my ($class, $filters) = @_;

  my %visible = ( active => 1 );
  my %hidden  = ( private => 1, adult => 1);

  my $own_links = delete $filters->{ own_links };
  my $adult     = delete $filters->{ see_adult };

  delete $hidden{adult} if $adult;
  delete $hidden{ private } if $own_links and $filters->{ user_id };

  my @flag_filters = ();

  for my $flag (keys %visible) {
    push @flag_filters, \["FIND_IN_SET(?, flags)", $flag];
  }
  for my $flag (keys %hidden) {
    push @flag_filters, \["NOT FIND_IN_SET(?, flags)", $flag];
  }

  return @flag_filters;
}

sub _refilter_for_user {
  my ($class, $filters) = @_;

  my %filters = %$filters;
  $filters{ bookmark_score } = delete $filters{ score } if $filters{ score };
  if ($filters{ -and } ) {
    my @filters;
    for my $filter ( @{ $filters{-and} } ) {
      if (ref $filter
          and ref $filter eq 'REF'
          and ref $$filter eq 'ARRAY') {

        my ($cond, @binds) = @{$$filter};
        $cond =~ s{flags}{bookmark_flags};
        push @filters, \[ $cond, @binds ];

      } else {
        push @filters, $filter;
      }
    }
    $filters{-and} = \@filters;
  }

  return \%filters;
}

sub _search_by_user {
  my ($class, $filters, $extra) = @_;

  my $order = delete $extra->{order} || 'recent';

  if ( $filters->{tag_id} ) {

    my $flts = $class->_refilter_for_user( $filters );

    $extra->{ order_by } = $orders{ "bt_$order" } || $orders{ "bt_recent " };

    my @bkuuids = Bookmrkist::Db::BookmarkTag->search_where($flts, $extra);
    return unless @bkuuids;

    delete $filters->{tag_id};
    @bkuuids = map { $_->bookmark_uuid } @bkuuids;
    $filters->{uuid} = { -in => \@bkuuids };
  }

  $extra->{ order_by } = $orders{ "b_$order" } || $orders{ "b_recent " };
  my @bookmarks = Bookmrkist::Db::Bookmark->search_where( $filters, $extra );
  return unless @bookmarks;

  my %book_by_url = map { $_->url_uuid => $_ } @bookmarks;
  my @url_ids     = map { $_->url_uuid } @bookmarks;

  my @urls = Bookmrkist::Db::Url->search_where( uuid => [keys %book_by_url] );

  my %urls = map { $_->uuid => $_ } @urls;
  @urls = ();
  for my $uuid (@url_ids) {
    next unless $urls{ $uuid };
    
    push @urls, {
        db_obj => $urls{ $uuid },
        highlight => Bookmrkist::Data::Bookmark->new(
                        db_obj => $book_by_url{ $uuid },
                      )
      };
  }

  return @urls;
}

sub _page_count_user {
  my ($class, $filters) = @_;

  my $count = 0;

  if ( $filters->{tag_id} ) {
    $filters = $class->_refilter_for_user( $filters );
    $count = Bookmrkist::Db::BookmarkTag->search_where_count( $filters );
  } else {
    $count = Bookmrkist::Db::Bookmark->search_where_count( $filters );
  }

  return $count;
}

sub _search_by_tag {
  my ($class, $filters, $extra) = @_;

  my $order = delete $extra->{order} || 'score';
  $order = "t_$order";
  $extra->{order_by} = $orders{ $order } || $orders{ "t_recent" };

  my %filters = (
      tag_id  => $filters->{tag_id},
      ($filters->{score} ? ( max_score => $filters->{score} ) : () ),
    );

  my @url_ids = Bookmrkist::Db::UrlTag->search_where(\%filters, $extra );
  return unless @url_ids;

  @url_ids = map { $_->url_uuid } @url_ids;
  my @urls = Bookmrkist::Db::Url->search_where(uuid => \@url_ids);

  my %urls = map { $_->uuid => $_ } @urls;
  @urls = map { $urls{ $_ } || () } @url_ids;

  return @urls;
}

sub update_indexes {
  my ($class, $url) = @_;

  Bookmrkist::Db::UrlTag->update_for_url( $url->uuid );
  my ($score,$added) = Bookmrkist::Db::Bookmark->stats_for_url( $url->uuid );

  $url->base_score( $score );
  $url->first_added( $added );
  $url->update();

  return;
}

sub link {
  my ($self) = @_;

  return "/url/".uuid2hash( $self->uuid );
}

sub go_link {
  my ($self) = @_;

  return "/goto/".uuid2hash( $self->uuid );
}

sub count_bookmarks {
  my ($self) = @_;

  my $count = Bookmrkist::Db::Bookmark->count_for_url( $self->uuid );
  
  my $uuid = $self->uuid;

  return $count;
}

sub top_tags {
  my ($self) = @_;

  my $sth = Bookmrkist::Db::BookmarkTag->top_tags(
                    url_uuid => $self->uuid
                  );

  my %tagcounts = ();
  $sth->bind_columns( \my ($id, $count) );
  while ( $sth->fetch() ) {
    $tagcounts{ $id } = $count;
  }

  my @tags = Bookmrkist::Data::Tag->search(
      id  => [ keys %tagcounts ],
    );

  for my $tag ( @tags ) {
    $tag->count( $tagcounts{ $tag->id } );
  }

  @tags = sort { ($b->count <=> $a->count) || ($b->url cmp $a->url) } @tags;

  return \@tags;
}

sub _load_bookmarks {
  my ($self) = @_;

  return [Bookmrkist::Data::Bookmark->search(
      user       => $self->user,
      highlight  => $self->highlight_uuid,
      url_uuid   => $self->uuid,
    )];
}

sub _load_highlight {
  my ($self) = @_;

  if ( $self->highlight_uuid) {
    my %filters = (
        uuid  => $self->highlight_uuid,
        user  => $self->user,
      );

    my ($book) = Bookmrkist::Data::Bookmark->search( %filters );

    return $book if $book;
  }

  my $bookmarks = $self->bookmarks;
  my ($book) = $bookmarks->[0];

  return $book;
}

__PACKAGE__->make_column_accessors('Bookmrkist::Db::Url');

1;
