##
# name:      WikiText::Markdown::Emitter
# abstract:  A WikiText Receiver That Generates Markdown
# author:    Ingy döt Net <ingy@cpan.org>
# license:   perl
# copyright: 2008, 2011

package WikiText::Markdown::Emitter;
use strict;
use warnings;
use base 'WikiText::Emitter';

use XXX;

use constant NN => "\n\n";
my $pre = 0;

# TODO
# .pre conversion
use constant markdown => {
    h1 => ['# ', NN],
    h2 => ['## ', NN],
    h3 => ['### ', NN],
    h4 => ['#### ', NN],
    h5 => ['##### ', NN],
    h6 => ['###### ', NN],
    p => ['', NN],
    hr => ['---', NN],
    ul => [undef, undef],
    ol => [undef, undef],
    li => [undef, "\n"],
    hyperlink => [undef,''],
    wikilink => ['[','][]'],
    b => ['**', '**'],
    i => ['_', '_'],
    tt => ['`', '`'],
    mail => ['mailto:',''],
    table => ['', NN],
    tr => ['', "|\n"],
    td => ['| ', ' '],
    pre => [undef, "\n"],
};

sub begin_node {
    my ($self, $node) = @_;
    my $type = $node->{type};
    my $markdown = markdown()->{$type}
        or die "Unhandled markup '$type'";
    my $method = "begin_$type";
    $self->{output} .= defined $markdown->[0]
        ? $markdown->[0]
        : $self->$method($node);
}

sub end_node {
    my ($self, $node) = @_;
    my $type = $node->{type};
    my $markdown = markdown()->{$type}
        or die "Unhandled markup '$type'";
    my $method = "end_$type";
    $self->{output} .= defined $markdown->[1]
        ? $markdown->[1]
        : $self->$method($node);
}

sub text_node {
    my ($self, $text) = @_;
    if ($self->{link}) {
        $self->{link_text} = $text;
    }
    elsif ($pre) {
        $pre = 0;
        $text =~ s/^/    /gm;
        $text =~ s/^ *$//gm;
        $self->{output} .= $text;
    }
    else {
        $self->{output} .= $text;
    }
}

sub begin_pre {
    $pre = 1;
    '';
}

sub begin_hyperlink {
    my ($self, $node) = @_;
    $self->{link} = $node->{attributes}{target};
    return '';
}

sub end_hyperlink {
    my ($self, $node) = @_;
    my $link = delete($self->{link}) or die;
    my $link_text = delete($self->{link_text}) or die;
    return $link if $link eq $link_text;
    return "[$link_text]($link)";
}

sub begin_ol {
    my ($self) = @_;
    $self->{list_stack}[$self->{list_depth}++] = 'ol';
    '';
}

sub begin_ul {
    my ($self) = @_;
    $self->{list_stack}[$self->{list_depth}++] = 'ul';
    '';
}

sub begin_li {
    my ($self) = @_;
    my $depth = $self->{list_depth};
    my $indent = ' ' x (($depth - 1) * 2);
    return $indent . '* '
        if $self->{list_stack}[$depth - 1] eq 'ul';
    return $indent . '1. ';
}

sub end_ol {
    my ($self) = @_;
    my $depth = --$self->{list_depth};
    return($depth ? "" : "\n");
}

sub end_ul {
    my ($self) = @_;
    my $depth = --$self->{list_depth};
    return($depth ? "" : "\n");
}

1;

=head1 SYNOPSIS

    use WikiText::Markdown::Emitter;

=head1 DESCRIPTION

This receiver module, when hooked up to a parser, produces Markdown.
