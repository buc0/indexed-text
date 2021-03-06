#!/usr/bin/env perl6

use v6;

# structure of a file metadata stash:
# local-data => ( list-of-mixed-literals-and-marks )
# nonlocal-data => (
#   key => (
#       attribution => value,
#   ),
# )
# where the value may be a complex data structure
#   (and probably will be almost all the time)
#   

# the result of a parse is:
#   a list of local-data
#   a list of other metadata stashes in which to add/update nonlocal-data
#       each of which contains a list of key/value pairs
# It is explicitly allowed for the current metadata stash to be specified as a recipient of nonlocal-data

# each mark may contribute:
#   one item to the local-data, either a constant string or a hash (with some constraints)
#   one item each to zero-or-more other stashes, to be stored in their nonlocal-data
# It is explicitly allowed that a mark may contribute to the nonlocal-data of the current metadata stash

# X{Z} is a shortcut form of ¤{type≔Y·Z}
# ¦X is a shortcut form of display≔X
# display defaults to an empty string

# within a mark, key/value pairs are separated by ·
#   and the key is separated from the value by ≔

# keys may have any characters,
# but some may require a COMBINING GRAPHEME JOINER or embedding within a literal mark ( ¦{} ) to include

# valid mark forms:
#   X{Y≔Z} = ¤{type≔W·Y≔Z}
#   X{Y≔Z¦ABC} = ¤{type≔W·Y≔Z·display≔ABC}
#   X{¦ABC} = ¤{type≔W·display≔ABC}
#   X{} = ¤{type≔W}

# the hash for local-data contains, at minimum:
#   type => 'name for type of mark'
#   display => list-of-mixed-literals-and-marks

# with regard to submarks,
#   submarks return their local-data and their nonlocal-data to the containing mark
#   that containing mark can do whatever it wants with the data so obtained
#       note that a submark's contributions to nonlocal-data are only realized if the containing mark includes them in its own nonlocal-data contributions (with or without modifications)
#       thus a no-op mark isn't quite a complete no-op, as all of the contained marks (if any) will be fully evaluated, but all of their data will be thrown away before it has a chance to
#           modify any metadata cache
#           does this apply to ¤{type=define} ?
#               because I was going to have these marks directly (and permanently) modify the grammar...
#               perhaps ideally this would be scoped...

# regarding marks that define additional marks
#   ( whether from whole cloth or simply currying key/value pairs for an existing mark )
#   this implies one, or maybe two, additional sections besides local-data and nonlocal-data
#       first would be for marks defined on the fly for local use
#       second would be marks defined for export
#           This implies ¤{type=import}, which would allow the definition of multiple indicies to be centralized for use throughout a project

use Grammar::Tracer;

# the exclusive use of tokens is deliberate, as it prevents backtracking and
# special treatment of whitespace (which I want to be preserved in most places
# as significant)
grammar Indexed-Text {
    token TOP { <indexed-text> };
    token indexed-text {
        <unmarked-text> <indexed-text> |
        <index-mark> <indexed-text> |
        <empty>
    };
    token empty { ^$ };
    token unmarked-text {
        <[ \x00 .. \x7f ] +:WSpace +:C +:Z>+ |
        ?
    };
    token index-mark { ? };
};

=finish

grammar Indexed-Text {
    token TOP {
        <outside-text-or-index-mark>*
    };

    token outside-text-or-index-mark { <outside-text> | <index-mark> };

    # if outside-text can contain things that mark-display or mark-data-value can't,
    # then you can't just blindly enclose some block of text in ¤{...¦block of text}
    # or ¤{...·dislay≔block of text·...} without first going through and doing some
    # sanitizing on it.
    #   this is undesirable
    #   + e.g. the text "abc}" would cause problems due to ending the new mark
    #   + I /could/ make it an error to use an unescaped }, but it isn't an error
    #     to use an unescaped { as long as it isn't preceeded by a mark leader,
    #     so this introduces a mismatch where it's easier to use the opening glyph
    #     than it is the closing glyph.
    # + I want the natural use of any glyph to mean its natural appearance
    # + I need the special use of selected glyphs for marks to be easy
    token outside-text {
        <[ \x00 .. \x7f ] +:WSpace +:C +:Z>+ |
        . <!before '{'> |
        . $
    };

    # this is an effort to unmagic the plain '}'
    # ZWJ isn't strictly necessary, but has been included as a means of making marks very difficult to form accidentally
    # ZWJ sounds like a good fit for this, but may not work in practice
    #token index-mark { (<index-mark-leader>) "\c[ZERO WIDTH JOINER]" '{' <mark-body> '}' "\c[ZERO WIDTH JOINER]" $0 };

    token index-mark { <index-mark-leader> '{' ~ '}' <mark-body> };

    token index-mark-leader { <-[ \x00 .. \x7f ] -:WSpace -:C -:Z> };

    token mark-body { <mark-data>? [ '¦' <mark-display> ]? };

    token mark-data { <mark-kv-pair>* %% '·' };

    token mark-kv-pair { <mark-data-key> '≔' <mark-data-value> };

    # can't contain ≔ (ends key)
    # can't contain } (ends mark, with error?)
    # can't contain ¦ (ends data section, with error?)
    # can't contain · (automatic error?  or null value?)
    token mark-data-key { ... };

    # can't contain } (ends mark)
    # can't contain ¦ (ends data section)
    # can't contain · (ends value)
    # can contain submarks
    token mark-data-value { ... };

    # can't contain } (ends mark)
    # can contain submarks
    # if can contain ¦ or · then is not completely equivalent to display≔
    #   further, then if there is ever a mark with no/ignorable side-effects that
    #   also passes along its display up as text to the enclosing mark (or body)
    #   then if can contain ¦ or · then that mark can be used as a 'character entity'
    #   (ala *ML).  Note that this remains an option even if it isn't necessary.
    token mark-display { ... };
}

