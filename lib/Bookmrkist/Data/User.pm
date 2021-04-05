package Bookmrkist::Data::User;

use Mojo::Base 'Bookmrkist::Data::Base';

use SorWeTo::Db::User;

has icon        => \&_find_icon;
has icon_color  => \&_find_icon_color;

has _weird_id => \&_find_weird_id;

my %user_cache = ();

sub from_user_id {
  my ($class, $user_id) = @_;

  $user_cache{ $user_id } //= do {
    my ($user) = SorWeTo::Db::User->search_where( id => $user_id );
    unless ($user) {
      $user = SorWeTo::User->anonymous;
    }

    $class->new( db_obj => $user );
  };

  return $user_cache{ $user_id };
}

sub username {
  my ($self) = @_;

  return $self->db_obj->username || 'anonymous';
}

sub display_name {
  my ($self) = @_;

  return $self->db_obj->display_name || 'Unknow user';
}

sub is_anonymous {
  my ($self) = @_;

  return $self->db_obj->is_anonymous;
}

sub avatar {
  my ($self) = @_;

  #TODO: implement support for user avatars (maybe in sorweto)

  return;
}

sub link {
  my ($self) = @_;

  if ($self->is_anonymous) {
    return "/";
  }

  return "/user/".$self->username;
}

sub settings {
  my ($self) = shift;

  return $self->db_obj->settings( @_ );
}

#my @icons = qw(user user-tie smile portait user-secret);
#my @extra = qw(fas far);
my @icons = (
    'fas fa-user',
    'far fa-user',
    'fas fa-user-tie',
    'fas fa-smile',
    'far fa-smile',
    'fas fa-user-secret',
  );
sub _find_icon {
  my ($self) = @_;

  if ($self->is_anonymous) {
    return 'fas fa-user-alt-slash';
  }

  my $wid = $self->_weird_id;
  my $icon = $icons[ $wid % scalar @icons];

  return $icon;
}

my @colors = qw(
    blue
    azure
    indigo
    purple
    pink
    red
    orange
    yellow
    lime
    green
    teal
    cyan
  );
my %textwhite = map { $_ => 1 } @colors;
push @colors, qw(
    blue-lt
    azure-lt
    indigo-lt
    purple-lt
    pink-lt
    red-lt
    orange-lt
    yellow-lt
    lime-lt
    green-lt
    teal-lt
    cyan-lt
  );
sub _find_icon_color {
  my ($self) = @_;

  if ($self->is_anonymous) {
    return 'bg-muted-lt';
  }
  
  my $wid = $self->_weird_id;
  my $color = $colors[ $wid % scalar @colors ];

  if ( $textwhite{ $color } ) {
    $color .= ' text-white';
  }

  return "bg-$color";
}

my $i=1;
my %lval = map {
    $_ => $i++
  } (0..9, 'a'..'z');
sub _find_weird_id {
  my ($self) = @_;

  my $uname = $self->username;
  my $i = 1;
  my $wid = 0;
  for my $ch (split //, $uname) {
    $wid += ($lval{ $ch } || 0) * $i++;
  }

  return $wid;
}

1;
