package Bookmrkist::Db::BookmarkVote;

use parent 'Bookmrkist::Db';

__PACKAGE__->table('bookmark_vote');

__PACKAGE__->columns(Primary => qw( bookmark_uuid user_id ) );

__PACKAGE__->columns( Columns => qw(
    bookmark_uuid
    user_id
    vote_type
    score
    voted_at
    flags
  ));

1;
