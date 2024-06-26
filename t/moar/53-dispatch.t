# Tests for the MoarVM dispatch mechanism

plan(160);

{
    sub const($x) {
        nqp::dispatch('boot-constant', $x)
    }

    ok(const(1) == 1, 'boot-constant on first call passes through the value');
    ok(const(2) == 1, 'boot-constant fixates the value');
}

{
    sub value($x) {
        nqp::dispatch('boot-value', $x)
    }

    ok(value(1) == 1, 'boot-value passes through value');
    ok(value(2) == 2, 'boot-value does not fixate value');
}

{
    sub code-constant($code) {
        nqp::dispatch('boot-code-constant', $code, 2, 3);
    }
    ok(code-constant(-> $x, $y { $x + $y }) == 5, 'boot-code-constant invokes bytecode with args');
    ok(code-constant(-> $x, $y { $x * $y }) == 5, 'boot-code-constant fixates the callee');
}

{
    sub code($code) {
        nqp::dispatch('boot-code', $code, 2, 3);
    }
    ok(code(-> $x, $y { $x + $y }) == 5, 'boot-code invokes bytecode with args');
    ok(code(-> $x, $y { $x * $y }) == 6, 'boot-code does not fixate the callee');
}

{
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'identity', -> $capture {
        nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-value', $capture);
    });
    ok(nqp::dispatch('identity', 42) == 42, 'Can define identity dispatch (1)');
    ok(nqp::dispatch('identity', 'foo') eq 'foo', 'Can define identity dispatch (2)');
    ok(nqp::dispatch('identity', 3.14) == 3.14, 'Can define identity dispatch (3)');
    ok(nqp::eqaddr(nqp::dispatch('identity', NQPMu), NQPMu), 'Can define identity dispatch (4)');

    nqp::dispatch('boot-syscall', 'dispatcher-register', 'wrap-identity', -> $capture {
        nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'identity', $capture);
    });
    ok(nqp::dispatch('wrap-identity', 101) == 101,
        'Chains of userspace dispatcher delegations work (1 deep)');

    nqp::dispatch('boot-syscall', 'dispatcher-register', 'wrap-wrap-identity', -> $capture {
        nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'wrap-identity', $capture);
    });
    ok(nqp::dispatch('wrap-wrap-identity', 666) == 666,
        'Chains of userspace dispatcher delegations work (2 deep)');
}

{
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'drop-first', -> $capture {
        my $capture-derived := nqp::dispatch('boot-syscall', 'dispatcher-drop-arg', $capture, 0);
        nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-value', $capture-derived);
    });
    ok(nqp::dispatch('drop-first', 'first', 'second') eq 'second',
        'dispatcher-drop-arg works');

    nqp::dispatch('boot-syscall', 'dispatcher-register', 'drop-first-two', -> $capture {
        my $capture-da := nqp::dispatch('boot-syscall', 'dispatcher-drop-arg', $capture, 0);
        my $capture-db := nqp::dispatch('boot-syscall', 'dispatcher-drop-arg', $capture-da, 0);
        nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-value', $capture-db);
    });
    ok(nqp::dispatch('drop-first-two', 'first', 'second', 'third', 'fourth') eq 'third',
        'Multiple applications of dispatcher-drop-arg work');
}

{
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'drop-first-two', -> $capture {
        my $capture-derived := nqp::dispatch('boot-syscall', 'dispatcher-drop-n-args', $capture, 0, 2);
        nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-value', $capture-derived);
    });
    ok(nqp::dispatch('drop-first-two', 'first', 'second', 'third') eq 'third',
        'dispatcher-drop-n-args works');

    nqp::dispatch('boot-syscall', 'dispatcher-register', 'drop-first-three', -> $capture {
        my $capture-derived := nqp::dispatch('boot-syscall', 'dispatcher-drop-n-args', $capture, 0, 3);
        nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-value', $capture-derived);
    });
    ok(nqp::dispatch('drop-first-three', 'first', 'second', 'third', 'fourth', 'fifth') eq 'fourth',
        'dropping three arguments works');
}

{
    my $target := -> $x { $x + 1 }
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'call-on-target', -> $capture {
        my $capture-derived := nqp::dispatch('boot-syscall',
                'dispatcher-insert-arg-literal-obj', $capture, 0, $target);
        nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                'boot-code-constant', $capture-derived);
    });
    sub cot() { nqp::dispatch('call-on-target', 49) }
    ok(cot() == 50,
        'dispatcher-insert-arg-literal-obj works at start of capture');
    ok(cot() == 50,
        'dispatcher-insert-arg-literal-obj works at start of capture after link too');
}

{
    my $target := -> $x, $y { $x ~ $y }
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'insert-world', -> $capture {
        my $capture-derived := nqp::dispatch('boot-syscall',
                'dispatcher-insert-arg-literal-str', $capture, 2, 'world');
        nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                'boot-code-constant', $capture-derived);
    });
    sub insert() { nqp::dispatch('insert-world', $target, 'hello ') }
    ok(insert() eq 'hello world',
        'dispatcher-insert-arg-literal-str works at end of capture');
    ok(insert() eq 'hello world',
        'dispatcher-insert-arg-literal-str works at end of capture after link too');
}

{
    my $target := -> $x, $y { $x + $y }
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'insert-answer', -> $capture {
        my $capture-derived := nqp::dispatch('boot-syscall',
                'dispatcher-insert-arg-literal-int', $capture, 2, 42);
        nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                'boot-code-constant', $capture-derived);
    });
    sub insert() { nqp::dispatch('insert-answer', $target, 58) }
    ok(insert() == 100,
        'dispatcher-insert-arg-literal-int works at end of capture');
    ok(insert() == 100,
        'dispatcher-insert-arg-literal-int works at end of capture after link too');
}

