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
        if $first-mismatch == $.str.chars {
            # We are a prefix of the other string or we are the same strings
            if $first-mismatch == $other.str.chars {
                return MatcherNode::String.new(str => $.str, descendants => $.descendants.append($other.descendants), terminals => $.terminals.append($other.terminals));
            } else {
                my $descendant = MatcherNode::String.new(str => $other.str.substr($first-mismatch), descendants => $other.descendants, terminals => $other.terminals);
                return MatcherNode::String.new(str => $.str, descendants => $.descendants.append($descendant), terminals => $.terminals);
            }
        } elsif $first-mismatch == $other.str.chars {
            # They are a prefix of our string
            my $descendant = MatcherNode::String.new(str => $.str.substr($first-mismatch), descendants => $.descendants, terminals => $.terminals);
            return MatcherNode::String.new(str => $other.str, descendants => $other.descendants.append($descendant), terminals => $other.terminals);
        } else {
            my $self-new = MatcherNode::String.new(str => $.str.substr($first-mismatch), descendants => $.descendants, terminals => $.terminals);
            my $other-new = MatcherNode::String.new(str => $other.str.substr($first-mismatch), descendants => $other.descendants, terminals => $other.terminals);
            return MatcherNode::String.new(str => $.str.substr(0, $first-mismatch), descendants => [$self-new, $other-new], terminals => []);
        }
    }
}

class MatcherNode::CharacterRange {
}

class MatcherNode::Any {
    method is-match($str) {
        if ($.descendants) {
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

my $matcher = MatcherNode::String.new(str => '/foo/bar/', descendants => [
    MatcherNode::String.new(str => 'baz.txt', terminals => ['baz.txt']),
    MatcherNode::String.new(str => 'baz.cpp', terminals => ['baz.cpp'])
]);

for gather $matcher.match('/foo/bar/baz.txt') -> $m {
    say $m.perl;
}
