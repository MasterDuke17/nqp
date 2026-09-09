plan(27);

# The character class methods of the cursor have no NFA of their own,
# but each consumes one character of a known class. That character is
# the declarative prefix a branch calling one contributes to longest
# token matching.

my $m := 'n~' ~~ / <alnum> | <alnum> . /;
is(~$m, 'n~', 'a branch calling <alnum> then more beats a branch calling <alnum> alone');

$m := 'n~' ~~ / <alnum> . | <alnum> /;
is(~$m, 'n~', 'the same branch wins when it comes first');

$m := 'n~' ~~ / <.alnum> | <.alnum> . /;
is(~$m, 'n~', 'a non capturing call to <alnum> contributes the same prefix');

$m := 'n~' ~~ / <+alnum> | <+alnum> . /;
is(~$m, 'n~', 'an enumerated character class calling <alnum> contributes the same prefix');

$m := '_~' ~~ / <alnum> | <alnum> . /;
is(~$m, '_~', 'a branch calling <alnum> on an underscore then more beats a branch calling <alnum> alone');

$m := 'n~' ~~ / <+alnum +punct> | <+alnum +punct> . /;
is(~$m, 'n~', 'an enumerated character class combining <alnum> with <punct> contributes the same prefix');

$m := 'nn~' ~~ / <alnum> | <alnum>+ . /;
is(~$m, 'nn~', 'a quantified call to <alnum> then more beats a branch calling <alnum> alone');

$m := '1,' ~~ / <digit> | <digit> . /;
is(~$m, '1,', 'a branch calling <digit> then more beats a branch calling <digit> alone');

$m := 'N,' ~~ / <upper> | <upper> . /;
is(~$m, 'N,', 'a branch calling <upper> then more beats a branch calling <upper> alone');

$m := 'n,' ~~ / <lower> | <lower> . /;
is(~$m, 'n,', 'a branch calling <lower> then more beats a branch calling <lower> alone');

$m := 'f,' ~~ / <xdigit> | <xdigit> . /;
is(~$m, 'f,', 'a branch calling <xdigit> then more beats a branch calling <xdigit> alone');

$m := ' n' ~~ / <space> | <space> . /;
is(~$m, ' n', 'a branch calling <space> then more beats a branch calling <space> alone');

$m := "\nn" ~~ / <space> | <space> . /;
is(~$m, "\nn", 'a branch calling <space> on a newline then more beats a branch calling <space> alone');

$m := ' n' ~~ / <blank> | <blank> . /;
is(~$m, ' n', 'a branch calling <blank> then more beats a branch calling <blank> alone');

$m := 'n~' ~~ / <print> | <print> . /;
is(~$m, 'n~', 'a branch calling <print> then more beats a branch calling <print> alone');

$m := "\x[1]n" ~~ / <cntrl> | <cntrl> . /;
is(~$m, "\x[1]n", 'a branch calling <cntrl> then more beats a branch calling <cntrl> alone');

$m := ',n' ~~ / <punct> | <punct> . /;
is(~$m, ',n', 'a branch calling <punct> then more beats a branch calling <punct> alone');

$m := 'n~' ~~ / <graph> | <graph> . /;
is(~$m, 'n~', 'a branch calling <graph> on a letter then more beats a branch calling <graph> alone');

$m := ',n' ~~ / <graph> | <graph> . /;
is(~$m, ',n', 'a branch calling <graph> on punctuation then more beats a branch calling <graph> alone');

$m := 'a1' ~~ / <alnum> | <digit> . /;
is(~$m, 'a', 'a branch calling <digit> does not claim a letter');

grammar Ratchet {
    token TOP { ^ [ <alnum> | <alnum> .+ ] $ }
}

is(~Ratchet.parse('n~'), 'n~', 'a ratcheting group picks the branch calling <alnum> then more');

grammar Call {
    token N   { <digit> <digit> }
    token TOP { <digit> | <N> }
}

is(~Call.parse('12'), '12', 'a called subrule starting with <digit> contributes its whole prefix');

grammar Override {
    token digit { <[a..z]> }
    token TOP   { a | <digit> b }
}

is(~Override.parse('ab'), 'ab', 'a regex overriding <digit> contributes its own prefix');

grammar EdgelessOverride {
    token digit { {} <[a..z]> }
    token TOP   { a | <digit> b }
}

is(~EdgelessOverride.parse('xb'), 'xb', 'a regex overriding <digit> with no declarative prefix leaves its branch reachable');

grammar MethodOverride {
    method digit() {
        my $cursor := self."!cursor_start_cur"();
        $cursor."!cursor_pass"(self.pos + 1);
        $cursor
    }
    token TOP { a | <digit> b }
}

is(~MethodOverride.parse('1b'), '1b', 'a plain method overriding <digit> is taken to match a digit');
is(~MethodOverride.parse('a'), 'a', 'the other branch still matches next to a plain method override');

grammar Proto {
    proto token TOP {*}
    token TOP:sym<one>  { <alnum> }
    token TOP:sym<more> { <alnum> .+ }
}

is(~Proto.parse('n~'), 'n~', 'a proto token candidate calling <alnum> then more wins');
