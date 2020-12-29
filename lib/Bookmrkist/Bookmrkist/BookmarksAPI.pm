package Bookmrkist::Bookmrkist::BookmarksAPI;

use Mojo::Base qw(Mojolicious::Controller);

use Bookmrkist::Validator;
use Bookmrkist::Db::Url;
use Bookmrkist::Db::Bookmark;

sub add_link {
  my ($c) = @_;

  my $v = Bookmrkist::Validator->new->validation();

  my $input = {
    url         => $c->param('url'),
    title       => $c->param('title'),
    description => $c->param('description'),
    tags        => $c->param('tags'),
    csrf_token  => $c->param('csrf_token'),
  };

  $v->input( $input );

  $v->csrf_token( $c->csrf_token() )
    unless $c->stash->{oathed};

  $v->required('url','trim','not_empty')->url();
  $v->optional('title','trim','not_empty');
  $v->optional('description','trim','not_empty');
  $v->optional('tags','trim','not_empty')->tags();
  $v->csrf_protect()
    unless $c->stash->{oathed};

  return $c->handle_input_errors( $v, api_errors => 1 )
    if $v->has_error();

  my $data = $v->output();

  my ($url) = Bookmrkist::Db::Url->find_or_create( $data->{url} );

  my ($bookmark) = Bookmrkist::Db::Bookmark->find_or_create({
      url_uuid  => $url->uuid,
      title     => $data->{title},
      comment   => $data->{description},
      user_id   => $c->user->user_id,
    });

  my %res;
  if ( $bookmark ) {
    %res = (
        done    => 1,
        objects => {
          url       => $c->url_for('/url/'.$url->link_hash)->to_abs,
          bookmark  => $c->url_for('/bookmark/'.$bookmark->link_hash)->to_abs,
        },
      );

  } else {
    $c->res->code(500);
    %res = (
        done    => 0,
        errors  => [{
          type => 'unknow',
          message => $c->translate('error_unknow_no_db_object'),
        }],
      );
  }

  return $c->render(json => \%res);
}

1;
