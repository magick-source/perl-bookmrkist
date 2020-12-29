package Bookmrkist::Db::Tag;

use parent 'Bookmrkist::Db';

use SorWeTo::Utils::String qw(
  urify
);

__PACKAGE__->table('tag');

__PACKAGE__->columns(Primary => qw(id));

__PACKAGE__->columns(Columns => qw(
    id
    url
    display_name
    icon
    flags
  ));

sub find_or_create {
  my ($class, $tag) = @_;

  my $url = urify( $tag );

  my ($rec) = $class->search({
      url => $url,
    });
 
  unless ( $rec ) {
    ($rec) = $class->insert({
        url           => $url,
        display_name  => $tag,
        flags => '',
      });
  }

  return $rec;
}

sub find_or_create_many {
  my ($class, $tags) = @_;

  unless (ref $tags eq 'ARRAY') {
    $tags = [ split /\s*,\s*/, $tags ];
  }
  
  my @recs;
  for my $tag (@$tags) {
    push @recs, $class->find_or_create( $tag );
  }

  return @recs;
}

1;
