package Bookmrkist::Db::BookmarkTag;

use parent 'Bookmrkist::Db';

__PACKAGE__->table('bookmark_tag');

__PACKAGE__->columns(Primary => qw(bookmark_uuid tag_id));

__PACKAGE__->columns(Columns => qw(
    bookmark_uuid
    tag_id
    user_id
    bookmark_time
    bookmark_score
    bookmark_flags
  ));


__PACKAGE__->set_sql(top_tags_for_url => <<EoQ);
SELECT tag_id, count(bookmark_uuid) c
  FROM bookmark b
    LEFT JOIN bookmark_tag bt
      ON b.uuid = bt.bookmark_uuid
  WHERE b.url_uuid = ?
  GROUP by tag_id
  ORDER by c DESC
  LIMIT %s
EoQ

__PACKAGE__->set_sql(top_tags => <<EoQ);
SELECT tag_id, count(bookmark_uuid) c
  FROM __TABLE__
  GROUP by tag_id
  ORDER by c DESC
  LIMIT %s
EoQ

sub update_links {
  my ($class, $bookmark, $tags) = @_;

  my %existing = map { $_->tag_id => $_ } $class->search({
      bookmark_uuid => $bookmark->uuid
    });
  
  my ($user_id, $time, $score, $flags) = (
      $bookmark->user_id,
      $bookmark->added,
      $bookmark->score,
      $bookmark->flags,
    );

  my @links = ();
  for my $tag (@$tags) {
    my $rec;
    if (  $existing{ $tag->id } ) {
      $rec = delete $existing{ $tag->id };
      $rec->bookmark_score( $score );
      $rec->bookmark_flags( $flags );
      $rec->update;

    } else {
      ($rec) = $class->insert({
          bookmark_uuid   => $bookmark->uuid,
          tag_id          => $tag->id,
          user_id         => $user_id,
          bookmark_score  => $score,
          bookmark_time   => $time,
          bookmark_flags  => $flags,
        });
    }

    push @links, $rec if $rec;
  }

  for my $link (values %existing) {
    $link->delete;
  }

  return { active => \@links, deleted => [values %existing] };
}

sub top_tags {
  my ($class, %params) = @_;

  my $url = delete $params{url_uuid};

  my $paging;
  my ($page) = delete $params{ page } || 1;
  my ($count) = delete $params{ count };
  unless ($count) {
    $count = $url ? 5 : 25;
  }
  my $first = ($page-1) * $count;
  $paging = "$first,$count";

  my $sth;
  if ( $url ) {
    $sth = $class->sql_top_tags_for_url( $paging );
    $sth->execute( $url );
  } else {
    $sth = $class->sql_top_tags( $paging );
    $sth->execute();
  }

  return $sth;
}

1;
