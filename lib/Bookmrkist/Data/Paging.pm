package Bookmrkist::Data::Paging;

use Mojo::Base -base;

has 'base_url';
has 'cur_page';
has 'total_pages';

sub first {
  my ($self) = @_;

  return (($self->cur_page > 3) ? ( $self->cur_page -2 ) : 1);
}

sub last {
  my ($self) = @_;

  return (  ($self->cur_page < $self->total_pages - 3)
            ? ( $self->cur_page + 2 )
            : $self->total_pages );
}

sub page_url {
  my ($self, $page) = @_;

  my $url = $self->base_url;

  $page = undef if $page and $page == 1;

  $url->query->merge(page => $page);

  return $url->to_string;
}

1;
