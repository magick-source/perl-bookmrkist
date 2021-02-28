package Bookmrkist::Data::Tag;

use Mojo::Base 'Bookmrkist::Data::Base';

use Bookmrkist::Db::Tag;

__PACKAGE__->db_class('Bookmrkist::Db::Tag');

has color => \&_pick_color;

sub search {
  my ($class, %filters) = @_;

  my @tags = Bookmrkist::Db::Tag->search_where( %filters );

  @tags = map { $class->new( db_obj => $_ ) } @tags;

  return @tags;
}

sub top_tags_for_url {
  my ($class, $url_uuid) = @_;

  my @tags = Bookmrkist::Db::Tag->top_tags_for_url( $url_uuid );

  @tags = map { $class->new( db_obj => $_ ) } @tags;

  return @tags;
}

sub link {
  my ($self) = @_;

  return '/tag/'.$self->url;
}

my @colors = qw[
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
  ];

my $i = 1;
my %lcolor = map { $_ => $i++ } (
    0..9, 'a'..'z', '-'
  );

sub _pick_color {
  my ($self) = @_;

  my $i = 1;
  my $c = 0;
  for my $ch (split //, $self->url) {
    $c += ($lcolor{ $ch } || 0) * $i++;
  }

  $c = $c % scalar @colors;

  return "bg-$colors[$c]";
}

__PACKAGE__->make_column_accessors( );

1;