{
    my $adder := -> $x, $y { $x * $y }
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'dupe-arg', -> $capture {
        my $first-arg := nqp::dispatch('boot-syscall',
                'dispatcher-track-arg', $capture, 1);
        my $capture-derived := nqp::dispatch('boot-syscall',
                'dispatcher-insert-arg', $capture, 2, $first-arg);
        nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                'boot-code-constant', $capture-derived);
    });
    sub dupe() { nqp::dispatch('dupe-arg', $adder, 3) }
    ok(dupe() == 9, 'Can duplicate an argument');
    ok(dupe() == 9, 'Argument duplicating works after link too');
}

{
    my class C1 { }
    my class C2 { }
    my class C3 { }
    my $count := 0;
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'type-name', -> $capture {
        $count++;
        my $arg := nqp::dispatch('boot-syscall', 'dispatcher-track-arg', $capture, 0);
        my $arg-val := nqp::captureposarg($capture, 0);
        my str $name := $arg-val.HOW.name($arg-val);
        nqp::dispatch('boot-syscall', 'dispatcher-guard-type', $arg);
        nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-constant',
            nqp::dispatch('boot-syscall', 'dispatcher-insert-arg-literal-str',
                nqp::dispatch('boot-syscall', 'dispatcher-drop-arg', $capture, 0),
                0, $name));
    });
    sub type-name($obj) {
        nqp::dispatch('type-name', $obj)
    }

    ok(type-name(C1) eq 'C1', 'Dispatcher setting guard works');
    ok($count == 1, 'Dispatch callback ran once');
    ok(type-name(C1) eq 'C1', 'Can use it another time with the same type');
    ok($count == 1, 'Dispatch callback was not run again');

    ok(type-name(C2) eq 'C2', 'Can handle polymorphic sites when guard fails');
    ok($count == 2, 'Dispatch callback ran a second time for new type');
    ok(type-name(C2) eq 'C2', 'Second call with new type works');
    ok(type-name(C1) eq 'C1', 'Call with original type still works');
    ok($count == 2, 'Dispatch callback only ran a total of 2 times');

    ok(type-name(C3) eq 'C3', 'Can handle a third level of polymorphism');
    ok($count == 3, 'Dispatch callback ran a third time for new type');
    ok(type-name(C1) eq 'C1', 'Works with first type');
    ok(type-name(C2) eq 'C2', 'Works with second type');
    ok(type-name(C3) eq 'C3', 'Works with third type');
    ok($count == 3, 'There were no further dispatch callback invocations');
}

{
    my class C1 { }
    my class C2 { }
    my $count := 0;
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'conc', -> $capture {
        $count++;
        my $arg := nqp::dispatch('boot-syscall', 'dispatcher-track-arg', $capture, 0);
        my $arg-val := nqp::captureposarg($capture, 0);
        my str $result := nqp::isconcrete($arg-val) ?? 'conc' !! 'type';
        nqp::dispatch('boot-syscall', 'dispatcher-guard-concreteness', $arg);
        nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-constant',
            nqp::dispatch('boot-syscall', 'dispatcher-insert-arg-literal-str',
                nqp::dispatch('boot-syscall', 'dispatcher-drop-arg', $capture, 0),
                0, $result));
    });
    sub conc($obj) {
        nqp::dispatch('conc', $obj)
    }

    ok(conc(C1) eq 'type', 'Concreteness guard test dispatcher works on type object');
    ok(conc(C1.new) eq 'conc', 'Concreteness guard test dispatcher works on instance');
    ok($count == 2, 'Ran once for each concreteness');
    ok(conc(C1) eq 'type', 'Repeated test works on type object');
    ok(conc(C1.new) eq 'conc', 'Repeated test works on instance');
    ok(conc(C2) eq 'type', 'Repeated test works on a different type object');
    ok(conc(C2.new) eq 'conc', 'Repeated test works on different instance');
    ok($count == 2, 'Was really only guarding concreteness');
}

{
    my class C { has $!foo; method foo() { $!foo } }
    my $count := 0;
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'literal', -> $capture {
        $count++;
        my $arg := nqp::dispatch('boot-syscall', 'dispatcher-track-arg', $capture, 0);
        my $arg-val := nqp::captureposarg($capture, 0);
        nqp::dispatch('boot-syscall', 'dispatcher-guard-literal', $arg);
        nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-constant',
            nqp::dispatch('boot-syscall', 'dispatcher-insert-arg-literal-obj',
                nqp::dispatch('boot-syscall', 'dispatcher-drop-arg', $capture, 0),
                0, $arg-val.foo));
    });
    sub literal($obj) {
        nqp::dispatch('literal', $obj)
    }

    my $i1 := C.new(foo => 'bar');
    my $i2 := C.new(foo => 'baz');
    ok(literal($i1) eq 'bar', 'Literal guard test dispatcher works on instance 1');
    ok(literal($i2) eq 'baz', 'Literal guard test dispatcher works on instance 2');
    ok($count == 2, 'Ran once for each literal');
    ok(literal($i1) eq 'bar', 'Repeated literal guard test dispatcher works on instance 1');
    ok(literal($i2) eq 'baz', 'Repeated literal guard test dispatcher works on instance 2');
    ok($count == 2, 'Guards match with same literal');
}

