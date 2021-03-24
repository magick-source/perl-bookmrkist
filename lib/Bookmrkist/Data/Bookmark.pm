package Bookmrkist::Data::Bookmark;

use Mojo::Base 'Bookmrkist::Data::Base';

use Time::Piece;

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
      user          => $self->viewer,
      bookmark_uuid => $self->uuid,
      owners        => { $self->uuid => $self->user_id },
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
      @bookmarks = ( $chosen, grep {
          $_->uuid ne $highlight
        } @bookmarks );
      $chosen->{highlight} = 1;
    }
  }

  my @buuids = map { $_->uuid } @bookmarks;
  my %owners = map { $_->uuid => $_->user_id } @bookmarks;

  my $votes = Bookmrkist::Data::VotedFor->search(
      user            => $user,
      bookmark_uuid   => \@buuids,
      owners          => \%owners,
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

sub add_bookmark {
  my ($class, $c, $data) = @_;

  my ($url) = Bookmrkist::Db::Url->find_or_create( $data->{url} );
  $data->{score} = $c->prescore_bookmark( $c->user, $url, $data );

  my ($bookmark) = Bookmrkist::Db::Bookmark->find_or_create({
      url_uuid  => $url->uuid,
      title     => $data->{title},
      comment   => $data->{description},
      user_id   => $c->user->user_id,
      score     => $data->{score},
    });

  my @tags = Bookmrkist::Db::Tag->find_or_create_many( $data->{tags} );
  my $res = Bookmrkist::Db::BookmarkTag->update_links( $bookmark, \@tags );

  my @links   = @{ $res->{active} || [] };
  my @deleted = @{ $res->{deleted} || [] };
  my @up_tagids = map { $_->tag_id } @links, @deleted;

  Bookmrkist::Data::Tag->update_indexes( @up_tagids );
  Bookmrkist::Data::Url->update_indexes( $url );

  return ($bookmark, $url);
}

sub link {
  my ($self) = @_;

  my $url = $self->url->link.'?bookmark='.$self->link_hash;

  return $url;
}

sub link_hash {
  my ($self) = @_;

  return uuid2hash( $self->uuid );
}

sub voted {
  my ($self) = @_;

  return $self->_votes->voted_for( $self->uuid );
}

sub vote {
  my ($self) = @_;

  return $self->_votes->vote( $self->uuid );
}

my %vote_multiplier = (
  love    => 2,
  like    => 1,
  dislike => -1,
  hate    => -2,
  spam    => -99,
);

sub cast_vote {
  my ($class, $c, $data) = @_;

  my $vote_type = $data->{vote_type};
  my $book_hash = $data->{bookmark};

  my %res = (
      done => 0,
      errors => [{
        type    => 'input',
        message => 'WIP: not done yet!',
      }]
  );
  my $voter = $c->user();
  if ( $voter->is_anonymous ) {
    $res{errors} = [{
        type    => 'auth',
        message => "Please login to be able to vote!",
      }];
    $res{http_code} = 401;
    return \%res;
  }

  unless ( $vote_multiplier{ $vote_type } ){
    %res = (
      done  => 0,
      http_error  => 400,
      errors => [{
        type    => 'input',
        message => $c->translate('error_invalid_vote_type'),
      }]
    );

    return \%res;
  }

  my $right = "vote_$vote_type";
  unless ( $voter->has_right( $right ) ) {
    $res{errors}[0]{message} = "Vote type is invalid";
    $res{http_error} = 400;
    return \%res;
  }

  my $uuid = hash2uuid( $book_hash );
  return \%res unless $uuid;

  my ($bookmark) = Bookmrkist::Db::Bookmark->retrieve( $uuid );
  unless ($bookmark) {
    $res{errors}[0]{message} = "Bookmark doesn't exist";
    $res{http_error} = 404;
    return \%res;
  }
 
  if ( $voter->user_id == $bookmark->user_id ) {
    $res{errors}[0]{message} = "You can't vote on your own bookmarks";
    $res{http_error} = 404;
    return \%res;
  }

  my ($done, $resdata) = $class->_cast_vote( $voter, $bookmark, $vote_type );
  if ( $done ) {
    delete $res{errors};
    $res{done} = 1;
    $res{data} = $resdata if $resdata;

  } else {
    $res{errors}[0]{message} = "Something went wrong!";
    $res{http_error} = 500;
  }

  return \%res;
}

sub _cast_vote {
  my ($class, $voter, $bookmark, $vote_type) = @_;

  my $vote = $voter->vote_score();
  $vote *= $vote_multiplier{ $vote_type };

  my ($old_vote) = Bookmrkist::Db::BookmarkVote->retrieve(
      bookmark_uuid => $bookmark->uuid,
      user_id       => $voter->user_id,
    );

  my $netscore = 0;
  my %resdata = ();
  if ( $old_vote ) {
    if ( $old_vote->vote_type eq $vote_type ) {
      return (1,{}); #same vote, nothing to do
      # MAYBE(TODO): allow unvoting?
    }

    $netscore -= _vote_weight( $old_vote ) * $old_vote->score;

    $resdata{ remove_vote } = $old_vote->vote_type;

    $old_vote->vote_type( $vote_type );
    $old_vote->score( $vote );
    $old_vote->update();

    $netscore += _vote_weight( $old_vote ) * $vote;
    $resdata{ add_vote } = $vote_type;

  } else {
    my $vote_obj = Bookmrkist::Db::BookmarkVote->create({
        bookmark_uuid => $bookmark->uuid,
        user_id       => $voter->user_id,
        vote_type     => $vote_type,
        score         => $vote,
        flags         => 'active',
      });
    $netscore += $vote;
    $resdata{ add_vote } = $vote_type;
  }

  if ( $netscore ) {
    my $score = $bookmark->score() + $netscore;
    $bookmark->score( $score );
    $bookmark->update();

    my @tags = map { $_->db_obj } @{ _load_tags( $bookmark ) };
    Bookmrkist::Db::BookmarkTag->update_links( $bookmark, \@tags );
    Bookmrkist::Db::TagCount->update_for_tag( $_->id )
      for @tags;

    Bookmrkist::Db::UrlTag->update_for_url( $bookmark->url_uuid );
    Bookmrkist::Db::Url->update_base_score( $bookmark->url_uuid );
  }

  return (1, \%resdata );
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

#MAYBE(TODO): find a better place for this, and make it plauggable?
sub _vote_weigth {
  my ($vote) = @_;

  #TODO: cron to reapply changing weights daily
  return 1;
  
  my $voted_at = Time::Piece->strptime( $vote->voted_at, "%Y-%m-%d %H:%M:%S");
  my $now = localtime;

  my $age = $now - $voted_at;
  my $days = $age->days;

  my $weight = .2;
  if ( $days < 3 ) {
    $weight = 1;

  } elsif ( $days < 30 ) {
    $weight = sprintf "%.2f", 1 / log( $days );

  }

  return $weight;
}

__PACKAGE__->make_column_accessors( );

1;
