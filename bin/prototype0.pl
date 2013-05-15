#!/usr/bin/env perl

use strict;
use warnings;
use feature qw(:5.16);
use utf8;

# prototype0 goals:
#   main parsing loop
#   identify index marks in input text
#   detect syntactic errors (e.g. due to improper nesting

# prototype0 anti-goals:
#   do anything meaningful with found index marks (printing them split up is OK)
#   define any index marks, or check them for definedness

# the sturcture prototyped here will be combined with the structure from other
# prototypes to create the first version of the module that handles things