{
    my class Nil { }
    my class C { }
    my class D { }
    my $count := 0;
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'nil-check', -> $capture {
        $count++;
        my $arg := nqp::dispatch('boot-syscall', 'dispatcher-track-arg', $capture, 0);
        my $arg-val := nqp::captureposarg($capture, 0);
        my $is-nil := nqp::istype($arg-val, Nil);
        if $is-nil {
            nqp::dispatch('boot-syscall', 'dispatcher-guard-literal', $arg);
        }
        else {
            nqp::dispatch('boot-syscall', 'dispatcher-guard-not-literal-obj', $arg, Nil);
        }
        nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-constant',
            nqp::dispatch('boot-syscall', 'dispatcher-insert-arg-literal-str',
                nqp::dispatch('boot-syscall', 'dispatcher-drop-arg', $capture, 0),
                0, $is-nil ?? 'nil' !! 'not nil'));
    });
    sub nil-check($obj) {
        nqp::dispatch('nil-check', $obj)
    }

    ok(nil-check(C) eq 'not nil', 'Can add not literal guard');
    ok(nil-check(C.new) eq 'not nil', 'Dispatch that is not that literal works');
    ok(nil-check(D.new) eq 'not nil', 'Dispatch on other type works');
    ok($count == 1, 'Ran dispatch only once since unwanted literal never passed');
    ok(nil-check(Nil) eq 'nil', 'Passing unwanted literal does not meet guard');
    ok($count == 2, 'Now dispatch was run twice');
    ok(nil-check(C) eq 'not nil', 'Another case without unwanted literal');
    ok(nil-check(Nil) eq 'nil', 'Another case with unwanted literal');
    ok($count == 2, 'No further dispatch runs');
}

{
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'dies', -> $capture {
        nqp::die('my dying dispatcher')
    });
    my $message := '';
    try {
        nqp::dispatch('dies', 42);
        CATCH {
            $message := ~$_;
        }
    }
    ok($message eq 'my dying dispatcher', 'Exceptions thrown in dispatch are passed along');
}

{
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'bad-dupe', -> $capture {
        nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-value', $capture);
        nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-value', $capture);
    });
    my $message := '';
    try {
        nqp::dispatch('bad-dupe', 42);
        CATCH {
            $message := ~$_;
        }
    }
    ok($message ~~ /'dispatcher-delegate'/, 'Decent error on dupe dispatcher-delegate');
}

{
    my class Wrapper {
        has $!value;
    }
    my class Subclass is Wrapper {
    }
    my $count := 0;
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'read-value', -> $capture {
        $count++;
        my $arg := nqp::dispatch('boot-syscall', 'dispatcher-track-arg', $capture, 0);
        my $value := nqp::dispatch('boot-syscall', 'dispatcher-track-attr', $arg,
            Wrapper, '$!value');
        nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-value',
            nqp::dispatch('boot-syscall', 'dispatcher-insert-arg',
                nqp::dispatch('boot-syscall', 'dispatcher-drop-arg', $capture, 0),
                0, $value));
    });
    sub rv($obj) {
        nqp::dispatch('read-value', $obj)
    }
    ok(rv(Wrapper.new(value => 42)) == 42, 'Tracked attribute used as result works');
    ok(rv(Wrapper.new(value => 43)) == 43, 'Follow-up call does not fixate attribute read');
    ok($count == 1, 'Dispatch callback only invoked once');
    ok(rv(Subclass.new(value => 44)) == 44, 'On a subclass it also works');
    ok($count == 2, 'However, on a subclass implied guards are not met');
}

{
    my $target := -> $arg { nqp::dispatch('boot-resume', 'res-arg')  }
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'basic-resumable',
        # Dispatch
        -> $capture {
            nqp::dispatch('boot-syscall', 'dispatcher-set-resume-init-args', $capture);
            my $capture-derived := nqp::dispatch('boot-syscall',
                    'dispatcher-insert-arg-literal-obj', $capture, 0, $target);
            nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                    'boot-code-constant', $capture-derived);
        },
        # Resume
        -> $capture {
            nqp::die('In resume with arg ' ~ nqp::captureposarg_s($capture, 0));
        });
    my $message := '';
    try {
        nqp::dispatch('basic-resumable', 42);
        CATCH {
            $message := ~$_;
        }
    }
    ok($message ~~ /'In resume with arg'/, 'With boot-resume we make it into resume callback');
    ok($message ~~ /'res-arg'/, 'Resume callback gets expected argument');
}

{
    my $target-a := -> { nqp::dispatch('boot-resume') }
    my $target-b := -> { 'reached'  }
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'resumable-really-calls',
        # Dispatch
        -> $capture {
            nqp::dispatch('boot-syscall', 'dispatcher-set-resume-init-args', $capture);
            my $capture-derived := nqp::dispatch('boot-syscall',
                    'dispatcher-insert-arg-literal-obj', $capture, 0, $target-a);
            nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                    'boot-code-constant', $capture-derived);
        },
        # Resume
        -> $capture {
            my $capture-derived := nqp::dispatch('boot-syscall',
                    'dispatcher-insert-arg-literal-obj', $capture, 0, $target-b);
            nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                    'boot-code-constant', $capture-derived);
        });
    ok(nqp::dispatch('resumable-really-calls') eq 'reached',
        'resume callback can successfully provide code to run');
}

{
    my $target-a := -> $arg { 'x' ~ nqp::dispatch('boot-resume')  }
    my $target-b := -> $arg { 'y' ~ $arg }
    my int $disp-count;
    my int $res-count;
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'resumable-using-init-args',
        # Dispatch
        -> $capture {
            $disp-count++;
            nqp::dispatch('boot-syscall', 'dispatcher-set-resume-init-args', $capture);
            my $capture-derived := nqp::dispatch('boot-syscall',
                    'dispatcher-insert-arg-literal-obj', $capture, 0, $target-a);
            nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                    'boot-code-constant', $capture-derived);
        },
        # Resume
        -> $capture {
            $res-count++;
            my $args := nqp::dispatch('boot-syscall', 'dispatcher-get-resume-init-args');
            my $capture-derived := nqp::dispatch('boot-syscall',
                    'dispatcher-insert-arg-literal-obj', $args, 0, $target-b);
            nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                    'boot-code-constant', $capture-derived);
        });
    sub test-call(str $arg) { nqp::dispatch('resumable-using-init-args', $arg) }

    ok(test-call('z') eq 'xyz', 'Resumption could access init args');
    ok($disp-count == 1, 'In dispatch function once');
    ok($res-count == 1, 'In resume function once');

    ok(test-call('Z') eq 'xyZ', 'Second call works and did not fixate init arg');
    ok($disp-count == 1, 'Still only in dispatch function once');
    ok($res-count == 1, 'Still only in resume function once');
}

