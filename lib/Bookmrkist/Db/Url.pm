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
