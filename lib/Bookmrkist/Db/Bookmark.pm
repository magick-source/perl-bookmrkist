package Bookmrkist::Db::Bookmark;

use parent 'Bookmrkist::Db';

use SorWeTo::Utils::Digests qw(
  generate_random_hash
  hash2uuid
  link_hash
);

__PACKAGE__->table('bookmark');

__PACKAGE__->columns(Primary => qw(uuid));

__PACKAGE__->columns(Columns => qw(
    uuid
    url_uuid
    user_id
    title
    comment
    score
    flags
    last_updated
    added
  ));

sub find_or_create {
  my ($class, $bookmark) = @_;

  my ($rec) = $class->search({
      url_uuid  => $bookmark->{url_uuid},
      user_id   => $bookmark->{user_id},
    });
 
  unless ( $rec ) {
    my $uuid = hash2uuid( generate_random_hash( 'bookmrkist-bookmark' ) );
    
    ($rec) = $class->insert({
        %$bookmark,
        uuid  => $uuid,
        flags => 'active',
      });
  }

  return $rec;
}

1;