{
    my $target-a := -> $arg { 'x' ~ ($arg ?? nqp::dispatch('boot-resume') !! '') }
    my $target-b := -> $arg { 'y' ~ $arg }
    my int $disp-count;
    my int $res-count;
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'resumable-conditionally-resumed',
        # Dispatch
        -> $capture {
            $disp-count++;
            nqp::dispatch('boot-syscall', 'dispatcher-set-resume-init-args', $capture);
            my $capture-derived := nqp::dispatch('boot-syscall',
                    'dispatcher-insert-arg-literal-obj', $capture, 0, $target-a);
            nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                    'boot-code-constant', $capture-derived);
        },
        # Resume
        -> $capture {
            $res-count++;
            my $args := nqp::dispatch('boot-syscall', 'dispatcher-get-resume-init-args');
            my $capture-derived := nqp::dispatch('boot-syscall',
                    'dispatcher-insert-arg-literal-obj', $args, 0, $target-b);
            nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                    'boot-code-constant', $capture-derived);
        });
    sub test-call(str $arg) { nqp::dispatch('resumable-conditionally-resumed', $arg) }

    ok(test-call('') eq 'x', 'Code that conditionally resumes OK on first execution');
    ok($disp-count == 1, 'In dispatch function once');
    ok($res-count == 0, 'Not in resume function yet');

    ok(test-call('w') eq 'xyw', 'First resume taking place in second dispatch works');
    ok($disp-count == 1, 'Still only in dispatch function once');
    ok($res-count == 1, 'Now also in resume function once');

    ok(test-call('v') eq 'xyv', 'Second resume taking place in third dispatch works');
    ok($disp-count == 1, 'Still only in dispatch function once');
    ok($res-count == 1, 'Still only in resume function once');
}

{
    my $target-a := -> $arg { 'a' ~ nqp::dispatch('boot-resume')  }
    my $target-b1 := -> $arg { 'b1' }
    my $target-b2 := -> $arg { 'b2' }
    my class B1 {}
    my class B2 {}
    my int $disp-count;
    my int $res-count;
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'resume-guarding-init-state',
        # Dispatch
        -> $capture {
            $disp-count++;
            nqp::dispatch('boot-syscall', 'dispatcher-set-resume-init-args', $capture);
            my $capture-derived := nqp::dispatch('boot-syscall',
                    'dispatcher-insert-arg-literal-obj', $capture, 0, $target-a);
            nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                    'boot-code-constant', $capture-derived);
        },
        # Resume
        -> $capture {
            # We insert a guard on the type and use it to choose where we will
            # dispatch to, to test guarding on resume init args.
            $res-count++;
            my $args := nqp::dispatch('boot-syscall', 'dispatcher-get-resume-init-args');
            my $arg := nqp::dispatch('boot-syscall', 'dispatcher-track-arg', $args, 0);
            nqp::dispatch('boot-syscall', 'dispatcher-guard-type', $arg);
            my $arg-val := nqp::captureposarg($args, 0);
            my $target := nqp::istype($arg-val, B1) ?? $target-b1 !! $target-b2;
            my $capture-derived := nqp::dispatch('boot-syscall',
                    'dispatcher-insert-arg-literal-obj', $args, 0, $target);
            nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                    'boot-code-constant', $capture-derived);
        });
    sub test-call($arg) { nqp::dispatch('resume-guarding-init-state', $arg) }

    ok(test-call(B1) eq 'ab1', 'Resumption that guards on type works');
    ok($disp-count == 1, 'In dispatch function once');
    ok($res-count == 1, 'In resume function once');

    ok(test-call(B1) eq 'ab1', 'Second call with same type also works');
    ok($disp-count == 1, 'Still only in dispatch function once');
    ok($res-count == 1, 'Still only in resume function once');

    ok(test-call(B2) eq 'ab2', 'Call with different type works');
    ok($disp-count == 1, 'Still only in dispatch function once as it is not type dependent');
    ok($res-count == 2, 'Was in resume function a second time due to type guard miss');

    ok(test-call(B2) eq 'ab2', 'Second call with different type works');
    ok($disp-count == 1, 'Still only in dispatch function once as it is not type dependent');
    ok($res-count == 2, 'Still only Was in resume function twice');

    ok(test-call(B1) eq 'ab1', 'Call using first type again still works');
    ok($disp-count == 1, 'Still only in dispatch function once');
    ok($res-count == 2, 'Still only in resume function twice');
}

# Used for building tests that emulate Raku method deferral, but rather
# simplified
class DeferralChain {
    has $!method;
    has $!next;
    method new($method, $next) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, DeferralChain, '$!method', $method);
        nqp::bindattr($obj, DeferralChain, '$!next', $next);
        $obj
    }
    method method() { $!method }
    method next() { $!next }
};
class Exhausted {};

{
    my class C1 { method m() { 'c1' } }
    my class C2 is C1 { method m() { 'c2' ~ nqp::dispatch('boot-resume') } }
    my class C3 is C2 { method m() { 'c3' ~ nqp::dispatch('boot-resume') } }
    my class C4 is C3 { method m() { 'c4' ~ nqp::dispatch('boot-resume') } }

