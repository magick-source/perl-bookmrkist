package Bookmrkist::Action::BookmarksAPI;

use Mojo::Base qw(Mojolicious::Controller);

use Bookmrkist::Validator;

use Bookmrkist::Data::Bookmark;
use Bookmrkist::Data::Url;

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

  my ($bookmark, $url) = Bookmrkist::Data::Bookmark->add_bookmark( $c, $data );

  my %res;
  if ( $bookmark ) {
    $url = Bookmrkist::Data::Url->new( db_obj => $url, user => $c->user );
    $bookmark = Bookmrkist::Data::Bookmark->new(
          db_obj => $bookmark,
          url => $url,
          user => $c->user
        );

    my $ulink = $c->url_for($url->link)->to_abs->to_string;
    $ulink =~ s{\Ahttps?:}{};
    my $blink  = $c->url_for($bookmark->link)->to_abs->to_string;
    $blink =~ s{\Ahttps?:}{};
    %res = (
        done    => 1,
        objects => {
          url       => $ulink,
          bookmark  => $blink,
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

sub vote {
  my ($c) = @_;

  my $input = {
    bookmark    => $c->param('bookmark'),
    vote_type   => $c->param('vote_type'),
    csrf_token  => $c->param('vote_token'),
  };

  my $v = Bookmrkist::Validator->new->validation();
  $v->input( $input );
  $v->csrf_token( $c->csrf_token )
    unless $c->stash->{oathed};

  $v->required('bookmark','trim','not_empty')->link_hash();
  $v->required('vote_type','trim','not_empty')->vote_type();
  $v->csrf_protect()
    unless $c->stash->{oathed};

  return $c->handle_input_errors( $v, api_errors => 1 )
    if $v->has_error();

  my $data = $v->output();

  my ($resdata) = Bookmrkist::Data::Bookmark->cast_vote( $c, $data );

  $c->res->code( delete $resdata->{http_code} )
    if exists $resdata->{http_code};

  return $c->render(json => $resdata );
}

1;
