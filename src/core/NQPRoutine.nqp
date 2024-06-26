my knowhow NQPRoutine {
    has $!do;
    has $!signature;
    has $!dispatchees;
    has $!dispatch_cache;
    has $!dispatch_order;
    has $!clone_callback;
    has int $!onlystar;

    # Adds a multi-dispatch candidate.
    method add_dispatchee($code) {
        nqp::scwbdisable();
        $!dispatch_cache := nqp::null();
        $!dispatch_order := nqp::null();
        nqp::push($!dispatchees, $code);
        nqp::scwbenable();
    }

    # Checks if this code object is a dispatcher.
    method is_dispatcher() {
        nqp::defined($!dispatchees)
    }

    # Derives a new dispatcher.
    method derive_dispatcher() {
        # Clone the underlying VM code ref.
        my $do  := nqp::clone($!do);

        # Clone and attach the code object.
        my $der := nqp::clone(self);
        nqp::bindattr($der, NQPRoutine, '$!do', $do);
        nqp::bindattr($der, NQPRoutine, '$!dispatchees', nqp::clone($!dispatchees));
        nqp::setcodeobj($do, $der);

        # If needed, arrange for a fixup of the cloned code-ref.
        unless nqp::isnull($!clone_callback) {
            $!clone_callback($!do, $do, $der);
        }

        $der
    }

    # Checks if one type is narrower than the other.
    sub is_narrower_type($a, $b) {
        # If one of the types is null, then we know that's automatically
        # wider than anything.
        if nqp::isnull($b) && !nqp::isnull($a) { 1 }
        elsif nqp::isnull($a) || nqp::isnull($b) { 0 }
        else { nqp::istype($a, $b) }
    }

    # Sorts the dispatchees. Puts nulls between groups that are of equal weight.
    # The most specific group comes first.
    my int $SLURPY_ARITY      := nqp::bitshiftl_i(1, 30);
    my int $EDGE_REMOVAL_TODO := -1;
    my int $EDGE_REMOVED      := -2;
    my int $DEFINED_ONLY      := 1;
    my int $UNDEFINED_ONLY    := 2;
    method sort_dispatchees() {
        # Takes two candidates and determines if the first one is narrower than the
        # second. Returns a true value if they are.
        sub is_narrower(%a, %b) {
            # Work out how many parameters to compare, factoring in slurpiness
            # and optionals.
            my int $types_to_check;
            if %a<num_types> == %b<num_types> {
                $types_to_check := %a<num_types>;
            }
            elsif %a<min_arity> == %b<min_arity> {
                $types_to_check := %a<num_types> > %b<num_types> ?? %b<num_types> !! %a<num_types>;
            }
            else {
                return 0;
            }

            # Analyse each parameter in the two candidates.
            my int $i := 0;
            my int $narrower := 0;
            my int $tied := 0;
            while $i < $types_to_check {
                my $type_obj_a := %a<types>[$i];
                my $type_obj_b := %b<types>[$i];
                if nqp::eqaddr($type_obj_a, $type_obj_b) {
                    ++$tied;
                }
                elsif is_narrower_type($type_obj_a, $type_obj_b) {
                    ++$narrower;
                }
                elsif !is_narrower_type($type_obj_b, $type_obj_a) {
                    ++$tied;
                }
                ++$i;
            }

            # If one is narrower than the other from current analysis, we're done.
            if $narrower >= 1 && $narrower + $tied == $types_to_check {
                return 1;
            }

            # If they aren't tied, we're also done.
            elsif $tied != $types_to_check {
                return 0;
            }

            # Otherwise, we see if one has a slurpy and the other not. A lack of
            # slurpiness makes the candidate narrower. Otherwise, they're tied.
            return %a<max_arity> != $SLURPY_ARITY && %b<max_arity> == $SLURPY_ARITY;
        }

        # Create a node for each candidate in the graph.
        my @graph;
        my int $num_candidates := nqp::elems($!dispatchees);
        my int $i := 0;
        while $i < $num_candidates {
            # Get hold of signature, types and definednesses.
            my $candidate := $!dispatchees[$i];
            my $multi_sig := $candidate.signature;
            my @types_list := $multi_sig.types;
            my @definedness_list := $multi_sig.definednesses;
            my int $sig_elems := nqp::elems(@types_list);

            # Type information.
            my %info := nqp::hash(
                'sub',           $candidate,
                'types',         [],
                'definednesses', [],
                'min_arity',     0,
                'max_arity',     0,
                'num_types',     0
            );
            my %significant_param := 0;
            my int $j := 0;
            while $j < $sig_elems {
                # XXX TODO: Worry about optional and slurpy later.
                ++%info<max_arity>;
                ++%info<min_arity>;

                # Record type info for this parameter. */
                nqp::push(%info<types>, @types_list[$j]);
                nqp::push(%info<definednesses>, @definedness_list[$j]);
                ++%info<num_types>;

                ++$j;
            }

            # Add it to graph node, and initialize list of edges.
            nqp::push(@graph, nqp::hash(
                'info',      %info,
                'edges',     [],
                'edges_in',  0,
                'edges_out', 0
            ));

            ++$i;
        }

        # Now analyze type narrowness of the candidates relative to each other
        # and create the edges.
        $i := 0;
        while $i < $num_candidates {
            my int $j := 0;
            while $j < $num_candidates {
                if ($i != $j) {
                    if is_narrower(@graph[$i]<info>, @graph[$j]<info>) {
                        @graph[$i]<edges>[@graph[$i]<edges_out>] := @graph[$j];
                        ++@graph[$i]<edges_out>;
                        ++@graph[$j]<edges_in>;
                    }
                }
                ++$j;
            }
            ++$i;
        }

        # Perform the topological sort.
        my @result;
        my int $candidates_to_sort := $num_candidates;
        while $candidates_to_sort > 0 {
            my int $rem_results := nqp::elems(@result);

            # Find any nodes that have no incoming edges and add them to
            # results.
            my int $i := 0;
            while $i < $num_candidates {
                if @graph[$i]<edges_in> == 0 {
                    # Add to results.
                    nqp::push(@result, @graph[$i]<info>);
                    --$candidates_to_sort;
                    @graph[$i]<edges_in> := $EDGE_REMOVAL_TODO;
                }
                ++$i;
            }
            if $rem_results == nqp::elems(@result) {
                nqp::die("Circularity detected in multi sub types");
            }

            # Now we need to decrement edges in counts for things that had
            # edges from candidates we added here.
            $i := 0;
            while $i < $num_candidates {
                if @graph[$i]<edges_in> == $EDGE_REMOVAL_TODO {
                    my int $j := 0;
                    while $j < @graph[$i]<edges_out> {
                        --@graph[$i]<edges>[$j]<edges_in>;
                        ++$j;
                    }
                    @graph[$i]<edges_in> := $EDGE_REMOVED;
                }
                ++$i;
            }

            # Add gap between groups.
            nqp::push(@result, nqp::null());
        }

        # Add final null sentinel.
        nqp::push(@result, nqp::null());

        return @result;
    }

    # On MoarVM, we use new-disp to do the multiple dispatch.
#?if !moar
    method dispatch($capture) {
        # Count arguments.
        my int $num_args := nqp::captureposelems($capture);

        # Get list and number of candidates, triggering a sort if there are none.
        my @candidates := $!dispatch_order;
        if nqp::isnull(@candidates) {
            nqp::scwbdisable();
            @candidates := $!dispatch_order := self.sort_dispatchees();
            nqp::scwbenable();
        }
        my int $num_candidates := nqp::elems(@candidates);

        # Initialize dispatcher state.
        my @possibles;

        # Go through candidates.
        my int $type_mismatch;
        my int $type_check_count;
        my int $i;
        my int $cur_idx := 0;
        my $cur_candidate;
        while 1 {
            $cur_candidate := @candidates[$cur_idx];

            if nqp::isnull($cur_candidate) {
                # If we have some possible candidate(s), we're done in this loop.
                if nqp::elems(@possibles) {
                    last;
                }

                # Otherwise, we keep looping and looking, unless we really hit the end.
                if nqp::isnull(@candidates[++$cur_idx]) {
                    last;
                }
                else {
                    next;
                }
            }

            # Check if it's admissible by arity.
            if $num_args < $cur_candidate<min_arity> || $num_args > $cur_candidate<max_arity> {
                ++$cur_idx;
                next;
            }

            # Check if it's admissible by type.
            $type_check_count := $cur_candidate<num_types> > $num_args
                             ?? $num_args
                             !! $cur_candidate<num_types>;
            $type_mismatch := 0;
            $i := 0;
            while $i < $type_check_count {
                my $param := nqp::captureposarg($capture, $i);
                my $param_type := $param.WHAT;
                my $type_obj := $cur_candidate<types>[$i];
                my $definedness := $cur_candidate<definednesses>[$i];
                unless nqp::eqaddr($param_type, $type_obj) || nqp::isnull($type_obj) || is_narrower_type($param_type, $type_obj) {
                    $type_mismatch := 1;
                    last;
                }
                if $definedness {
                    # Have a constraint on the definedness.
                    my int $defined := nqp::isnull($param_type) ?? nqp::defined($param) !! nqp::isconcrete($param);
                    if (!$defined && $definedness == $DEFINED_ONLY) || ($defined && $definedness == $UNDEFINED_ONLY) {
                        $type_mismatch := 1;
                        last;
                    }
                }
                ++$i;
            }

            if $type_mismatch {
                ++$cur_idx;
                next;
            }

            # If we get here, it's an admissible candidate; add to list. */
            nqp::push(@possibles, $cur_candidate);
            ++$cur_idx;
        }

        # Cache the result if there's a single chosen one and return it.
        if nqp::elems(@possibles) == 1 {
            my $result := @possibles[0]<sub>;
            nqp::scwbdisable();
            $!dispatch_cache := nqp::multicacheadd($!dispatch_cache, $capture, $result);
            nqp::scwbenable();
            $result
        }
        elsif nqp::elems(@possibles) == 0 {
            # XXX Include possible candidate signatures.
            nqp::die("No applicable candidates found to dispatch to for '" ~ self.name ~ "'.")
        }
        else {
            # XXX Include ambiguous candidate signatures.
            nqp::die("Ambiguous dispatch to multi '" ~ self.name ~ "'.")
        }
    }
#?endif

    method clone() {
        # Clone the underlying VM code ref.
        my $do  := nqp::clone($!do);

        # Clone and attach the code object.
        my $der := nqp::clone(self);
        nqp::bindattr($der, NQPRoutine, '$!do', $do);
        nqp::setcodeobj($do, $der);

        # If needed, arrange for a fixup of the cloned code-ref.
        unless nqp::isnull($!clone_callback) {
            $!clone_callback($!do, $do, $der);
        }

        $der
    }

    method !set_name($name) {
        nqp::setcodename($!do, $name);
    }

    method name() {
        nqp::getcodename($!do)
    }

    method signature() { $!signature }

    method gist() {
        self.name()
    }
}
#?if !moar
nqp::setinvokespec(NQPRoutine, NQPRoutine, '$!do', nqp::null);
#?endif
nqp::setboolspec(NQPRoutine, 5, nqp::null());
nqp::settypehll(NQPRoutine, 'nqp');

