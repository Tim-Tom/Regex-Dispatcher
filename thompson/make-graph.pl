use strict;
use warnings;

print "digraph G {\n";
print "  rankdir=LR;";
print "  node [shape = square] nil;\n";
my %states;
my $state_count;

$states{'(nil)'} = 'nil';

sub ms {
  $states{$_[0]} //= 'S' . ++$state_count;
}

my $transitions = '';

while(<STDIN>) {
  last if /---/;
  /^\[([^:]+): ([a-zA-Z]) (\S+)(?: (\S+))?\]$/ or die;
  my $state = ms $1;
  if ($2 eq 'M') {
    my ($o1, $o2) = map { ms $_ } ($3, $4);
    print "  node [shape = doublecircle] $state;\n";
    $transitions .= "  $state -> { $o1, $o2 };\n";
  } elsif ($2 eq 'S') {
    my ($o1, $o2) = map { ms $_ } ($3, $4);
    print "  node [shape = diamond] $state;\n";
    $transitions .= "  $state -> { $o1, $o2 };\n";
  } else {
    my $out = ms $3;
    print "  node [shape = circle] $state;\n";
    $transitions .= "  $state -> $out [ label = \"$2\" ];\n";
  }
}

print $transitions;

print "}\n";