    my int $disp-count;
    my int $res-count;
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'method-deferral',
        # Dispatch
        -> $capture {
            $disp-count++;
            # We'll resume on the original dispatch arguments.
            nqp::dispatch('boot-syscall', 'dispatcher-set-resume-init-args', $capture);

            # Guard on the method name and invocant type.
            my $name := nqp::dispatch('boot-syscall', 'dispatcher-track-arg', $capture, 0);
            nqp::dispatch('boot-syscall', 'dispatcher-guard-literal', $name);
            my $invocant := nqp::dispatch('boot-syscall', 'dispatcher-track-arg', $capture, 1);
            nqp::dispatch('boot-syscall', 'dispatcher-guard-type', $invocant);

            # Resolve the method.
            my str $name-val := nqp::captureposarg_s($capture, 0);
            my $invocant-val := nqp::captureposarg($capture, 1);
            my $meth := $invocant-val.HOW.find_method($invocant-val, $name-val);
            unless nqp::isconcrete($meth) {
                nqp::die("No such method '$meth'");
            }

            # Drop the name, insert the method, delegate.
            my $without-name := nqp::dispatch('boot-syscall',
                    'dispatcher-drop-arg', $capture, 0);
            my $with-method := nqp::dispatch('boot-syscall',
                    'dispatcher-insert-arg-literal-obj', $without-name, 0,
                    nqp::getattr($meth, NQPRoutine, '$!do'));
            nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                    'boot-code-constant', $with-method);
        },
        # Resume
        -> $capture {
            $res-count++;

            # Check if we have an existing dispatch state.
            my $state := nqp::dispatch('boot-syscall', 'dispatcher-get-resume-state');
            if nqp::isnull($state) {
                # No state, so just starting the resumption. Guard on the
                # invocant type and name.
                my $init := nqp::dispatch('boot-syscall', 'dispatcher-get-resume-init-args');
                my $name := nqp::dispatch('boot-syscall', 'dispatcher-track-arg', $init, 0);
                nqp::dispatch('boot-syscall', 'dispatcher-guard-literal', $name);
                my $invocant := nqp::dispatch('boot-syscall', 'dispatcher-track-arg', $init, 1);
                nqp::dispatch('boot-syscall', 'dispatcher-guard-type', $invocant);

                # Also guard on there being no dispatch state.
                my $track-state := nqp::dispatch('boot-syscall', 'dispatcher-track-resume-state');
                nqp::dispatch('boot-syscall', 'dispatcher-guard-literal', $track-state);

                # Find all methods.
                my str $name-val := nqp::captureposarg_s($init, 0);
                my $invocant-val := nqp::captureposarg($init, 1);
                my @methods;
                for $invocant-val.HOW.mro($invocant-val) {
                    my $meth := $_.HOW.method_table($_){$name-val};
                    @methods.push($meth) if nqp::isconcrete($meth);
                }
                @methods.shift; # Discard the first one, which we initially called
                my $next-method := @methods.shift; # The immediate next one

                # Build chain of further methods and set it as the state.
                my $chain := Exhausted;
                while @methods {
                    $chain := DeferralChain.new(@methods.pop, $chain);
                }
                nqp::dispatch('boot-syscall', 'dispatcher-set-resume-state-literal', $chain);

                # Invoke the immediate next method.
                my $without-name := nqp::dispatch('boot-syscall',
                        'dispatcher-drop-arg', $init, 0);
                my $with-method := nqp::dispatch('boot-syscall',
                        'dispatcher-insert-arg-literal-obj', $without-name, 0,
                        nqp::getattr($next-method, NQPRoutine, '$!do'));
                nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                        'boot-code-constant', $with-method);
            }
            elsif nqp::istype($state, Exhausted) {
                nqp::die('Nowhere to defer to');
            }
            else {
                # Already working through a chain of things to dispatch on.
                # Obtain the tracking object for the dispatch state, and
                # guard against the method attribute.
                my $track-state := nqp::dispatch('boot-syscall', 'dispatcher-track-resume-state');
                my $track-method := nqp::dispatch('boot-syscall', 'dispatcher-track-attr',
                    $track-state, DeferralChain, '$!method');
                nqp::dispatch('boot-syscall', 'dispatcher-guard-literal', $track-method);

                # Update dispatch state to point to next method.
                my $track-next := nqp::dispatch('boot-syscall', 'dispatcher-track-attr',
                    $track-state, DeferralChain, '$!next');
                nqp::dispatch('boot-syscall', 'dispatcher-set-resume-state', $track-next);

                # Dispatch to the method at the head of the chain.
                my $init := nqp::dispatch('boot-syscall', 'dispatcher-get-resume-init-args');
                my $without-name := nqp::dispatch('boot-syscall',
                        'dispatcher-drop-arg', $init, 0);
                my $with-method := nqp::dispatch('boot-syscall',
                        'dispatcher-insert-arg-literal-obj', $without-name, 0,
                        nqp::getattr($state.method, NQPRoutine, '$!do'));
                nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                        'boot-code-constant', $with-method);
            }
        });
    sub test-call($obj) {
        nqp::dispatch('method-deferral', 'm', $obj)
    }

    ok(test-call(C1) eq 'c1', 'Non-resuming method deferral dispatch works');
    ok($disp-count == 1, 'Was in the dispatch callback once');
    ok($res-count == 0, 'Was never in the resume callback');

    ok(test-call(C2) eq 'c2c1', 'Single level of deferral works');
    ok($disp-count == 2, 'Was in the dispatch callback a second time');
    ok($res-count == 1, 'Was in the resume callback once');

    ok(test-call(C2) eq 'c2c1', 'Single level of deferral works with recorded program');
    ok($disp-count == 2, 'Was not in the dispatch callback again');
    ok($res-count == 1, 'Was not in the resume callback again');

    ok(test-call(C3) eq 'c3c2c1', 'Two levels of deferral works');
    ok($disp-count == 3, 'Was in the dispatch callback a third time');
    ok($res-count == 3, 'Was in the resume callback two more times as resumed twice');

    ok(test-call(C3) eq 'c3c2c1', 'Two levels of deferral works with recorded program');
    ok($disp-count == 3, 'Was not in the dispatch callback again');
    ok($res-count == 3, 'Was not in the resume callback again');

    ok(test-call(C4) eq 'c4c3c2c1', 'Three levels of deferral works');
    ok($disp-count == 4, 'Was in the dispatch callback a fourth time');
    ok($res-count == 5, 'Was in the resume callback twice more (by forth level, identical state)');

    ok(test-call(C4) eq 'c4c3c2c1', 'Three levels of deferral works with recorded program');
    ok($disp-count == 4, 'Was not in the dispatch callback again');
    ok($res-count == 5, 'Was not in the resume callback again');

    # We also test it with boot-resume-caller, which we use in Raku to skip
    # over the callsame dispatch itself.
    my $callsame := -> {
        nqp::dispatch('boot-resume-caller')
    }
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'invoke-callsame',
        # Dispatch
        -> $capture {
            my $with-target := nqp::dispatch('boot-syscall',
                    'dispatcher-insert-arg-literal-obj', $capture, 0, $callsame);
            nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                    'boot-code-constant', $with-target);
        });

    my class CS1 { method m() { 'cs1' } }
    my class CS2 is CS1 { method m() { 'cs2' ~ nqp::dispatch('invoke-callsame') } }
    my class CS3 is CS2 { method m() { 'cs3' ~ nqp::dispatch('invoke-callsame') } }
    my class CS4 is CS3 { method m() { 'cs4' ~ nqp::dispatch('invoke-callsame') } }

    ok(test-call(CS2) eq 'cs2cs1', '2-level dispatch works with boot-resume-caller');
    ok(test-call(CS3) eq 'cs3cs2cs1', '3-level dispatch works with boot-resume-caller');
    ok(test-call(CS4) eq 'cs4cs3cs2cs1', '4-level dispatch works with boot-resume-caller');

    ok(test-call(CS2) eq 'cs2cs1', '2-level dispatch works with boot-resume-caller (recorded)');
    ok(test-call(CS3) eq 'cs3cs2cs1', '3-level dispatch works with boot-resume-caller (recorded)');
    ok(test-call(CS4) eq 'cs4cs3cs2cs1', '4-level dispatch works with boot-resume-caller (recorded)');
}

