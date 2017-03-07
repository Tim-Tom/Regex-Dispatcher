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

sub merge-descendants(@l, @r) {
    my @descendants;
    if @l == 0 {
        @descendants = @r;
    } elsif @r == 0 {
        @descendants = @l
    } else {
        my @picked = @r.map({ False });
        for @l -> $l {
            my $picked = False;
            for @r.kv -> $i, $r {
                next if @picked[$i];
                if $l.can-merge($r) {
                    @descendants.push($l.merge($r));
                    $picked = @picked[$i] = True;
                    last;
                }
            }
            @descendants.push($l) unless $picked;
        }
        for @r.kv -> $i, $r {
            @descendants.push($r) unless @picked[$i];
        }
    }
    return @descendants;
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
            my $self-new = MatcherNode::String.new(str => $.str.substr($first-mismatch), descendants => $.descendants.flat, terminals => $.terminals.flat);
            my $other-new = MatcherNode::String.new(str => $other.str.substr($first-mismatch), descendants => $other.descendants.flat, terminals => $other.terminals.flat);
            return MatcherNode::String.new(str => $.str.substr(0, $first-mismatch), descendants => [$self-new, $other-new], terminals => []);
        } elsif $.str.chars == $other.str.chars {
            # Both strings are the same, so we should combine the two nodes into one
            # master node. This is essentially a degenerate case. TODO: This probably
            # needs to merge descendants, but since one of the descendant lists is
            # currently always empty, that's not really neccesary.
            return MatcherNode::String.new(str => $.str, descendants => merge-descendants(@.descendants, @($other.descendants)), terminals => ($.terminals.flat, $other.terminals.flat).flat);
        } elsif $.str.chars < $other.str.chars {
            # We are a prefix of the other node. Chop the other string at the appropriate place.
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

class MatcherNode::Any does MatcherNode::Base {
    method is-match($str) {
        return $str.substr(1);
    }
    method can-merge($other) {
        return $other ~~ MatcherNode::Any;
    }
    method merge($other) {
        return MatcherNode::Any.new(descendants => merge-descendants($.descendants.flat, $other.descendants.flat).flat, terminals => ($.terminals.flat, $other.terminals.flat).flat);
    }
    method debug-print(Str $indent) {
        if @.terminals > 0 {
            say "$indent\{*} [$.terminals]";
        } else {
            say "$indent\{*}";
        }
        for @.descendants -> $d {
            $d.debug-print($indent ~ '  |');
        }
    }
}

class MatcherNode::Except does MatcherNode::Base {
    has $.char;
    method is-match($str) {
        return Str if $str.substr(0, 1) eq $.char;
        return $str.substr(1);
    }
    method can-merge($other) {
        return False unless $other ~~ MatcherNode::Except;
        return $.char eq $other.char;
    }
    method merge($other) {
        # TODO: This probably needs to merge descendants, but since one of the descendant
        # lists is currently always empty, that's not really neccesary.
        if $.descendants.elems > 0 && $other.descendants.elems > 0 {
            die "We don't handle this case properly.";
        }
        return MatcherNode::Except.new(char => $.char, descendants => ($.descendants.flat, $other.descendants.flat).flat, terminals => ($.terminals.flat, $other.terminals.flat).flat);
    }
    method debug-print(Str $indent) {
        if @.terminals > 0 {
            say "$indent\{^$.char} [$.terminals]";
        } else {
            say "$indent\{^$.char}";
        }
        for @.descendants -> $d {
            $d.debug-print($indent ~ '   |');
        }        
    }
}

class MatcherNode::Root does MatcherNode::Base {
    method is-match($str) {
        return $str;
    }
    method can-merge($other) {
        die 'Unsupported';
    }
    method merge($self: $other) {
        my $already-merged = False;
        for @.descendants -> $d is rw {
            if $d.can-merge($other) {
                $d = $d.merge($other);
                $already-merged = True;
                last;
            }
        }
        @.descendants.push($other) unless $already-merged;
        return $self;
    }
    method debug-print(Str $indent) {
        for @.descendants -> $d {
            $d.debug-print($indent);
        }
    }
}

my $matcher = MatcherNode::Root.new;

for $*IN.lines.kv -> $line-no, $line {
    say "[$line-no]: $line";
    my $new-matcher = MatcherNode::String.new(str => $line, terminals => [$line-no]);
    $matcher = $matcher.merge($new-matcher);
}

$matcher.merge(MatcherNode::String.new(str => '/foo', descendants => [MatcherNode::Any.new(descendants => [MatcherNode::String.new(str => 'bar/baz.txt', terminals => ['first'])])]));
$matcher.merge(MatcherNode::String.new(str => '/foo', descendants => [MatcherNode::Except.new(char => '/', descendants => [MatcherNode::String.new(str => 'bar/baz.txt', terminals => ['second'])])]));

$matcher.debug-print('');

say '---';
.say for gather $matcher.match('/foo/bar/baz.txt');

say '===';
.say for gather $matcher.match('/foo_bar/baz.txt');
