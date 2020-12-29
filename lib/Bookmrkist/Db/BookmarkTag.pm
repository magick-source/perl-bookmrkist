package Bookmrkist::Db::BookmarkTag;

use parent 'Bookmrkist::Db';

__PACKAGE__->table('bookmark_tag');

__PACKAGE__->columns(Primary => qw(bookmark_uuid tag_id));

__PACKAGE__->columns(Columns => qw(
    bookmark_uuid
    tag_id
    bookmark_time
    bookmark_score
    bookmark_flags
  ));


sub update_links {
  my ($class, $bookmark, $tags) = @_;

  my %existing = map { $_->tag_id => $_ } $class->search({
      bookmark_uuid => $bookmark->uuid
    });
  
  my ($time, $score, $flags) = (
      $bookmark->added,
      $bookmark->score,
      $bookmark->flags,
    );
  $flags = join ',',
      grep { $_ eq 'adult' or $_ eq 'private' }
      split /,/, $flags;

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

  return @links;
}

1;