# We may tweak the argument capture that we save as the initialization state.
{
    my $first := -> $arg { $arg ~ nqp::dispatch('boot-resume') }
    my $second := -> $arg-code, $arg { (nqp::isinvokable($arg-code) ?? 'y' !! 'n') ~ $arg }
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'tweaked-args-init-state',
        # Dispatch
        -> $capture {
            # Insert something to call and then use that as the resume init
            # state, before delegating to invoke it.
            my $capture-derived := nqp::dispatch('boot-syscall',
                    'dispatcher-insert-arg-literal-obj', $capture, 0, $first);
            nqp::dispatch('boot-syscall', 'dispatcher-set-resume-init-args', $capture-derived);
            nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                    'boot-code-constant', $capture-derived);
        },
        # Resume
        -> $capture {
            # Insert second callee at the start of the resume state and call
            # with that.
            my $init-args := nqp::dispatch('boot-syscall', 'dispatcher-get-resume-init-args');
            my $capture-derived := nqp::dispatch('boot-syscall',
                    'dispatcher-insert-arg-literal-obj', $init-args, 0, $second);
            nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                    'boot-code-constant', $capture-derived);
        });
    sub test-call() {
        nqp::dispatch('tweaked-args-init-state', 'x')
    }
    ok(test-call() eq 'xyx', 'Init args can be derived from initial capture');
    ok(test-call() eq 'xyx', 'Init args can be derived from initial capture (recorded)');
}

# Test we can have two resumable dispatches, and fall from the inner one to the
# outer one.
{
    my $outer := -> $arg { 'o' ~ $arg }
    my $first-inner := -> $arg { 'fi' ~ $arg ~ nqp::dispatch('boot-resume') }
    my $second-inner := -> $arg { 'si' ~ $arg ~ nqp::dispatch('boot-resume') }
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'test-resume-outer',
        # Dispatch
        -> $capture {
            # Save our resume init args, and then immediately delegate to the
            # inner dispatcher.
            nqp::dispatch('boot-syscall', 'dispatcher-set-resume-init-args', $capture);
            nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'test-resume-inner', $capture);
        },
        # Resume
        -> $capture {
            # Invoke the outer.
            my $init-args := nqp::dispatch('boot-syscall', 'dispatcher-get-resume-init-args');
            my $capture-derived := nqp::dispatch('boot-syscall',
                    'dispatcher-insert-arg-literal-obj', $init-args, 0, $outer);
            nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                    'boot-code-constant', $capture-derived);
        });
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'test-resume-inner',
        # Dispatch
        -> $capture {
            # Invoke the first inner.
            nqp::dispatch('boot-syscall', 'dispatcher-set-resume-init-args', $capture);
            my $capture-derived := nqp::dispatch('boot-syscall',
                    'dispatcher-insert-arg-literal-obj', $capture, 0, $first-inner);
            nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                    'boot-code-constant', $capture-derived);
        },
        # Resume
        -> $capture {
            # We use the resume state to indicate if we already deferred to the
            # inner candidate; if so, fall back to outer resumption.
            my $init-args := nqp::dispatch('boot-syscall', 'dispatcher-get-resume-init-args');
            my $state := nqp::dispatch('boot-syscall', 'dispatcher-get-resume-state');
            my $track-state := nqp::dispatch('boot-syscall', 'dispatcher-track-resume-state');
            nqp::dispatch('boot-syscall', 'dispatcher-guard-literal', $track-state);
            if nqp::isnull($state) {
                # First resume. Set state and invoke second inner.
                nqp::dispatch('boot-syscall', 'dispatcher-set-resume-state-literal', Exhausted);
                my $capture-derived := nqp::dispatch('boot-syscall',
                        'dispatcher-insert-arg-literal-obj', $init-args, 0, $second-inner);
                nqp::dispatch('boot-syscall', 'dispatcher-delegate',
                        'boot-code-constant', $capture-derived);
            }
            else {
                # Second resume, fall back to outer dispatcher's resumption if
                # there is one. If not, then hand back a constant.
                unless nqp::dispatch('boot-syscall', 'dispatcher-next-resumption') {
                    my $capture-derived := nqp::dispatch('boot-syscall',
                            'dispatcher-insert-arg-literal-str', $init-args, 0, 'END');
                    nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-constant',
                        $capture-derived);
                }
            }
        });
    sub test-call-inner-only() {
        nqp::dispatch('test-resume-inner', 'n')
    }
    sub test-call() {
        nqp::dispatch('test-resume-outer', 'n')
    }

    ok(test-call-inner-only() eq 'finsinEND',
        'dispatcher-next-resumption returns 0 when there is not one (record)');
    ok(test-call-inner-only() eq 'finsinEND',
        'dispatcher-next-resumption returns 0 when there is not one (run)');

    ok(test-call() eq 'finsinon',
        'dispatcher-next-resumption delegates to outer resumption if there is one (record)');
    ok(test-call() eq 'finsinon',
        'dispatcher-next-resumption delegates to outer resumption if there is one (run)');
}

