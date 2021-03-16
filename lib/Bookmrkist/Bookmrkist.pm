package Bookmrkist::Bookmrkist;

use Mojo::Base qw(Mojolicious::Plugin);

use Bookmrkist::Db;
use Bookmrkist::User;
use Bookmrkist::Scoring;

use Bookmrkist::Data::Tag;

has _current_config => 'xxx';
has 'app';
has shared_users => 0;

sub register {
  my ($self, $app, $conf) = @_;

  $self->app($app);
  $self->shared_users(1) if ($conf->{shared_users});
  
  $app->defaults->{'footer-text'} = 'Built with Bookmrkist';

  Bookmrkist::User->register( $app );
  Bookmrkist::Scoring->register( $app );

  # Routes and stuff 
  my $r = $app->routes;
  unshift @{$r->namespaces}, 'Bookmrkist::Bookmrkist';

  $r->any('/')->to('Bookmarks#list');
  $r->any('/recent')->to('Bookmarks#list', recent => 1);
  $r->any('/recent/:tag' => [tag => qr/\w[\w\-]*\w/])
    ->to('Bookmarks#list', recent => 1);

  $r->any('/tag/:tag'=> [tag  => qr/\w[\w\-]*\w/])->to('Bookmarks#list');
  $r->any('/user/:username' => [username => qr/\w{3,}/])->to('Bookmarks#list');
  $r->any('/user/:username/:tag'
          => [ username => qr/\w{3,}/,
               tag      => qr/\w[\w-]{2,}\w/,
             ])->to('Bookmarks#list');

  $r->any('/add')->to('Bookmarks#add_page');

  $r->get('/url/:link_hash'
            => [link_hash => qr/[0-9a-z]{30}/
               ])->to('Bookmarks#view');

  my $user_api = $r->api_can('add_links');
  $user_api->any('/add-link')->to('BookmarksAPI#add_link');

  # to make multi-site work
  $app->hook(around_action  => sub { $self->_around_action( @_ ) });

  $app->helper( needed_js   => \&_needed_js );
  $app->helper( needed_css  => \&_needed_css );
  $app->helper( global_top_tags => \&_global_top_tags );
  $app->helper( bk_user => \&_get_bk_user );
  $app->html_hook(html_body_end => \&_html_body_end );
  $app->html_hook(html_head     => \&_html_head );

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

  $c->needed_css('/css/bookmrkist.css');

  return $next->();
}

sub _needed_js {
  my ($c, @paths) = @_;

  for my $js_path ( @paths ) {
    $c->stash->{needed_js}->{ $js_path } = undef;
  }

  return;
}

sub _needed_css {
  my ($c, @paths) = @_;

  for my $js_path ( @paths ) {
    $c->stash->{needed_css}->{ $js_path } = undef;
  }

  return;
}

sub _get_bk_user {
  my ($c) = @_;

  return Bookmrkist::Data::User->new( db_obj => $c->user );
}

sub _global_top_tags {
  my ($c) = @_;

  return Bookmrkist::Data::Tag->global_top_tags();
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

sub _html_head {
  my ($c, @params) = @_;

  my $res = '';
  if (my $needed = $c->stash->{needed_css}) {
    for my $css (keys %{ $needed }) {
      $css = "/css/$css" unless $css =~ m{\A/};
      $css .= '.css' unless $css =~ m{\.\w{3,}\z};
      $res .= "<link href='$css' rel='stylesheet' type='text/css' />\n";
    }
  }


  return $res;
}

1;
