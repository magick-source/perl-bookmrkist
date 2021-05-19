package Bookmrkist;

use Mojo::Base qw(SorWeTo::Server);

use Bookmrkist::Db;
use Bookmrkist::User;
use Bookmrkist::Scoring;

use Bookmrkist::Data::Tag;
use Bookmrkist::Data::User;

has _current_config => 'xxx';
has shared_users => 0;

sub startup {
  my ($self) = @_;

  $self->SUPER::startup;

  $self->load_plugin('email');
  $self->load_plugin('TmpBlob');
  $self->load_plugin('user');
  $self->load_plugin('login');
  $self->load_plugin('MySQL');
  $self->load_plugin('themes');
  $self->load_plugin('MoreHelpers');
  $self->load_plugin('UserSettings');
  $self->load_plugin('CookieConsent');

  my $conf = $self->config->config('bookmrkist');

  $self->shared_users(1) if ($conf->{shared_users});
  
  $self->defaults->{'footer-text'} = 'Built with Bookmrkist';

  Bookmrkist::User->register( $self );
  Bookmrkist::Scoring->register( $self );

  # no config, use same database as sorweto
  if ( my $config = $self->config->config('mysql:bookmrkist') ) {
    if (keys %$config) {
      Bookmrkist::Db->init( $config );
    }
  }

  $self->register_routes;

  $self->register_themes;

  $self->helper( needed_js   => \&_needed_js );
  $self->helper( needed_css  => \&_needed_css );
  $self->helper( global_top_tags => \&_global_top_tags );
  $self->helper( bk_user => \&_get_bk_user );
  $self->html_hook(html_body_end => \&_html_body_end );
  $self->html_hook(html_head     => \&_html_head );

  $self->register_static;

  $self->register_themes('bookmrkist');
  $self->register_translations('translations', { application => 'bookmrkist' });

  $self->register_user_setting({ name => 'user_score', is_number => 1});

  return $self;
}

sub register_routes {
  my ($self) = @_;

  # Routes and stuff 
  my $r = $self->routes;
  unshift @{$r->namespaces}, 'Bookmrkist::Action';

  $r->any('/')->to('Bookmarks#list');
  $r->any('/recent')->to('Bookmarks#list', recent => 1);
  $r->any('/recent/:tag' => [tag => qr/\w[\w\-]*\w/])
    ->to('Bookmarks#list', recent => 1);
  $r->any('/recent/u/:username'
          => [ username => qr/\w{3,}/,
             ])->to('Bookmarks#list', recent => 1);
  $r->any('/recent/u/:username/:tag'
          => [ username => qr/\w{3,}/,
               tag      => qr/\w[\w-]{2,}\w/,
             ])->to('Bookmarks#list', recent => 1);


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

  $r->get('/goto/:link_hash'
            => [link_has => qr/[0-9a-z]{30}/
               ])->to('Bookmarks#goto');

  my $user_api = $r->api_can('add_links');
  $user_api->any('/add-link')->to('BookmarksAPI#add_link');
  $user_api->post('/vote')->to('BookmarksAPI#vote');

  return;
}

sub _around_action {
  my ($self, $next, $c, $action, $last) = @_;

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

  if ( $c->user->is_anonymous ) {
    $res .= $c->include('inc/login_toast');
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
