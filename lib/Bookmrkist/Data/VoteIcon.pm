package Bookmrkist::Data::VoteIcon;

use Mojo::Base -base;

has 'type';
has 'state';

my %icons = (
    love    => 'heart',
    like    => 'thumbs-up',
    dislike => 'thumbs-down',
    hate    => 'frown',
    spam    => 'times-circle',
  );


sub icon {
  my ($self) = @_;

  my $icon = "";
  if ( $self->type and $self->state and $icons{ $self->type } ) {
    $icon = "fa-$icons{ $self->type }";

    if ($self->state eq 'voted') {
      $icon = "fas $icon";

    } elsif ( $self->state eq 'disabled' ) {
      $icon = "far $icon"
    } else {
      $icon = "far $icon";
    }
  }

  return $icon;
}

sub vote_class {
  my ($self) = @_;
  
  return '' unless $self->state and $self->type;

  my $class ='';
  if ( $self->state eq 'voted' ) {
    $class = 'bookmark_voted';

  } elsif ( $self->state eq 'disabled' ) {
    $class = 'bookmark_vote_disable';

  } elsif ( $self->state eq 'can_vote' or $self->state eq 'voted-other' ) {
    $class = 'bookmark_to_vote';

  } elsif ( $self->state eq 'login-to-vote' ) {
    $class = 'login_to_vote';

  }
  my $type = $self->type;
  $class .= " vote-type-$type";

  return $class;
}

sub color {
  my ($self) = @_;
  return '' unless $self->state and $self->type;

  my $colors = "";
  if ( $self->state eq 'disabled' or $self->state eq 'voted-other') {
    $colors = "text-muted";
  } elsif ( $self->state eq 'login-to-vote' ) {
    $colors = "text-azure";
  } elsif ( $self->type eq 'love' ) {
    $colors = "text-danger";
  } else {
    $colors = "text-primary";
  }

  return $colors;
}



1;
