% spec.pl - independent oracle: truth-table semantics, and size formulas
% computed directly from the expression tree (no compilation).
:- ensure_loaded('programs.pl').

spec_for(run_all, spec_run_all).
spec_for(sizes, spec_sizes).

spec_def(expr(I, D), I, D) :- !.
spec_def(P, I, D) :- prog(P, I, D).

% The required property: all three representations agree with the truth table.
spec_run_all(P-Bits, out(O, O, O)) :-
    spec_def(P, Ins, Defs),
    findall(N=V, ( member(N=E, Defs), spec_val(E, Ins, Bits, V) ), O).

spec_val(E, _, _, E) :- integer(E), !.
spec_val(E, Ins, Bits, V) :- atom(E), !, nth1(K, Ins, E), nth1(K, Bits, V).
spec_val(E, Ins, Bits, V) :-
    E =.. [Op|Args],
    findall(X, ( member(A, Args), spec_val(A, Ins, Bits, X) ), Xs),
    table(Op, Xs, V).

table(not, [0], 1).  table(not, [1], 0).
table(and, [X, Y], V) :- ( X == 1, Y == 1 -> V = 1 ; V = 0 ).
table(or,  [X, Y], V) :- ( X == 0, Y == 0 -> V = 0 ; V = 1 ).
table(xor, [X, Y], V) :- ( X == Y -> V = 0 ; V = 1 ).

% Sizes: neurons per node (var 0, const 1, not/and/or 1, xor 3);
% one ancilla qubit per non-variable node; gates (0:0, 1:1, not 2, and 1, or 3, xor 2).
spec_sizes(P, sizes(N, Q, G)) :-
    spec_def(P, Ins, Defs), length(Ins, NI),
    findall(c(A, B, C), ( member(_=E, Defs), spec_count(E, A, B, C) ), Cs),
    spec_sum(Cs, N, Anc, G), Q is NI + Anc.

spec_sum([], 0, 0, 0).
spec_sum([c(A, B, C)|T], N, Q, G) :- spec_sum(T, N0, Q0, G0), N is N0 + A, Q is Q0 + B, G is G0 + C.

spec_count(E, 0, 0, 0) :- atom(E), !.
spec_count(0, 1, 1, 0) :- !.
spec_count(1, 1, 1, 1) :- !.
spec_count(E, N, Q, G) :-
    E =.. [Op|Args],
    findall(c(A, B, C), ( member(X, Args), spec_count(X, A, B, C) ), Cs),
    spec_sum(Cs, N0, Q0, G0),
    cost(Op, NN, GG),
    N is N0 + NN, Q is Q0 + 1, G is G0 + GG.

cost(not, 1, 2).
cost(and, 1, 1).
cost(or, 1, 3).
cost(xor, 3, 2).
