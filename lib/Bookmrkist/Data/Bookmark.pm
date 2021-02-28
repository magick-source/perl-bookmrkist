package Bookmrkist::Data::Bookmark;

use Mojo::Base 'Bookmrkist::Data::Base';

use Bookmrkist::Db::Bookmark;
use Bookmrkist::Db::BookmarkTag;

use Bookmrkist::Data::Url;
use Bookmrkist::Data::User;
use Bookmrkist::Data::Tag;
use Bookmrkist::Data::VotedFor;

use SorWeTo::Utils::Digests qw(
    hash2uuid
    uuid2hash
  );

__PACKAGE__->db_class('Bookmrkist::Db::Bookmark');

has 'viewer';
has 'highlight' => sub { 0 };

has tags  => \&_load_tags;

has url => sub { 
  my ($self) = @_;

  return Bookmrkist::Data::Url->retrieve( $self->url_uuid );
};

has user => sub {
  my ($self) = @_;

  return Bookmrkist::Data::User->from_user_id( $self->user_id );
};

has _votes => sub {
  my ($self) = @_;

  return Bookmrkist::Data::VotedFor->search(
      user_id => $self->viewer->id,

    );
};

my %orders = (
    score   => ['score', 'desc'],
    recent  => ['date_added', 'desc'],
    oldest  => ['date_added', 'asc'],
  );

sub search {
  my ($class, %filters) = @_;

  my $user      = delete $filters{ user };
  my $highlight = delete $filters{ highlight};
  if ($highlight and $highlight !~ m{\-}) {
    $highlight = hash2uuid( $highlight );
  }

  my $order     = delete $filters{ order } || 'score';

  my @bookmarks = Bookmrkist::Db::Bookmark->search_where( %filters );

# TODO: filter links with less than xx score

  @bookmarks = grep {
      _filter_bookmark( $_, $user )
    } @bookmarks;

  return unless @bookmarks;

  my ($ordfld, $orddir) = @{ $orders{ $order } || ['score','desc'] };
  if ( $orddir eq 'asc' ) {
    @bookmarks = sort { $a->$ordfld() <=> $b->$ordfld() } @bookmarks;
  } else {
    @bookmarks = sort { $b->$ordfld() <=> $a->$ordfld() } @bookmarks;
  }
  
  if ( $highlight ) {
    my ($chosen) = grep {
        $_->uuid eq $highlight
      } @bookmarks;

    if ($chosen) {
      @bookmarks = $chosen, grep {
          $_->uuid ne $highlight
        } @bookmarks;
      $chosen->{highlight} = 1;
    }
  }

  my @buuids = map { $_->uuid } @bookmarks;

  my $votes = Bookmrkist::Data::VotedFor->search(
      user            => $user,
      bookmark_uuid   => \@buuids
    );

  @bookmarks = map {
      $class->new(
          db_obj    => $_,
          viewer    => $user,
          highlight => $_->{highlight},
          _votes    => $votes,
        );
    } @bookmarks;

  return @bookmarks;
}

sub link {
  my ($self) = @_;

  my $url = $self->url->link.'?bookmark='.uuid2hash( $self->uuid );

  return $url;
}

sub voted {
  my ($self) = @_;

  return $self->_votes->voted_for( $self->uuid );
}

sub vote {
  my ($self) = @_;

  return $self->_votes->vote( $self->uuid );
}

sub _load_tags {
  my ($self) = @_;

  my @btags = Bookmrkist::Db::BookmarkTag->search(
        bookmark_uuid => $self->uuid
      );

  return [] unless @btags;

  my @ids = map { $_->tag_id } @btags;
  my @tags = Bookmrkist::Data::Tag->search( id => \@ids );

  return \@tags;
}

sub _filter_bookmark {
  my ( $bookmark, $user ) = @_;

  my %flags = $bookmark->flagged('adult','private');
  return 1 unless keys %flags;

  if ($flags{ 'adult' } ) {
    return unless $user->user_can('adult');
  }

  if ($flags{ 'private' }) {
    return unless $bookmark->user_id == $user->user_id;
  }

  return $bookmark;
}

__PACKAGE__->make_column_accessors( );

1;
