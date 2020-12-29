package Bookmrkist::Scoring;

use Mojo::Base -base;


sub register {
  my ($class, $app) = @_;

  $app->helper( prescore_bookmark => \&_prescore_bookmark );

  return;
}

sub _prescore_bookmark {
  my ($c, $user, $url, $data) = @_;

  my $score = ($url->base_score || 0) + ( $user->vote_score || 0);

  $score /= 2;

  return $score;
}


1;
