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

__PACKAGE__->set_sql(top_tags => <<EoQ);
SELECT * FROM __TABLE__ WHERE id in (
  SELECT tag_id FROM (
    SELECT tag_id, count(bookmark_uuid) c
      FROM bookmark b
        LEFT JOIN bookmark_tag bt
          ON b.uuid = bt.bookmark_uuid
      WHERE b.url_uuid = ?
      GROUP by tag_id
      ORDER by c DESC
      LIMIT 5
  ) btc
)
EoQ

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

sub top_tags_for_url {
  my ($class, $url_uuid) = @_;

  return $class->search_top_tags( $url_uuid );
}

1;
