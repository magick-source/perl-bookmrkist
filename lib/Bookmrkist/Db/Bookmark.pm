package Bookmrkist::Db::Bookmark;

use parent 'Bookmrkist::Db';

__PACKAGE__->table('bookmark');

__PACKAGE__->columns(Primary => qw(id));



1;
