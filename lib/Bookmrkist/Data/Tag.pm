package Bookmrkist::Data::Tag;

use Mojo::Base 'Bookmrkist::Data::Base';

use Bookmrkist::Db::Tag;
use Bookmrkist::Db::TagCount;
use Bookmrkist::Db::BookmarkTag;

__PACKAGE__->db_class('Bookmrkist::Db::Tag');

has color => \&_pick_color;

has count => sub { 1 };

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

sub global_top_tags {
  my ($class) = @_;

  my @tag_ids = Bookmrkist::Db::TagCount->search_where({
      public_bookmarks  => { '>' => 1 }, 
    },{
      limit_dialect => 'LimitOffset',
      limit         => 25,
      offset        => 0,
      order_by      => 'total_score desc',
    });
  my %tag_counts = map { $_->tag_id => $_->public_bookmarks } @tag_ids;

  my @tags = Bookmrkist::Db::Tag->search_where( id => [keys %tag_counts] );

  @tags = map { 
            $class->new( db_obj => $_, count => $tag_counts{ $_->id } )
          } @tags;

  @tags = sort { $b->count <=>$a->count || $b->url cmp $a->url } @tags;

  return @tags;
}

sub link {
  my ($self) = @_;

  return '/tag/'.$self->url;
}

sub label {
  my ($self) = @_;

  my $label = $self->display_name;

  if ($self->count and $self->count > 1) {
    $label .= ' ( '.$self->count.' )';
  }

  return $label;
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
