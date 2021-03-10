package Bookmrkist::Db::TagCount;

use parent 'Bookmrkist::Db';

__PACKAGE__->table('tag_count');

__PACKAGE__->columns(Primary => qw(tag_id));

__PACKAGE__->columns(Columns => qw(
    tag_id
    first_bookmark_time
    public_bookmarks
    total_score
    max_score
  ));

__PACKAGE__->set_sql( update_for_tag => <<EoQ );
SELECT  bt.tag_id,
        min(b.added) as first_bookmark_time,
        count(b.uuid) as public_bookmarks,
        sum(b.score) as total_score,
        max(b.score) as max_score
  FROM bookmark_tag bt
    LEFT JOIN bookmark b
      ON bt.bookmark_uuid = b.uuid
  WHERE bt.tag_id = ?
    AND FIND_IN_SET('active', b.flags)
    AND NOT FIND_IN_SET('private', b.flags)
    AND NOT FIND_IN_SET('adult', flags)
EoQ

sub update_for_tag {
  my ($class, $tag_id) = @_;

  $class->sql_update_for_tag()->execute( $tag_id );

  return;
}

1;
