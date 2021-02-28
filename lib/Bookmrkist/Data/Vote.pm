package Bookmrkist::Data::Vote;

use Mojo::Base q(Bookmrkist::Data::Base);

use Bookmrkist::Data::VoteIcon;

__PACKAGE__->db_class('Bookmrkist::Db::BookmarkVote');

has 'user';
has icons => \&_find_icons;

my %icons = (
    love    => 'grin_hearts',
    like    => 'heart',
    dislike => 'heartbroke',
    hate    => 'angry',
  );

my @icon_order = qw(
  love like dislike hate
);

sub _find_icons {
  my ($self) = @_;

  my %icons;
  if (my $vote = $self->db_obj) {
    $icons{ $vote->type} = Bookmrkist::Data::VoteIcon->new( 
                              type  => $vote->type,
                              state => 'voted'
                            );
  }

  my $user = $self->user;

  for my $itype (@icon_order) {
    next if $icons{ $itype };
    next unless $user and $user->has_right("vote_$itype");

    $icons{ $itype } = Bookmrkist::Data::VoteIcon->new(
        type  => $itype,
        state => 'can_vote', 
      );
  }

  use Data::Dumper;
  print STDERR "icons: ", Dumper( $self );

  my @icons = map { $icons{ $_ } ? $icons{ $_ } : () } @icon_order;

  return \@icons;
}

1;
