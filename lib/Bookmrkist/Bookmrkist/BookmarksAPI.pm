package Bookmrkist::Bookmrkist::BookmarksAPI;

use Mojo::Base qw(Mojolicious::Controller);

use Bookmrkist::Validator;


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

use Data::Dumper;
print STDERR "input: ", Dumper( $input );

  $v->input( $input );

  $v->csrf_token( $c->csrf_token() )
    unless $c->stash->{oathed};

  $v->required('url','trim','not_empty')->url();
  $v->optional('title','trim','not_empty');
  $v->optional('description','trim','not_empty');
  $v->optional('tags','trim','not_empty')->tags();
  $v->csrf_protect()
    unless $c->stash->{oathed};

  if ( $v->has_error() ) {
    my %errors = map { $_ => $v->error( $_ ) } @{ $v->failed };
    
    use Data::Dumper;
    print STDERR "errors: ", Dumper(\%errors);

    return $c->api_fail( 400 => { errors => \%errors });
  }

  my $data = $v->output();

  

  use Data::Dumper;
  print STDERR "data: ", Dumper( $data );

  return $c->render(json => { done => 0 });
}

sub __finish_with_error { 
  my ($c) = @_;

  return unless $c->res->code() == 200;

  $c->res->code(400);
  $c->render(json => { errors => $c->flash('errors') });
}

1;
