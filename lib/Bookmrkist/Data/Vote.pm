package Bookmrkist::Data::Vote;

use Mojo::Base q(Bookmrkist::Data::Base);

use Bookmrkist::Db::BookmarkVote;

use Bookmrkist::Data::VoteIcon;

__PACKAGE__->db_class('Bookmrkist::Db::BookmarkVote');

has 'user';
has 'owner_id';
has icons => \&_find_icons;

my @icon_order = qw(
  love like dislike hate spam
);

sub _find_icons {
  my ($self) = @_;

  return $self->_anonymous_icons
    unless $self->user and $self->user->user_id;

  return [] unless $self->owner_id;
  
  my $state = '';
  $state = 'disabled' if $self->user->user_id == $self->owner_id;

  my %icons;
  my $voted = 0;
  if (my $vote = $self->db_obj) {
    $icons{ $vote->vote_type } = Bookmrkist::Data::VoteIcon->new( 
                              type  => $vote->vote_type,
                              state => 'voted'
                            );
    $voted = 1;
  }

  my $user = $self->user;

  for my $itype (@icon_order) {
    next if $icons{ $itype };
    next unless $user and $user->has_right("vote_$itype");

    $icons{ $itype } = Bookmrkist::Data::VoteIcon->new(
        type  => $itype,
        state => $state || ($voted ? 'voted-other' : 'can_vote'), 
      );
  }

  my @icons = map { $icons{ $_ } ? $icons{ $_ } : () } @icon_order;

  return \@icons;
}

sub _anonymous_icons {
  my ($self) = @_;

  return [
      Bookmrkist::Data::VoteIcon->new(
          type  => 'like',
          state => 'login-to-vote',
        ),
    ];
}

__PACKAGE__->make_column_accessors( );

1;
