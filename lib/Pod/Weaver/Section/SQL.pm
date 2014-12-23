package Pod::Weaver::Section::SQL;

# ABSTRACT: Document SQL more easily by referencing only the SQL command in POD


use Moose;
with 'Pod::Weaver::Role::Section';
with 'Pod::Weaver::Role::Transformer';

use Moose::Autobox;

use Pod::Elemental::Selectors -all;
use Pod::Elemental::Transformer::Nester;
use Pod::Elemental::Transformer::Gatherer;

has __used_container => ( is => 'rw' );


sub transform_document {
    my ( $self, $document ) = @_;

    my $selector = s_command('sql');
    my $children = $document->children;

    # I don't know why this branch cannot be coverable, but manually my
    # tests cover both branches.
    #
    # uncoverable branch true
    # uncoverable branch false
    return unless $children->grep($selector)->length;

    my $nester = Pod::Elemental::Transformer::Nester->new(
        {
            top_selector => $selector,
            content_selectors =>
              [ s_command( [qw/head2 head3 head4 over item back/] ), s_flat, ],
        }
    );

    my ($container_id) = grep {
        my $c = $children->[$_];
        $c->isa("Pod::Elemental::Element::Nested")
          and $c->command eq 'sql'
          and $c->content;
    } 0 .. $#$children;

    my $container =
      $container_id
      ? splice @{$children}, $container_id, 1
      : Pod::Elemental::Element::Nested->new(
        {
            command => 'head1',
            content => 'SQL',
        }
      );

    $self->__used_container($container);

    my $gatherer = Pod::Elemental::Transformer::Gatherer->new(
        {
            gather_selector => $selector,
            container       => $container,
        }
    );

    $nester->transform_node($document);
    $gatherer->transform_node($document);

    my @queue;
    push @queue, @{ $container->children };
    $container->children( [] );

    while ( my $node = shift @queue ) {
        if (    $node->can('command')
            and $node->command eq 'sql' )
        {
            if ( $node->can('children') ) {

                # Move up every child of sql node
                push @queue, @{ $node->children };
            }
            push @{ $container->children },
              Pod::Elemental::Element::Generic::Text->new(
                content => _format_sql( $node->content . "\n\n" ) );
        }
        else {
            push @{ $container->children }, $node;
        }
    }
}


sub weave_section {
    my ( $self, $document, $input ) = @_;

    return unless $self->__used_container;

    my $in_node = $input->{pod_document}->children;
    my @found;
    $in_node->each(
        sub {
            my ( $i, $para ) = @_;
            push @found, $i
              if ( $para == $self->__used_container
                && $self->__used_container->children->length );
        }
    );

    my @to_add;
    for my $i ( reverse @found ) {
        push @to_add, splice @{$in_node}, $i, 1;
    }

    $document->children->push(@to_add);
}

sub _format_sql {
    my ($content) = @_;
    $content =~ s/SELECT/B<SELECT>/g;
    $content =~ s/FROM/B<FROM>/g;
    return $content;
}

__PACKAGE__->meta->make_immutable;
1;

__END__
=pod

=encoding UTF-8

=head1 NAME

Pod::Weaver::Section::SQL - Document SQL more easily by referencing only the SQL command in POD

=head1 VERSION

version 0.01

=head1 SYNOPSIS

Update your weaver.ini file with

  [SQL]
  command = sql

It will then gather all B<=sql> section into one unique SQL section in your
documentation.

=head1 METHODS

=head2 transform_document

Gathers all

  =sql

  =cut

Commands into the same Pod document node.

=head2 weave_section

Remove the section gathered in L<transform_document> from the source document.

=head1 AUTHOR

Armand Leclercq <armand.leclercq@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2014 by Armand Leclercq.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut

