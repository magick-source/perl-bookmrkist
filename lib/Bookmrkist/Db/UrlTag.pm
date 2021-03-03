package Bookmrkist::Db::UrlTag;

use parent 'Bookmrkist::Db';


__PACKAGE__->table('url_tag');

__PACKAGE__->columns(Primary => qw( url_uuid tag_id ) );

__PACKAGE__->columns(Columns => qw(
    url_uuid
    tag_id
    first_bookmark_time
    last_bookmark_time
    public_bookmarks
    total_score
    max_score
    last_updated
  ));

__PACKAGE__->set_sql( delete_for_url => <<EoQ );
DELETE FROM __TABLE__ WHERE url_uuid = ?
EoQ
__PACKAGE__->set_sql( update_for_url => <<EoQ );
INSERT INTO __TABLE__
  SELECT tag_id, bg.*, NOW()
    FROM (
        SELECT  url_uuid,
                min(added) as first_bookmark_time,
                max(added) as last_bookmark_time,
                count(uuid) as public_bookmarks,
                max(score) as max_score,
                sum(score) as total_score
          FROM bookmark
          WHERE url_uuid = ?
            AND FIND_IN_SET('active', flags)
            AND NOT FIND_IN_SET('private', flags)
            AND NOT FIND_IN_SET('adult', flags)
          GROUP by url_uuid
      ) bg
    LEFT JOIN (
        SELECT distinct url_uuid, tag_id
          FROM bookmark b
            LEFT JOIN bookmark_tag bt
              ON b.uuid = bt.bookmark_uuid
          WHERE url_uuid = ?
      )  ut
      ON bg.url_uuid = ut.url_uuid
EoQ

sub update_for_url {
  my ($class, $url_uuid) = @_;

  $class->do_transaction(sub {
      $class->sql_delete_for_url()->execute( $url_uuid );
      $class->sql_update_for_url()->execute( $url_uuid );
    });

  return;
}


sub find_or_create {
  my ($class, $url) = @_;

  my ($domain) = $url =~ m{\A\w+://([^/]+)};
  $domain =~ s{\Awww\.}{};

  my ($rec) = $class->search({
      domain  => $domain,
      url     => $url,
    });

  unless ( $rec ) {
    my $uuid = hash2uuid( generate_random_hash( 'bookmrkist-url' ) );

    ($rec) = $class->insert({
        uuid    => $uuid,
        domain  => $domain,
        url     => $url,
        flags   => "active,pending"
      });
  }

  return $rec;
}

1;
