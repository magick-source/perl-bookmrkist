package Bookmrkist::User;

use Mojo::Base -base;


sub register {
  my ($class, $app) = @_;

  $app->hook( user_has_right => \&_user_has_right );

  return;
}


sub post_register {
  my ($class, $app) = @_;

  $app->add_user_helper( score => \&user_score );
  $app->add_user_helper( vote_score => \&vote_score );
}

sub user_score {
  my ($user) = @_;

  return $user->anonymous ? 0 : 1;

}

sub vote_score {
  use Data::Dumper;
  print STDERR 'vote_score: ', Dumper(\@_);

}

#TODO(maybe): Make the scores for each right configurabl
my %role_scores  = (
  newbie    =>      0,
  linker    =>    100,
  moderator =>  1_000,
  manager   => 10_000,
);
my %rights  = (
  vote_for        => 'newbie',
  report_adult    => 'linker',
  vote_against    => 'linker',
  select_min_list => 'linker',
  boost_url       => 'moderator',
  report_spam     => 'moderator',
  flag_spam       => 'manager',
  flag_adult      => 'manager',
  flag_adult_user => 'manager',
);

sub _user_has_right {
  my ($next, $c, $user, $right) = @_;

  my $user_score = user_score( $user );
  return 1 if $right eq 'spammer' and $user_score < 0;

  my $role = $right;
  if ( $rights{ $right } ) {
    $role = $rights{ $right };
  }

  if ( defined $role_scores{ $role } ) {
    return 1 if  $user_score > $role_scores{ $role };

    return 0;
  }

  return $next->( $c, $user, $user ) if $next;

  return;
}

1;
