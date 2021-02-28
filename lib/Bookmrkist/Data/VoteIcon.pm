package Bookmrkist::Data::VoteIcon;

use Mojo::Base -base;

has 'type';
has 'state';

my %icons = (
    love    => 'heart',
    like    => 'thumbs-up',
    dislike => 'thumbs-down',
    hate    => 'heartbroke',
  );


sub icon {
  my ($self) = @_;

  my $icon = "";
  if ( $self->type and $self->state and $icons{ $self->type } ) {
    $icon = "fa-$icons{ $self->type }";

    if ($self->state eq 'voted') {
      $icon = "voted fas $icon";

    } elsif ( $self->state eq 'disabled' ) {
      $icon = "vote-disabled far $icon"
    } else {
      $icon = "vote-icon far $icon";
    }
  }

  return $icon;
}

sub color {
  my ($self) = @_;
  return '' unless $self->state and $self->type;

  my $colors = "";
  if ( $self->state eq 'disabled' ) {
    $colors = "text-muted";
  } elsif ( $self->type eq 'love' or $self->type eq 'hate' ) {
    $colors = "text-danger";
  } else {
    $colors = "text-primary";
  }

  return $colors;
}



1;
