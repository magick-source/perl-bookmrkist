package Bookmrkist::Db::Url;

use parent 'Bookmrkist::Db';

use SorWeTo::Utils::Digests qw(
  generate_random_hash
  hash2uuid
);

__PACKAGE__->table('url');

__PACKAGE__->columns(Primary => qw( uuid ) );

__PACKAGE__->columns(Columns => qw(
    uuid
    domain
    url
    icon
    shoot
    page_title
    description
    flags
    base_score
    first_added
    last_updated
  ));

__PACKAGE__->set_sql(update_base_score => <<EoQ );
INSERT INTO __TABLE__
  (uuid, base_score)
  SELECT url_uuid, max(score)
    FROM bookmark b
    WHERE url_uuid = ?
      AND FIND_IN_SET('active', b.flags)
      AND NOT FIND_IN_SET('private', b.flags)
      AND NOT FIND_IN_SET('adult', flags)
    GROUP by url_uuid
  ON DUPLICATE KEY
    UPDATE
      base_score=VALUES(base_score)
EoQ

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

sub update_base_score {
  my ($class, $url_uuid) = @_;

  $class->sql_update_base_score()->execute( $url_uuid );

  return;
}

1;
