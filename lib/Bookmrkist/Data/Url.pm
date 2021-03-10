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
has 'highlight';

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
      db_obj    => $url,
      user      => $user,
      highlight => $book_hash,
    );

  return $self;
}

my %orders = (
    score     => 'base_score desc',
    recent    => 'first_added desc',

    b_score   => 'score desc, added asc',
    b_recent  => 'added desc, score desc',

    t_score   => 'max_score desc, first_bookmark_time asc',
    t_recent  => 'first_bookmark_time desc, max_score desc',
  );
sub search {
  my ($class, %filters) = @_;

  my $tag       = delete $filters{ tag };
  my $username  = delete $filters{ username };

  my $count     = delete $filters{page_size} || 13;
  $count = 15 if $count < 1 or $count > 50;

  my $page      = delete $filters{page} || 1;
  my $offset    = ($page - 1) * $count;

  my $order     = delete $filters{ order } || 'score';
  print STDERR "order by '$order'\n\n";
  $order = 'score' unless $orders{ $order };

  if ($username) {
    my ($user) = SorWeTo::Db::User->search_where( username => $username );
    return unless $user;

    $filters{'b.user_id'} = $user->user_id;

    $order  = "b_$order";
  }
  
  if ( $tag ) {
    my ($otag) = Bookmrkist::Db::Tag->search_where(url  => $tag);
    return unless $otag;

    $filters{ 'bt.tag_id' } = $otag->id;

    $order  = "t_$order" unless $username;
  }
 
  my %extra = (
      limit_dialect => 'LimitOffset',
      limit         => $count,
      offset        => $offset,
      order_by      => $orders{ $order },
    );


  my @urls;
  if ( $username ) {
    my @url_ids = Bookmrkist::Db::Bookmark->search_where({
        user_id => delete $filters{'b.user_id'},
        %filters,
      }, \%extra);
    @url_ids = map { $_->url_uuid } @url_ids;

    @urls = Bookmrkist::Db::Url->search_where( uuid => \@url_ids ) ;

    my %urls = map { $_->uuid => $_ } @urls;
    @urls = map { $urls{ $_ } || () } @url_ids;

  } elsif ( $tag ) {
    my @url_ids = Bookmrkist::Db::UrlTag->search_where({
          tag_id => $filters{'bt.tag_id'}
        }, \%extra );
    return unless @url_ids;

    @url_ids = map { $_->url_uuid } @url_ids;
    @urls = Bookmrkist::Db::Url->search_where(uuid => \@url_ids);

    my %urls = map { $_->uuid => $_ } @urls;
    @urls = map { $urls{ $_ } || () } @url_ids;

  } else {
    unless ( $filters{ flags } ) {
      $filters{ flags} = { -and => {
                            -like => "%active%" ,
                            -not_like => "%private%"
                            }
                        };
    }

    use Data::Dumper;
    print STDERR 'search urls: ', Dumper( \%filters, \%extra );
    @urls = Bookmrkist::Db::Url->search_where( \%filters, \%extra );

  }

  @urls = map { $class->new( db_obj => $_ ) } @urls;

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
      highlight  => $self->highlight,
      url_uuid   => $self->uuid,
    )];
}

__PACKAGE__->make_column_accessors('Bookmrkist::Db::Url');

1;
