% inputs.pl - 200 test inputs: library programs on all inputs, then
% pseudo-randomly generated expressions.
:- ensure_loaded('../programs.pl').

input(Id, P, I) :- findall(P0-I0, case(P0, I0), Cs), nth1(Id, Cs, P-I), Id =< 200.

case(run_all, P-B) :- prog(P, Ins, _), length(Ins, N), bitlist(N, B).
case(sizes, P) :- prog(P, _, _).
case(run_all, expr(Ins, [y=E])-B) :-
    between(1, 70, Seed), Ins = [a, b, c], rexpr(3, Seed, _, E),
    S2 is Seed mod 8, bin3(S2, B).
case(sizes, expr([a, b, c], [y=E, z=F])) :-
    between(1, 60, Seed), rexpr(3, Seed, S1, E), rexpr(2, S1, _, F).

bitlist(0, []) :- !.
bitlist(N, [B|Bs]) :- member(B, [0, 1]), N1 is N - 1, bitlist(N1, Bs).

bin3(N, [A, B, C]) :- A is (N >> 2) /\ 1, B is (N >> 1) /\ 1, C is N /\ 1.

lcg(S0, S) :- S is (S0 * 1103515245 + 12345) mod 2147483648.

rexpr(0, S0, S, E) :- !, lcg(S0, S), K is (S >> 16) mod 5, nth0(K, [a, b, c, 0, 1], E).
rexpr(D, S0, S, E) :-
    lcg(S0, S1), K is (S1 >> 16) mod 6, D1 is D - 1,
    (   K =:= 0 -> rexpr(0, S1, S, E)
    ;   K =:= 1 -> rexpr(D1, S1, S, A), E = not(A)
    ;   nth0(K, [_, _, and, or, xor, and], Op),
        rexpr(D1, S1, S2, A), rexpr(D1, S2, S, B), E =.. [Op, A, B]
    ).