my knowhow NQPSignature {
    has $!types;
    has $!definednesses;
    method types() { $!types }
    method definednesses() { $!definednesses }
}
nqp::settypehll(NQPSignature, 'nqp');

# Data on the captures that a particular rule has.
my knowhow RegexCaptures {
    # An integer array of positional capture counts.
    has @!pos-capture-counts;

    # A string array of named capture names and a matching integer array of
    # capture counts.
    has @!named-capture-names;
    has @!named-capture-counts;

    # If there's only one name and captured multiple times, then we fast-path it
    # in MATCH. If such a case, this holds the only name.
    has str $!onlyname;

    # Flags to allow us to more quickly figure stuff out.
    my int $HAS_CAPTURES := 1;
    my int $HAS_QUANT_LIST_CAPTURES := 2;
    my int $HAS_QUANT_HASH_CAPTURES := 4;
    has int $!flags;

    # Form this data structure from a capnames hash.
    method from-capnames(%capnames) {
        nqp::create(self).'!from-capnames'(%capnames)
    }

    method !from-capnames(%capnames) {
        # Initialize.
        @!pos-capture-counts := nqp::list_i();
        @!named-capture-names := nqp::list_s();
        @!named-capture-counts := nqp::list_i();

        # Go over the captures and build up the data structure.
        my int $num-captures := 0;
        my str $onlyname := '';
        my int $quant-list-captures := 0;
        my int $quant-hash-captures := 0;
        for sorted_keys(%capnames) -> $name {
            if $name ne '' {
                my $count := %capnames{$name};
                if nqp::ord($name) != 36 && nqp::ord($name) < 58 {
                    nqp::bindpos_i(@!pos-capture-counts, +$name, $count);
                    $quant-list-captures++ if $count >= 2;
                }
                else {
                    nqp::push_s(@!named-capture-names, $name);
                    nqp::push_i(@!named-capture-counts, $count);
                    $quant-hash-captures++ if $count >= 2;
                }
                $num-captures++;
                if $count >= 2 && nqp::ord($name) != 36 {
                    $onlyname := $name;
                }
            }
        }

        $!onlyname := $num-captures == 1 && $onlyname ne '' ?? $onlyname !! '';
        $!flags := ($num-captures ?? $HAS_CAPTURES !! 0) +
            ($quant-list-captures ?? $HAS_QUANT_LIST_CAPTURES !! 0) +
            ($quant-hash-captures ?? $HAS_QUANT_HASH_CAPTURES !! 0);

        self
    }

    # Are there any captures?
    method has-captures() {
        nqp::bitand_i($!flags, $HAS_CAPTURES)
    }

    # Build a list of positional captures, or return a shared empty list if
    # there are none. This only populates the slots which need an array.
    my $EMPTY-LIST := nqp::list();
    my $EMPTY-HASH := nqp::hash();
    method prepare-list() {
        my int $n := nqp::elems(@!pos-capture-counts);
        if $n > 0 {
            my $result := nqp::list();
            if nqp::bitand_i($!flags, $HAS_QUANT_LIST_CAPTURES) {
                my int $i := 0;
                while $i < $n {
                    nqp::bindpos($result, $i, nqp::list())
                        if nqp::atpos_i(@!pos-capture-counts, $i) >= 2;
                    $i++;
                }
            }
            $result
        }
        else {
            $EMPTY-LIST
        }
    }

    # Build a hash of named camptures, or return a shared empty hash if there
    # are none. This only poplates the slots that need an array.
    method prepare-hash() {
        my int $n := nqp::elems(@!named-capture-counts);
        if $n > 0 {
            my $result := nqp::hash();
            if nqp::bitand_i($!flags, $HAS_QUANT_HASH_CAPTURES) {
                my int $i := 0;
                while $i < $n {
                    if nqp::atpos_i(@!named-capture-counts, $i) >= 2 {
                        nqp::bindkey($result,
                            nqp::atpos_s(@!named-capture-names, $i),
                            nqp::list());
                    }
                    $i++;
                }
            }
            $result
        }
        else {
            $EMPTY-HASH
        }
    }

    # Get the name of the only capture, if there is only one.
    method onlyname() { $!onlyname }
}
nqp::settypehll(RegexCaptures, 'nqp');

