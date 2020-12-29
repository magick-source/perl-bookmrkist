package Bookmrkist::Bookmrkist;

use Mojo::Base qw(Mojolicious::Plugin);

use Bookmrkist::Db;
use Bookmrkist::User;
use Bookmrkist::Scoring;

has _current_config => 'xxx';
has 'app';
has shared_users => 0;

sub register {
  my ($self, $app, $conf) = @_;

  $self->app($app);
  $self->shared_users(1) if ($conf->{shared_users});

  Bookmrkist::User->register( $app );
  Bookmrkist::Scoring->register( $app );

  # Routes and stuff 
  my $r = $app->routes;
  unshift @{$r->namespaces}, 'Bookmrkist::Bookmrkist';

  $r->route('/')->to('Bookmarks#list');
  $r->route('/tag/:tag'=> [tag  => qr/\w[\w\-]{2,}\w/])->to('Bookmarks#list');
  $r->route('/u/:user' => [user => qr/\w{3,}/]        )->to('Bookmarks#list');
  $r->route('/u/:user/:tag'
          => [ user => qr/\w{3,}/,
               tag  => qr/\w[\w-]{2,}\w/,
             ])->to('Bookmarks#list');

  $r->route('/add')->to('Bookmarks#add_page');

  my $user_api = $r->api_can('add_links');
  $user_api->route('/add-link')->to('BookmarksAPI#add_link');

  # to make multi-site work
  $app->hook(around_action  => sub { $self->_around_action( @_ ) });

  $app->helper( needed_js => \&_needed_js );
  $app->html_hook(html_body_end  => \&_html_body_end );

  return $self;
}

sub post_register {
  my ($self, $app) = @_;	

  Bookmrkist::User->post_register( $app );

  $app->register_themes('bookmrkist');
  $app->register_translations('translations', { application => 'bookmrkist' });
}

sub _around_action {
  my ($self, $next, $c, $action, $last) = @_;

  my $hostname = $c->req->url->base->host;

  $hostname =~ s{[^\w\.]}{-}g;
  unless ($self->_current_config eq "mysql:$hostname") {
    my $app = $self->app;
    my $dbinfo = $app->config->config("mysql:$hostname");
    if ($dbinfo and keys %$dbinfo) {
      Bookmrkist::Db->init( $dbinfo );
      unless ($self->shared_users) {
        SorWeTo::Db->init( $dbinfo );
      }
      
      $self->_current_config("mysql:$hostname");
    } elsif ($self->_current_config ne '') {
      $dbinfo = $app->config->config('mysql');
      Bookmrkist::Db->init( $dbinfo );
      unless ($self->shared_users) {
        SorWeTo::Db->init( $dbinfo );
      }
      
      $self->_current_config('');
    }

    print STDERR "user score: ", $c->user->score(), "\n\n";
  }

  return $next->();
}

sub _needed_js {
  my ($c, @paths) = @_;

  for my $js_path ( @paths ) {
    $c->stash->{needed_js}->{ $js_path } = undef;
  }

  return;
}

sub _html_body_end {
  my ($c, @params) = @_;

  my $res = '';
  if (my $needed = $c->stash->{needed_js}) {
    for my $js (keys %{ $needed }) {
      $js = "/js/$js" unless $js =~ m{\A/};
      $js .= '.js' unless $js =~ m{\.\w{2,}\z};
      $res .= "<script src='$js'></script>\n";
    }
  }

  return $res;
}

1;
