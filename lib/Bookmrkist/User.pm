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

  if ( $user->is_anonymous ) {
    return 0;
  }

  my $score = $user->settings->get('user_score') || 0;

  return $score;
}

sub vote_score {
  my ($user) = @_;

  my $vote = 1;
  $vote = 0 if $user->score <= 0;

  return $vote;
}

#TODO(maybe): Make the scores for each right configurabl
my %role_scores  = (
  badboy    =>   -100,
  newbie    =>      0,
  linker    =>    100,
  moderator =>  1_000,
  manager   => 10_000,
);
my %rights  = (
  add_links       => 'badboy',
  report_adult    => 'linker',
  select_min_list => 'linker',
  report_spam     => 'moderator',
  flag_spam       => 'manager',
  flag_adult      => 'manager',
  flag_adult_user => 'manager',

  vote_like       => 'newbie',
  vote_dislike    => 'linker',
  vote_love       => 'linker',
  vote_hate       => 'moderator',
  vote_spam       => 'manager',
);

my %anonymous_rights = map { $_ => 1 } qw(
    vote_like
  );

sub _user_has_right {
  my ($next, $user, $right) = @_;

  if ( $user->is_anonymous ) {
    return $anonymous_rights{ $right } || 0;
  }

  my $user_score = user_score( $user );
  return 1 if $right eq 'spammer' and $user_score < 0;

  my $role = $right;
  if ( $rights{ $right } ) {
    $role = $rights{ $right };
  }

  if ( defined $role_scores{ $role } ) {
    return 1 if  $user_score >= $role_scores{ $role };

    return 0;
  }

  return $next->( $user, $user ) if $next;

  return;
}

1;
