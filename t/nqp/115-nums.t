plan(14 + 3*300);

# Precision and value drift tests for floating point numerics

sub is ($got, $expected, $desc = "$got is exactly equal to $expected") {
    ok(?(my $test := nqp::iseq_n($got, $expected)), $desc);
    unless $test {
        say("# got:      $got");
        say("# expected: $expected");
    }
    ?$test
}

sub isn't ($got, $expected, $desc = "$got is NOT equal to $expected") {
    ok(?(my $test := nqp::isne_n($got, $expected)), $desc);
    unless $test {
        say("# got value: $got");
        say("# had value: $expected");
    }
    ?$test
}

##############################################################

isn't(5e-324, 0e0,    'denormal 5e-324 is recognized and is not 0');
is(   6e-324, 5e-324, '6e-324 denormal equates to 5e-324 denormal');
is(   5e-324, 5e-324, '5e-324 denormal equates to 5e-324 denormal');
is(   3e-324, 5e-324, '2e-324 denormal equates to 5e-324 denormal');
is(   2e-324, 0e0,    '2e-324 denormal is 0e0');
is(   9e-324, 1e-323, '9e-324 denormal is 1e-323');


# U+0CE6 KANNADA DIGIT ZERO [Nd] (೦)
# U+0CE7 KANNADA DIGIT ONE [Nd] (೧)
# U+0CE8 KANNADA DIGIT TWO [Nd] (೨)
# U+0CE9 KANNADA DIGIT THREE [Nd] (೩)
# U+0CEA KANNADA DIGIT FOUR [Nd] (೪)
# U+0CEB KANNADA DIGIT FIVE [Nd] (೫)
# U+0CEC KANNADA DIGIT SIX [Nd] (೬)
# U+0CED KANNADA DIGIT SEVEN [Nd] (೭)
# U+0CEE KANNADA DIGIT EIGHT [Nd] (೮)
# U+0CEF KANNADA DIGIT NINE [Nd] (೯)

if nqp::getcomp('nqp').backend.name eq 'jvm' {
    skip("JVM doesn't know how to Unicode properly", 6);
}
else {
    isn't(೫e-೩೨೪, ೦e೦,    'denormal 5e-324 is recognized and is not 0 (Uni)');
    is(   ೬e-೩೨೪, ೫e-೩೨೪, '6e-324 denormal equates to 5e-324 denormal (Uni)');
    is(   ೫e-೩೨೪, ೫e-೩೨೪, '5e-324 denormal equates to 5e-324 denormal (Uni)');
    is(   ೩e-೩೨೪, ೫e-೩೨೪, '2e-324 denormal equates to 5e-324 denormal (Uni)');
    is(   ೨e-೩೨೪, ೦e೦,    '2e-324 denormal is 0e0 (Uni)');
    is(   ೯e-೩೨೪, ೧e-೩೨೩, '9e-324 denormal is 1e-323 (Uni)');
}

isn't(1180591620717411303424e0, 1180591620717409992704e0,
    'distinct num literals close to each other are not equal');

is(9.9989999999999991e0, 9.998999999999999e0,
    'nums choose closest available representation');

sub () {
    sub gen-num() {
        my $res := '';
        my int $rounds;
        $res := $res ~ nqp::ceil_n(nqp::rand_n(9.9e0))
            while nqp::rand_n(1e0) > .2e0 && $rounds++ < 30;
        $res := '0' if ! $res;
        $res := $res ~ '.';
        $rounds := 0;
        $res := $res ~ nqp::ceil_n(nqp::rand_n(9.9e0))
            while nqp::rand_n(1e0) > .2e0 && $rounds++ < 30;
        $res := $res ~ '0' if nqp::eqat($res, '.', nqp::chars($res)-1);
        $res := $res ~ 'e';
        $res := $res ~ (nqp::rand_n(1e0) > .5e0
            ??       nqp::ceil_n(nqp::rand_n(100e0))
            !! "-" ~ nqp::ceil_n(nqp::rand_n(100e0)));
        $res := "-$res" if nqp::rand_n(1e0) > .5e0;
        $res;
    }

    my int $i;
    while $i++ < 300 {
        my $n := gen-num();
        is(+$n,     +~+$n, "no drift in str -> num roundtrip `$n` (1 level)");
        is(+$n,   +~+~+$n, "no drift in str -> num roundtrip `$n` (2 levels)");
        is(+$n, +~+~+~+$n, "no drift in str -> num roundtrip `$n` (3 levels)");
    }
}()
