##
# name:      WikiText::Kwiki::Parser
# abstract:  Kwiki WikiText Parser Module
# author:    Ingy döt Net <ingy@cpan.org>
# license:   perl
# copyright: 2008, 2010, 2011

package WikiText::Kwiki::Parser;
use strict;
use warnings;
use base 'WikiText::Parser';

use XXX;

# Reusable regexp generators used by the grammar
my $ALPHANUM = '\p{Letter}\p{Number}\pM';

# These are all stolen from URI.pm
my $reserved   = q{;/?:@&=+$,[]#};
my $mark       = q{-_.!~*'()};
my $unreserved = "A-Za-z0-9\Q$mark\E";
my $uric       = quotemeta($reserved) . $unreserved . "%";

sub create_grammar {
    my $all_phrases = [
        qw(wikilink a tt b i)
    ];
    my $all_blocks = [
        qw(
            pre
            hr hx
            ul ol
            table
            p empty
            else
        )
    ];

    return {
        _all_blocks => $all_blocks,
        _all_phrases => $all_phrases,

        top => {
            blocks => $all_blocks,
        },

        empty => {
            match => qr/^\s*\n/,
            filter => sub {
                my $node = shift;
                $node->{type} = '';
            },
        },

        p => {
           match =>  qr/^(            # Capture whole thing
                (?m:
                    ^(?!        # All consecutive lines *not* starting with
                    (?:
                        [\#\-\*]+[\ ] |
                        [\=\|\>] |
                        \.\w+\s*\n |
                        \{[^\}]+\}\s*\n
                    )
                    )
                    .*\S.*\n
                )+
                )
                (\s*\n)*   # and all blank lines after
            /x,
            phrases => $all_phrases,
            filter => sub { chomp },
        },

        else => {
            match => qr/^(.*)\n/,
            phrases => [],
            filter => sub {
                my $node = shift;
                $node->{type} = 'p';
            },
        },

        pre => {
            match => qr/^((?: +\S.*\n)(?:(?: +\S.*\n| *\n)*(?: +\S.*\n))?)/,
            filter => sub {
                my $node = shift;
                while (not /^\S/m) {
                    s/^ //gm;
                }
                $node->{text} = $_;
            },
        },

        hx => {
            match => qr/^(=+) *(.*?)(\s+=+)?\s*?\n+/,
            phrases => $all_phrases,
            filter => sub {
                my $node = shift;
                $node->{type} = 'h' . length($node->{1});
                $_ = $node->{text} = $node->{2};
            },
        },

        ul => {
            match => re_list('\*'),
            blocks => [qw(ul ol subl li)],
            filter => sub { s/^[\*\0] *//mg },
        },

        ol => {
            match => re_list('\0'),
            blocks => [qw(ul ol subl li)],
            filter => sub { s/^[\*\0] *//mg },
        },

        subl => {
            type => 'li',

            match => qr/^(          # Block must start at beginning
                                    # Capture everything in $1
                (.*)\n              # Capture the whole first line
                [\*\0]+\ .*\n      # Line starting with one or more bullet
                (?:[\*\0]+\ .*\n)*  # Lines starting with '*' or '0'
            )(?:\s*\n)?/x,          # Eat trailing lines
            blocks => [qw(ul ol li2)],
        },

        li => {
            match => qr/(.*)\n/,    # Capture the whole line
            phrases => $all_phrases,
        },

        li2 => {
            type => '',
            match => qr/(.*)\n/,    # Capture the whole line
            phrases => $all_phrases,
        },

        hr => {
            match => qr/^--+(?:\s*\n)?/,
        },

        table => {
            match => qr/^(
                (
                    (?m:^\|.*\|\ \n(?=\|))
                    |
                    (?m:^\|.*\|\ \ +\n)
                    |
                    (?ms:^\|.*?\|\n)
                )+
            )(?:\s*\n)?/x,
            blocks => ['tr'],
        },

        tr => {
            match => qr/^((?m:^\|.*?\|(?:\n| \n(?=\|)|  +\n)))/s,
            blocks => ['td'],
            filter => sub { s/\s+\z// },
        },

        td => {
            match => qr/\|?\s*(.*?)\s*\|\n?/s,
            phrases => $all_phrases,
        },

        wikilink => {
            match => qr/
                (?:"([^"]*)"\s*)?(?:^|(?<=[^$ALPHANUM]))\[(?=[^\s\[\]])
                (.*?)
                \](?=[^$ALPHANUM]|\z)
            /x,
            filter => sub {
                my $node = shift;
                $node->{attributes}{target} = $node->{2};
                $_ = $node->{1} || $node->{2};
            },
        },

        b => {
            match => re_huggy(q{\*}),
            phrases => $all_phrases,
        },

        tt => {
            match => re_huggy(q{\`}),
        },

        i => {
            match => WikiText::Kwiki::Parser::re_huggy(q{\_}),
            phrases => $all_phrases,
        },

        a => {
            type => 'hyperlink',
            match => qr{
                (?:"([^"]*)"\s*)?
                <?
                (
                    (?:http|https|ftp|irc|file):
                    (?://)?
                    [$uric]+
                    [A-Za-z0-9/#]
                )
                >?
            }x,
            filter => sub {
                my $node = shift;
                $_ = $node->{1} || $node->{2};
                $node->{attributes}{target} = $node->{2};
            },
        },

    };
}

sub re_huggy {
    my $brace1 = shift;
    my $brace2 = shift || $brace1;

    qr/
        (?:^|(?<=[^{$ALPHANUM}$brace1]))$brace1(?=\S)(?!$brace2)
        (.*?)
        $brace2(?=[^{$ALPHANUM}$brace2]|\z)
    /x;
}

sub re_list {
    my $bullet = shift;
    return qr/^(            # Block must start at beginning
                            # Capture everything in $1
        ^$bullet+\ .*\n     # Line starting with one or more bullet
        (?:[\*\0]+\ .*\n)*  # Lines starting with '*' or '0'
    )(?:\s*\n)?/x,          # Eat trailing lines
}

1;
