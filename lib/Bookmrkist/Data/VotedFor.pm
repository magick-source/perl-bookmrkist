package Bookmrkist::Data::VotedFor;

use Mojo::Base 'Bookmrkist::Data::LazyList';

use Bookmrkist::Db::BookmarkVote;
use Bookmrkist::Data::Vote;

use SorWeTo::User;

__PACKAGE__->db_class('Bookmrkist::Db::BookmarkVote');
__PACKAGE__->record_class('Bookmrkist::Data::Vote');

__PACKAGE__->key_field('bookmark_uuid');

has 'user';
has 'owners' => sub { {} };

sub search {
  my ($class, %params) = @_;

  my $user = delete $params{ user };
  unless ($user) {
    warn "VoterFor without user - using anonymous";

    $user = SorWeTo::User->unknown_user();
  }
  $params{ user_id } = $user->user_id;

  my $owners = delete $params{ owners };

  my $self = $class->SUPER::search( %params );
  $self->user( $user ) if $user;
  $self->owners( $owners || {} );

  return $self;
}

sub data_loaded {
  my ($self, @data) = @_;

  return unless my $user = $self->user;

  for my $rec (@data) {
    $rec->user( $user );
    $rec->owner_id( $self->owners->{ $rec->bookmark_uuid } );
  }

  return;
}

sub voted_for {
  my ($self, $bookmark_uuid) = @_;

  my $rec = $self->get($bookmark_uuid);

  return !!($rec);
}

sub vote {
  my ($self, $bookmark_uuid) = @_;

  my $rec = $self->get( $bookmark_uuid );
  unless ($rec) {
    $rec = Bookmrkist::Data::Vote->new(
              user      => $self->user,
              owner_id  => $self->owners->{$bookmark_uuid},
            );
  }

  return $rec;
}

1;
