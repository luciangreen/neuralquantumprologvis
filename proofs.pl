% proofs.pl - correctness of the Prolog -> ANN and Prolog -> quantum translations.
%
% Theorem: for every expression E and input bits B,
%   ann(E)(B) = eval(E)(B) = quantum(E)(B).
% Proof by structural induction on E. Base cases: a variable is passed through
% (in(V) / its own qubit); constants are a bias-only neuron / X on a fresh
% ancilla. Inductive step: each operator's compiled gadget computes the
% operator's truth table on the (inductively correct) values of its
% sub-expressions; the lemmas gadget_* below check every gadget on all of
% its finitely many inputs, which is a complete proof of each lemma.
% Ancillas are fresh and earlier qubits are only read (lemma
% inputs_unchanged), so sub-results are not disturbed.
:- ensure_loaded('neuralquantumprologvis.pl').
:- ensure_loaded('spec.pl').

bits(0, []) :- !.
bits(N, [B|Bs]) :- N > 0, member(B, [0, 1]), N1 is N - 1, bits(N1, Bs).

gadget_ok(Op, Arity) :-
    length(Vs, Arity), Names = [a, b], append(Ins, _, Names), length(Ins, Arity),
    Vs = Ins, E =.. [Op|Vs],
    forall(bits(Arity, B), run_all(expr(Ins, [y=E])-B, out(X, X, X))).

proof(gadget_not, gadget_ok(not, 1)).
proof(gadget_and, gadget_ok(and, 2)).
proof(gadget_or, gadget_ok(or, 2)).
proof(gadget_xor, gadget_ok(xor, 2)).
proof(gadget_constants, ( run_all(expr([a], [y=0, z=1])-[0], out(X, X, X)), X == [y=0, z=1] )).

% Every library program agrees on its whole truth table (exhaustive proof).
proof(library_programs_equivalent,
      forall(prog(P, Ins, _), ( length(Ins, N),
             forall(bits(N, B), ( run_all(P-B, out(X, Y, Z)), X == Y, Y == Z )) ))).

% The quantum circuit never changes its input qubits (they are only controls).
proof(inputs_unchanged,
      forall(prog(P, Ins, Defs), ( length(Ins, N), q_compile(Ins, Defs, circ(Q, Gs, _)),
             forall(bits(N, B), ( q_initial(B, Q, S0), foldl(apply_gate, Gs, S0, S),
                                  length(Pre, N), append(Pre, _, S), Pre == B )) ))).

% Every gate is its own inverse, so running the circuit backwards uncomputes it.
proof(circuit_reversible,
      forall(prog(P, Ins, Defs), ( length(Ins, N), q_compile(Ins, Defs, circ(Q, Gs, _)),
             reverse(Gs, Rs),
             forall(bits(N, B), ( q_initial(B, Q, S0), foldl(apply_gate, Gs, S0, S1),
                                  foldl(apply_gate, Rs, S1, S2), S2 == S0 )) ))).

% Size formulas from spec.pl match the compilers.
proof(sizes_match_spec, forall(prog(P, _, _), ( sizes(P, A), spec_sizes(P, B), A == B ))).

% The ANN is feed-forward: each neuron reads only inputs or earlier neurons.
proof(ann_feed_forward,
      forall(prog(_, _, Defs), ( ann_compile(Defs, net(Ns, _)),
             forall(nth0(I, Ns, neuron(Id, Srcs, _)),
                    ( Id =:= I, forall(member(n(J)-_, Srcs), J < Id) )) ))).