# Test for where we have dispatch resumptions that themselves trigger new
# resumable dispatches.
{
    my class Wrappable {
        has $!meth;
        has $!wrapper;
        method meth() { $!meth }
        method wrapper() { $!wrapper }
    }
    my $parent := Wrappable.new(
        meth => -> $arg { 'pm' ~ $arg },
        wrapper => -> $arg { 'pw' ~ $arg ~ nqp::dispatch('boot-resume') });
    my $child := Wrappable.new(
        meth => -> $arg { 'cm' ~ $arg ~ nqp::dispatch('boot-resume') },
        wrapper => -> $arg { 'cw' ~ $arg ~ nqp::dispatch('boot-resume') });
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'test-wrappable-method-outer',
        # Dispatch
        -> $capture {
            # Save our resume init args. Prepend the child wrappable to the args and
            # delegate.
            nqp::dispatch('boot-syscall', 'dispatcher-set-resume-init-args', $capture);
            nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'test-wrappable-method-inner',
                nqp::dispatch('boot-syscall', 'dispatcher-insert-arg-literal-obj', $capture, 0, $child));
        },
        # Resume
        -> $capture {
            # Delegate again with the parent.
            my $init-args := nqp::dispatch('boot-syscall', 'dispatcher-get-resume-init-args');
            nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'test-wrappable-method-inner',
                nqp::dispatch('boot-syscall', 'dispatcher-insert-arg-literal-obj', $init-args, 0, $parent));
        });
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'test-wrappable-method-inner',
        # Dispatch
        -> $capture {
            # Save our resume init args. Then obtain the first arg which is the
            # wrappable. Drop it, pull out the wrapper, and make a call to that.
            nqp::dispatch('boot-syscall', 'dispatcher-set-resume-init-args', $capture);
            my $wrappable := nqp::captureposarg($capture, 0);
            my $target := $wrappable.wrapper;
            nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-code-constant',
                nqp::dispatch('boot-syscall', 'dispatcher-insert-arg-literal-obj',
                    nqp::dispatch('boot-syscall', 'dispatcher-drop-arg', $capture, 0),
                    0, $target));
        },
        # Resume
        -> $capture {
            # We use the resume state to indicate if we already deferred to the
            # wrapped thing.
            my $init-args := nqp::dispatch('boot-syscall', 'dispatcher-get-resume-init-args');
            my $state := nqp::dispatch('boot-syscall', 'dispatcher-get-resume-state');
            my $track-state := nqp::dispatch('boot-syscall', 'dispatcher-track-resume-state');
            nqp::dispatch('boot-syscall', 'dispatcher-guard-literal', $track-state);
            if nqp::isnull($state) {
                # First resume. Set state and invoke the inner thing.
                nqp::dispatch('boot-syscall', 'dispatcher-set-resume-state-literal', Exhausted);
                my $wrappable := nqp::captureposarg($init-args, 0);
                my $target := $wrappable.meth;
                nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-code-constant',
                    nqp::dispatch('boot-syscall', 'dispatcher-insert-arg-literal-obj',
                        nqp::dispatch('boot-syscall', 'dispatcher-drop-arg', $init-args, 0),
                        0, $target));
            }
            else {
                # Second resume, fall back to outer dispatcher's resumption.
                nqp::dispatch('boot-syscall', 'dispatcher-next-resumption') ||
                    nqp::die('Should not be falling back at the end');
            }
        });

    sub test-call() {
        nqp::dispatch('test-wrappable-method-outer', 'x')
    }
    ok(test-call() eq 'cwxcmxpwxpmx',
        'Can handle resumptions creating further resumable dispatchers (record)');
    ok(test-call() eq 'cwxcmxpwxpmx',
        'Can handle resumptions creating further resumable dispatchers (run)');
}