my knowhow NQPRegex {
    has $!do;
    has $!caps;
    has $!nfa;
    has %!alt_nfas;
    has $!generic_nfa;
    has @!nested_codes;
    has $!clone_callback;
    method SET_CAPS(%capnames) {
        $!caps := RegexCaptures.from-capnames(%capnames);
    }
    method SET_NFA($nfa) {
        $!nfa := self.'!hllize_nfa'($nfa);
    }
    method SET_ALT_NFA($name, $nfa) {
        nqp::ifnull(%!alt_nfas, %!alt_nfas := {});
        %!alt_nfas{$name} := self.'!hllize_nfa'($nfa);
    }
    method SET_GENERIC_NFA($nfa) {
        $!generic_nfa := self.'!hllize_nfa'($nfa.save());
    }
    method !hllize_nfa($nfa) {
        sub hll_list($l) {
            if nqp::islist($l) {
                my @h_l := nqp::list();
                for $l -> $elem {
                    nqp::push(@h_l, hll_list($elem));
                }
                @h_l
            }
            else {
                $l
            }
        }
        hll_list($nfa)
    }
    method ADD_NESTED_CODE($code) {
        nqp::ifnull(@!nested_codes, @!nested_codes := nqp::list());
        nqp::push(@!nested_codes, $code);
    }
    method CAPS() {
        $!caps
    }
    method NFA() {
        $!nfa
    }
    method ALT_NFAS() {
        nqp::isnull(%!alt_nfas) ?? nqp::hash() !! %!alt_nfas
    }
    method ALT_NFA(str $name) {
        nqp::isnull(%!alt_nfas) ?? nqp::null() !! %!alt_nfas{$name}
    }
    method NESTED_CODES() {
        nqp::isnull(@!nested_codes) ?? nqp::list() !! @!nested_codes
    }
    method clone() {
        # Clone the underlying VM code ref.
        my $do  := nqp::clone($!do);

        # Clone and attach the code object.
        my $der := nqp::clone(self);
        nqp::bindattr($der, NQPRegex, '$!do', $do);
        nqp::setcodeobj($do, $der);

        # If needed, arrange for a fixup of the cloned code-ref.
        unless nqp::isnull($!clone_callback) {
            $!clone_callback($!do, $do, $der);
        }

        $der
    }
    my $nfa_type;
    method SET_NFA_TYPE($type) {
        $nfa_type := $type;
    }
    method instantiate_generic($env) {
        if nqp::isnull($!generic_nfa) {
            self.clone()
        }
        else {
            my $ins := self.clone();
            nqp::bindattr($ins, NQPRegex, '$!nfa',
                $nfa_type.from_saved($!generic_nfa).instantiate_generic($env).save());
            nqp::bindattr($ins, NQPRegex, '$!generic_nfa', nqp::null());
            $ins
        }
    }
    method name() {
        nqp::getcodename($!do)
    }
    method !set_name($name) {
        nqp::setcodename($!do, $name);
    }
}
#?if !moar
nqp::setinvokespec(NQPRegex, NQPRegex, '$!do', nqp::null);
#?endif
nqp::setboolspec(NQPRegex, 5, nqp::null());
nqp::settypehll(NQPRegex, 'nqp');