class Gather-Marks {
    method index-mark-leader         ($/) { make ~$/                                                 };
    method mark-data                 ($/) { make $/<mark-kv-pair>».made;                             };
    method mark-kv-pair              ($/) { make $/<mark-data-key>.made => $/<mark-data-value>.made; };
    method mark-data-key             ($/) { make ~$/;                                                };
    method inside-text               ($/) { make ~$/;                                                };
    method mark-text                 ($/) { make ~$/;                                                };
    method mark-data-value           ($/) { make [~] $/<inside-text-or-index-mark>».made;            };
    method inside-text-or-index-mark ($/) { make $/.hash.values[0].made;                             };
    method mark-display              ($/) { make $/<mark-data-value>.made;                           };

    method TOP ($/) { say "TOP {$/.perl}"; make [ $/<outside-text-or-index-mark>».made ]; };
    method outside-text-or-index-mark ($/) { say "outside-text-or-index-mark {$/.perl}"; make $/.hash.values[0].made; };
    method outside-text ($/) { say "outside-text {$/.perl}"; make ~$/ };

    method index-mark ($/) {
        say "index-mark {$/.perl}";
    };

    method mark-body ($/) {
        my %mark-data;
        if $/<mark-data>:exists {
            %mark-data = $/<mark-data>.made;
        }
        if $/<mark-display>:exists {
            %mark-data<display> = $/<mark-display>.made;
        }
        make %mark-data;
    };
}

my @t = (
    'abc',
    'def{g¤hi',
    '¤{type≔test}',
    '∅{¦a}',
    '∃{type≔mu·data≔something}',
    '※{key≔value¦b}',
);

for @t -> $t {
    my $actions = Gather-Marks.new;
    if Indexed-Text.parse( $t, :$actions ) {
        say "{$t.perl} matches: {$/.perl}";
    }
    else {
        say "{$t.perl} doesn't match";
    }
}

=finish

grammar Indexed-Text {
    token index-mark { <index-mark-leader> '{' <mark-body> '}' };

    proto token index-mark-leader {*};
          token index-mark-leader:mark<undefined> { <-[ \x00 .. \x7f ] -:WSpace -:C -:Z> { fail "Attempted use of an undefined index-mark: $/" } };
          token index-mark-leader:mark<no-op> { '∅' };
          token index-mark-leader:mark<literal> { '¦' };

    token mark-body {
        <mark-data> '¦' <mark-display> |
        <mark-data-and-display>
    };

    rule mark-data { <mark-kv-pair>* %% ',' };

    rule mark-kv-pair { <mark-data-key> '≔' <mark-data-value> };

    token mark-data-key { <text>+ };

    token mark-data-value { <text>* [ <index-mark> { fail "" unless $/<index-mark>.ast.WHAT === Str } <text>* ]* };

    token mark-display { <mark-data-value> };

    token mark-data-and-display { <mark-display> };
}

class GatherMarks {
    #method TOP ($/) { * };

    method text { make ~$/ };

    #method index-mark ($/) { * };

    #method index-mark-leader:mark<section> ($/) { * };
    method index-mark ($/) { make $/<index-mark-leader>.ast( $/<mark-body>.ast ) };

    method index-mark-leader:mark<no-op> ($/) { make sub { '' } };

    method mark-body ($/) {};

    method mark-data-value ($/) { make [~] $/.list.map( { |$^a // $^a } ) };

    method mark-display ($/) { make 'display' => $/<mark-data-value> };

    method mark-data-and-display { make $/<mark-display>.ast };
}

