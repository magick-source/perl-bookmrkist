package Bookmrkist::Data::Url;

use Mojo::Base 'Bookmrkist::Data::Base';

use Bookmrkist::Db::Url;

use Bookmrkist::Data::Bookmark;
use Bookmrkist::Data::Tag;

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

sub search {
  my ($class, %filters) = @_;
 
  unless ( $filters{ flags } ) {
    $filters{ flags} = { -and => {
                            -like => "%active%" ,
                            -not_like => "%private%"
                            }
                        };
  }

  my @url = Bookmrkist::Db::Url->search_where( \%filters );

  @url = map { $class->new( db_obj => $_ ) } @url;

use Data::Dumper;
print STDERR 'urls: ', Dumper(\@url);

  return @url;
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
  print STDERR "counting bookmarks for '$uuid': $count\n";

  return $count;
}

sub top_tags {
  my ($self) = @_;

  return [ Bookmrkist::Data::Tag->top_tags_for_url( $self->uuid ) ];
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
