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


#TODO: update for tag, maybe

1;
