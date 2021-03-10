package Bookmrkist::Data::LazyList;

use Mojo::Base -base;

use base q(Class::Data::Inheritable);

__PACKAGE__->mk_classdata('record_class');
__PACKAGE__->mk_classdata('db_class');
__PACKAGE__->mk_classdata('key_field');

has 'data' => \&_load_data;
has '_search';

sub search {
  my ($class) = shift;

  die "Missing 'record_class' or 'db_class' for $class"
    unless $class->record_class or $class->db_class;

  my %search;
  if ($#_ == 0) {
    %search = %{ $_[0] };
  } else {
    %search = @_;
  }

  return $class->new( _search => \%search );
}

sub get {
  my ($self, $key) = @_;

  my $rec = $self->data->{ $key };
  unless ( $rec ) {
    if ( $self->can('null_record') ) {
      $rec = $self->null_record;
    }
  }

  return $rec;
}

sub _load_data {
  my ($self) = @_;

  my $data_class  = $self->record_class;
  my $db_class    = $self->db_class || $data_class->db_class;

  my $search = $self->_search;
  use Data::Dumper;
  print STDERR "lazylist search: ", Dumper($search);
  
  my @records = $db_class->search_where( $self->_search );

  if ( $data_class ) {
    @records = map { $data_class->new( db_obj => $_ ) } @records;
  }

  my $kfield = $self->key_field || 'id';
  my %records = map {
      $_->$kfield() => $_ 
    } @records;

  if ( $self->can('data_loaded') ) {
    $self->data_loaded( @records );
  }

  return \%records;
}


1;
