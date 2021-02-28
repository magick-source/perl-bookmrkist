package Bookmrkist::Data::Base;

use Mojo::Base -base;

use base qw(Class::Data::Inheritable);

has db_obj => undef;

__PACKAGE__->mk_classdata('db_class');

sub _make_method {
  my $class = shift;

  my $db_class = $class->db_class;
  my $mk_method = $db_class->can('_make_method');
  die "$db_class can't make methods - is it a Class:DBI class?"
    unless $mk_method;

  $class->$mk_method( @_ );
}

sub primary_columns {
  my ($class) = @_;

  return $class->db_class->primary_columns;
}

sub make_column_accessors {
  my ($class) = @_;

  return unless my $db_class = $class->db_class();

  my @cols = $db_class->all_columns();

  for my $col (@cols) {
    my $acc_name = $db_class->accessor_name_for($col);
    my $method = sub {
      my ($self) = @_;
      return unless $self->db_obj;
      return $self->db_obj->$acc_name();
    };

    $class->_make_method( $acc_name => $method );
  }
}


1;
