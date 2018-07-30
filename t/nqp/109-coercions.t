plan(18);

my sub isnan($n) {
    nqp::isnanorinf($n) && nqp::isne_n($n, nqp::inf()) && nqp::isne_n($n, nqp::neginf());
}

ok(isnan(nqp::numify('NaN')), 'numifying NaN');
ok(nqp::iseq_n(nqp::numify('Inf'), nqp::inf), 'numifying Inf');
ok(nqp::iseq_n(nqp::numify('+Inf'), nqp::inf), 'numifying +Inf');
ok(nqp::iseq_n(nqp::numify('-Inf'), nqp::neginf), 'numifying -Inf');
ok(nqp::iseq_n(nqp::numify('3.14159_26535'), 3.1415926535), 'numifying works with underscores');
ok(nqp::iseq_n(nqp::numify('−123e0'), -123), 'numifying works with unicode minus U+2212');
is(~100, '100', 'stringifing 100');
is(~100.0, '100', 'stringifing 100');
ok(~3.14 == 3.14, 'stringifing 3.14');
ok(~3.1 == 3.1, 'stringifing 3.1');
ok(~3.0 == 3, 'stringifing 3.0');
ok(~0.0 == 0.0, 'stringifing 0.0');
is(~nqp::nan(), 'NaN', 'stringifing nqp::nan');
is(~nqp::inf(), 'Inf', 'stringifing nqp::inf');
is(~nqp::neginf(), '-Inf', 'stringifing nqp::neginf');

is(~(nqp::div_n(1, nqp::neginf())), '-0', 'stringifing -0');
is(~(nqp::div_n(1, nqp::inf())), '0', 'stringifing 0');

if nqp::getcomp('nqp').backend.name eq 'jvm' {
    skip('num to str conversion still needs to be standardized on the jvm backend', 1);
} else {
  is(~1.01e100, '1.01e+100', 'stringifing 1.01e100');
}