# Test bind fail via assertparamcheck can lead to a boot-resume
{
    sub first($x) { nqp::assertparamcheck($x == 0); "first $x" }
    sub second($x) { "second $x" }
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'test-resume-on-bind-fail',
        # Dispatch
        -> $capture {
            nqp::dispatch('boot-syscall', 'dispatcher-set-resume-init-args', $capture);
            nqp::dispatch('boot-syscall', 'dispatcher-resume-on-bind-failure', 42);
            nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-code-constant',
                nqp::dispatch('boot-syscall', 'dispatcher-insert-arg-literal-obj',
                    $capture, 0, &first));
        },
        # Resume
        -> $capture {
            # Check we got the expected argument.
            ok(nqp::captureposarg_i($capture, 0) == 42, 'Correct argument to resume');

            # Call second function with original args.
            my $init-args := nqp::dispatch('boot-syscall', 'dispatcher-get-resume-init-args');
            nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-code-constant',
                nqp::dispatch('boot-syscall', 'dispatcher-insert-arg-literal-obj',
                    $init-args, 0, &second));
        });

    sub test-call($arg) {
        nqp::dispatch('test-resume-on-bind-fail', $arg)
    }
    ok(test-call(0) eq 'first 0', 'Case where bind check is OK just runs function (record)');
    ok(test-call(1) eq 'second 1', 'Case where bind check fails runs second function (record)');
    ok(test-call(0) eq 'first 0', 'Case where bind check is OK just runs function (run)');
    ok(test-call(1) eq 'second 1', 'Case where bind check fails runs second function (run)');
}

{
    my $foo := -> $x { $x + 19 }
    sub lang-call($i) {
        nqp::dispatch('lang-call', $foo, $i);
    }
    ok(nqp::iscoderef($foo), 'Really are testing lang-call on a VM code ref');
    ok(lang-call(23) == 42, 'lang-call works with deferring to NQP dispatcher (record)');
    ok(lang-call(80) == 99, 'lang-call works with deferring to NQP dispatcher (run)');
}

{
    my $foo := nqp::create(NQPRoutine);
    nqp::bindattr($foo, NQPRoutine, '$!do', -> $x { $x + 19 });
    sub lang-call($i) {
        nqp::dispatch('lang-call', $foo, $i);
    }
    ok($foo.HOW.name($foo) eq 'NQPRoutine', 'Really are testing lang-call on NQPRoutine');
    ok(lang-call(23) == 42, 'lang-call works with deferring to NQP dispatcher (record)');
    ok(lang-call(80) == 99, 'lang-call works with deferring to NQP dispatcher (run)');
}

{
    my class C { method m($name) { "Axiom $name" } }
    sub lang-meth-call($name) {
        nqp::dispatch('lang-meth-call', C, 'm', C, $name)
    }
    ok(lang-meth-call('Greek Fire') eq 'Axiom Greek Fire',
        'lang-meth-call on an NQP class works (record)');
    ok(lang-meth-call('Queen Vaccine') eq 'Axiom Queen Vaccine',
        'lang-meth-call on an NQP class works (run)');
}

{
    my $type := nqp::knowhow().new_type(:name('DispTest'));
    sub lang-meth-call($name, $code) {
        nqp::dispatch('lang-meth-call', $type.HOW, 'add_method', $type.HOW, $type, $name, $code);
    }
    lang-meth-call('m1', -> $obj { 111 });
    lang-meth-call('m2', -> $obj { 222 });
    $type.HOW.compose($type);
    ok(nqp::dispatch('lang-meth-call', $type, 'm1', $type) == 111,
        'lang-meth-call KnowHOW fallback works (record)');
    ok(nqp::dispatch('lang-meth-call', $type, 'm2', $type) == 222,
        'lang-meth-call KnowHOW fallback works (run)');
}

{
    my int $entries := 0;
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'test-how', -> $capture {
        $entries++;
        my $obj := nqp::dispatch('boot-syscall', 'dispatcher-track-arg', $capture, 0);
        my $how := nqp::dispatch('boot-syscall', 'dispatcher-track-how', $obj);
        my $delegate := nqp::dispatch('boot-syscall', 'dispatcher-insert-arg',
            $capture, 0, $how);
        nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-value', $delegate);
    });
    sub check-it-works($obj) {
        nqp::dispatch('test-how', $obj)
    }
    my class TestA {}
    my class TestB {};
    ok(nqp::eqaddr(check-it-works(TestA), TestA.HOW), 'dispatcher-track-how (record)');
    ok(nqp::eqaddr(check-it-works(TestB), TestB.HOW), 'dispatcher-track-how (run)');
    ok($entries == 1, 'No type guard enforced by dispatcher-track-how');
}

{
    my class WithHash {
        has $!the-hash;
    }
    my $table := nqp::create(WithHash);
    nqp::bindattr($table, WithHash, '$!the-hash', nqp::hash('a', 42, 'b', 100));
    my int $entries := 0;
    nqp::dispatch('boot-syscall', 'dispatcher-register', 'test-lookup', -> $capture {
        $entries++;
        my $obj := nqp::dispatch('boot-syscall', 'dispatcher-track-arg', $capture, 0);
        my $key := nqp::dispatch('boot-syscall', 'dispatcher-track-arg', $capture, 1);
        my $table-attr := nqp::dispatch('boot-syscall', 'dispatcher-track-attr',
            $obj, WithHash, '$!the-hash');
        my $result := nqp::dispatch('boot-syscall', 'dispatcher-index-tracked-lookup-table',
            $table-attr, $key);
        my $delegate := nqp::dispatch('boot-syscall', 'dispatcher-insert-arg',
            $capture, 0, $result);
        nqp::dispatch('boot-syscall', 'dispatcher-delegate', 'boot-value', $delegate);
    });
    sub check-it-works(str $key) {
        nqp::dispatch('test-lookup', $table, $key)
    }
    ok(check-it-works('a') == 42, 'dispatcher-index-tracked-lookup-table (record)');
    ok(check-it-works('b') == 100, 'dispatcher-index-tracked-lookup-table (run)');
    ok($entries == 1, 'Only one recording of dispatch program made');
}
