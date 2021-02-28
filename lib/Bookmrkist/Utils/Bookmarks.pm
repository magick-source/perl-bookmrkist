package Bookmrkist::Utils::Bookmarks;

use Mojo::Base -strict;
use parent 'Exporter';

use Bookmrkist::Db::Url;
use Bookmrkist::Db::Bookmark;

use SorWeTo::Utils::Digests qw(
    hash2uuid
  );

our @EXPORT_OK = qw(
    url_from_linkhash
  );


sub url_from_linkhash {
  my ($link_hash, $user, $book_hash) = @_;

  my $uuid  = hash2uuid( $link_hash );
  my $buuid = hash2uuid( $book_hash ) if $book_hash;

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

  return _load_bookmarks($url, $user, $buuid);
}

sub _load_bookmarks {
  my ($url, $user, $buuid) = @_;

  my @bookmarks = Bookmrkist::Db::Bookmark->search( url_uuid => $url->uuid );

  @bookmarks = grep {
      _filter_bookmark( $_, $user )
    } @bookmarks;

  return unless @bookmarks;

  @bookmarks = sort { $b->{score} <=> $a->{score} } @bookmarks;

  if ( $buuid ) {
    my ($choosen) = grep {
        $_->uuid eq $buuid
      } @bookmarks;

    if ($choosen) {
      @bookmarks = $choosen,  grep {
          $_->uuid ne $buuid
        } @bookmarks;
      $choosen->{highlight} = 1;
    }
  }
  $url->{bookmarks} = \@bookmarks;

  use Data::Dumper;
  print STDERR 'url: ', Dumper( $url );

  return $url;
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

1;
