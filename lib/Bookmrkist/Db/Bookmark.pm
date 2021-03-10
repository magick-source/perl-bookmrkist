package Bookmrkist::Db::Bookmark;

use parent 'Bookmrkist::Db';

use SorWeTo::Utils::Digests qw(
  generate_random_hash
  hash2uuid
  uuid2hash
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

__PACKAGE__->set_sql( count_for_url => <<EoQ);
SELECT COUNT(uuid)
  FROM __TABLE__
  WHERE url_uuid = ?
    AND NOT find_in_set('private', flags)
    AND find_in_set('active', flags)
EoQ

__PACKAGE__->set_sql( stats_for_url => <<EoQ );
SELECT  floor(max(score)*(100+count(score)))/100 as base_score,
        min( added ) as first_added
  FROM  __TABLE__
  WHERE url_uuid = ?
    AND NOT find_in_set('private', flags)
    AND NOT find_in_set('adult', flags)
    AND find_in_set('active', flags)
EoQ

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

sub link_hash {
  my ($self) = @_;

  return uuid2hash( $self->uuid );
}

sub count_for_url {
  my ($class, $url_uuid) = @_;

  my $count = $class->sql_count_for_url()->select_val( $url_uuid );
  
  print STDERR "count_for_url [$url_uuid]: $count\n";

  return $count;
}

sub stats_for_url {
  my ($class, $url_uuid) = @_;

  my ($score, $added) = $class->sql_stats_for_url()->select_row($url_uuid);

  return ($score, $added );
}


1;
