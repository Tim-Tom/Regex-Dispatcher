use v6;

role MatcherNode::Base {
    has @.descendants;
    has @.terminals;
    method is-match(Str:D $str) returns Str { ... }
    method can-merge(MatcherNode::Base:D $other) returns Bool { ... }
    method merge(MatcherNode::Base:D $other) returns MatcherNode::Base { ... }
    method match(Str:D $str) {
        my $match = $.is-match($str);
        if ($match.defined) {
            if ($match.chars == 0) {
                .take for @.terminals;
            } else {
                @.descendants.map(*.match($match)).flat();
            }
        }
    }
    method debug-print(Str $indent) { ... }
}

class MatcherNode::String does MatcherNode::Base {
    has Str $.str;
    method is-match($str) {
        if ($str.starts-with($.str)) {
            return $str.substr($.str.chars);
        } else {
            return Str;
        }
    }
    method can-merge($other) {
        return False unless $other ~~ MatcherNode::String;
        return $.str.substr(0, 1) eq $other.str.substr(0, 1);
    }
    method merge($other) {
        my $first-mismatch = ($.str.comb Zeq $other.str.comb).pairs.first(not *.value).key;
        if $first-mismatch.defined {
            # If first-mismatch is defined, that means there was a mismatch somewhere in
            # the strings and so we should make a new node and point it to the remaining
            # part of each string.
            say "Case 1";
            my $self-new = MatcherNode::String.new(str => $.str.substr($first-mismatch), descendants => $.descendants.flat, terminals => $.terminals.flat);
            my $other-new = MatcherNode::String.new(str => $other.str.substr($first-mismatch), descendants => $other.descendants.flat, terminals => $other.terminals.flat);
            return MatcherNode::String.new(str => $.str.substr(0, $first-mismatch), descendants => [$self-new, $other-new], terminals => []);
        } elsif $.str.chars == $other.str.chars {
            # Both strings are the same, so we should combine the two nodes into one master
            # node. This is essentially a degenerate case. TODO: This probably needs to merge descendants.
            say "Case 2";
            return MatcherNode::String.new(str => $.str, descendants => ($.descendants.flat, $other.descendants.flat).flat, terminals => ($.terminals.flat, $other.terminals.flat).flat);
        } elsif $.str.chars < $other.str.chars {
            # We are a prefix of the other node. Chop the other string at the appropriate place.
            say "Case 3";
            my $descendant = MatcherNode::String.new(str => $other.str.substr($.str.chars), descendants => $other.descendants.flat, terminals => $other.terminals.flat);
            my @descendants = $.descendants.flat;
            my $already-merged = False;
            for @descendants -> $d is rw {
                if $d.can-merge($descendant) {
                    $d = $d.merge($descendant);
                    $already-merged = True;
                    last;
                }
            }
            @descendants.push($descendant) unless $already-merged;
            return MatcherNode::String.new(str => $.str, descendants => @descendants, terminals => $.terminals.flat);
        } else {
            # They are a prefix of our node. Chop our string at the appropriate place.
            say "Case 4";
            my $descendant = MatcherNode::String.new(str => $.str.substr($other.str.chars), descendants => $.descendants.flat, terminals => $.terminals.flat);
            my @descendants = $other.descendants.flat;
            my $already-merged = False;
            for @descendants -> $d is rw {
                if $d.can-merge($descendant) {
                    $d = $d.merge($descendant);
                    $already-merged = True;
                    last;
                }
            }
            @descendants.push($descendant) unless $already-merged;
            return MatcherNode::String.new(str => $other.str, descendants => @descendants, terminals => $other.terminals.flat);
        }
    }
    method debug-print(Str $indent) {
        if @.terminals > 0 {
            say "$indent$.str [$.terminals]";
        } else {
            say "$indent$.str";
        }
        for @.descendants -> $d {
            $d.debug-print($indent ~ ' ' x ($.str.chars - 1) ~ '|');
        }
    }
}

class MatcherNode::CharacterRange {
}

class MatcherNode::Any {
    method is-match($str) {
        if (@.descendants) {
            return $str.substr(1);
        } else {
            return '';
        }
    }
}

class MatcherNode::Except {
    has $.char;
    method is-match($str) {
        return Str if $str.substr(0, 1) eq $.char;
        return $str.substr(1);
    }
}

my $matcher;

for $*IN.lines.kv -> $line-no, $line {
    say "[$line-no]: $line";
    my $new-matcher = MatcherNode::String.new(str => $line, terminals => [$line-no]);
    if $matcher {
        if $matcher.can-merge($new-matcher) {
            $matcher = $matcher.merge($new-matcher);
        } else {
            say qq{Can't merge the strings};
        }
    } else {
        $matcher = $new-matcher;
    }
}

$matcher.debug-print('');
