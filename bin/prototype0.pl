#!/usr/bin/env perl

# prototype0 goals:
#   main parsing loop
#   identify index marks in input text
#   detect syntactic errors (e.g. due to improper nesting)

# prototype0 anti-goals:
#   do anything meaningful with found index marks (printing them split up is OK)
#   define any index marks, or check them for definedness

# the sturcture prototyped here will be combined with the structure from other
# prototypes to create the first version of the module that handles things

my $STATE_INTEXT = [];
my $STATE_POTENTIAL_MARK = [];
my $STATE_INDATA = [];
my $STATE_INDISPLAY = [];

my $state = $STATE_INTEXT;

my $prev_token = '';
my $text = '';

my @marks;
my $curmark;

while( 1 ) {
    if( $text eq '' ) {
        $text = <DATA>;

        last unless $text;

        # NFC normalize $text
    }

    $text =~ s/^(\X)//;

    my $token = $1;

=comment
    given( $state ) {
        when( $STATE_INTEXT ) {
            if( $token eq '{' ) {
            }
        }
        when( $STATE_INDATA ) {
            if( $token eq '¦' ) {
                $state = $STATE_INDISPLAY;
            }
            else {
                $curmark->{data} .= $token;
            }
        }
        when( $STATE_INDISPLAY ) {
            if( $token eq '}' ) {
                $state = $STATE_INTEXT;
            }
            else {
                push @marks, $curmark;
                undef $curmark;
            }
        }
    }
=cut

    print "$token (unicode values)\n";

    $prev_token = $token;
}


__DATA__
0{a}
∅{b}
∅​{c}
∅{͏d}
0​{e}
