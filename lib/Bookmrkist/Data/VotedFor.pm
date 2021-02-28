package Bookmrkist::Data::VotedFor;

use Mojo::Base 'Bookmrkist::Data::LazyList';

use Bookmrkist::Db::BookmarkVote;
use Bookmrkist::Data::Vote;

__PACKAGE__->db_class('Bookmrkist::Db::BookmarkVote');
__PACKAGE__->record_class('Bookmrkist::Data::Vote');

__PACKAGE__->key_field('bookmark_uuid');

has 'user';

sub search {
  my ($class, %params) = @_;

  my $user = delete $params{ user };
  if ($user) {
    $params{ user_id } ||= $user->user_id;
  }

  my $self = $class->SUPER::search( %params );
  $self->user( $user ) if $user;

  return $self;
}

sub data_loaded {
  my ($self, @data) = @_;

  return unless my $user = $self->user;

  for my $rec (@data) {
    $rec->user( $user );
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
    $rec = Bookmrkist::Data::Vote->new( user => $self->user );
  }

  return $rec;
}

1;
