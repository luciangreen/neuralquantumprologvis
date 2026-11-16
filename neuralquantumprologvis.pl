% neuralquantumprologvis - partwise visualisation of how a Prolog algorithm
% translates to an artificial neural network and to a quantum circuit, showing
% that data passing through each element gives the same input and output.
%
% Algorithms are Boolean Prolog definitions: prog(Name, Inputs, [Out=Expr,...])
% with Expr built from input names, 0, 1, not/1, and/2, or/2, xor/2.
%
% Try:  ?- explain(full_adder, [1,0,1]).
%       ?- explain(expr([p,q], [r=or(not(p),q)]), [1,0]).

:- ensure_loaded('programs.pl').

prog_def(expr(Ins, Defs), Ins, Defs) :- !.
prog_def(P, Ins, Defs) :- prog(P, Ins, Defs).

% ---- entry points used by the tests ----------------------------------------
% run_all(+Prog-Bits, -out(PrologOut, AnnOut, QuantumOut))
run_all(P-Bits, out(PO, AO, QO)) :-
    prolog_run(P, Bits, PO), ann_run(P, Bits, AO), q_run(P, Bits, QO).

% sizes(+Prog, -sizes(Neurons, Qubits, Gates))
sizes(P, sizes(N, Q, G)) :-
    prog_def(P, Ins, Defs),
    ann_compile(Defs, Net), Net = net(Ns, _), length(Ns, N),
    length(Ins, NI), q_compile(Ins, Defs, circ(Q, Gs, _)), length(Gs, G),
    Q >= NI.

% ---- 1. Prolog semantics ----------------------------------------------------
prolog_run(P, Bits, Outs) :-
    prog_def(P, Ins, Defs), env(Ins, Bits, Env),
    findall(O=V, ( member(O=E, Defs), eval(E, Env, V) ), Outs).

env([], [], []).
env([I|Is], [B|Bs], [I=B|E]) :- env(Is, Bs, E).

eval(0, _, 0) :- !.
eval(1, _, 1) :- !.
eval(V, Env, X) :- atom(V), !, memberchk(V=X, Env).
eval(not(A), E, V) :- eval(A, E, X), V is 1 - X.
eval(and(A, B), E, V) :- eval(A, E, X), eval(B, E, Y), V is X * Y.
eval(or(A, B), E, V) :- eval(A, E, X), eval(B, E, Y), V is max(X, Y).
eval(xor(A, B), E, V) :- eval(A, E, X), eval(B, E, Y), V is (X + Y) mod 2.

% ---- 2. Artificial neural network -------------------------------------------
% neuron(Id, [Source-Weight,...], Bias); activation = 1 if sum + bias > 0.
% Sources are in(Var) or n(Id).
ann_compile(Defs, net(Ns, Outs)) :-
    foldl(ann_out, Defs, Outs, 0-[], _-Rev), reverse(Rev, Ns).

ann_out(O=E, O=Src, S0, S) :- ann_c(E, Src, S0, S).

ann_c(V, in(V), S, S) :- atom(V), !.
ann_c(C, n(Id), Id-Ns, N-[neuron(Id, [], C)|Ns]) :- integer(C), !, N is Id + 1.
ann_c(not(A), n(Id), S0, N-[neuron(Id, [SA-(-2)], 1)|Ns]) :-
    ann_c(A, SA, S0, Id-Ns), N is Id + 1.
ann_c(and(A, B), n(Id), S0, N-[neuron(Id, [SA-2, SB-2], -3)|Ns]) :-
    ann_c(A, SA, S0, S1), ann_c(B, SB, S1, Id-Ns), N is Id + 1.
ann_c(or(A, B), n(Id), S0, N-[neuron(Id, [SA-2, SB-2], -1)|Ns]) :-
    ann_c(A, SA, S0, S1), ann_c(B, SB, S1, Id-Ns), N is Id + 1.
ann_c(xor(A, B), n(Id), S0, N-[neuron(Id, [n(H1)-2, n(H2)-2], -3),
                                neuron(H2, [SA-(-2), SB-(-2)], 3),
                                neuron(H1, [SA-2, SB-2], -1)|Ns]) :-
    ann_c(A, SA, S0, S1), ann_c(B, SB, S1, H1-Ns),
    H2 is H1 + 1, Id is H1 + 2, N is H1 + 3.

ann_run(P, Bits, Outs) :-
    prog_def(P, Ins, Defs), env(Ins, Bits, Env),
    ann_compile(Defs, net(Ns, OSrcs)),
    foldl(fire(Env), Ns, [], Acts),
    findall(O=V, ( member(O=S, OSrcs), src_val(S, Env, Acts, V) ), Outs).

fire(Env, neuron(Id, Ins, B), A0, [Id-V|A0]) :-
    foldl(weigh(Env, A0), Ins, B, Sum),
    ( Sum > 0 -> V = 1 ; V = 0 ).

weigh(Env, Acts, S-W, A0, A) :- src_val(S, Env, Acts, X), A is A0 + W * X.

src_val(in(V), Env, _, X) :- memberchk(V=X, Env).
src_val(n(I), _, Acts, X) :- memberchk(I-X, Acts).

% ---- 3. Quantum circuit ------------------------------------------------------
% Reversible gates on qubits 0..Q-1: x(T), cnot(C,T), ccx(C1,C2,T).
% Inputs occupy the first qubits; every operation writes a fresh ancilla.
q_compile(Ins, Defs, circ(Q, Gates, Outs)) :-
    length(Ins, NI),
    foldl(q_out(Ins), Defs, Outs, NI-[], Q-Rev), reverse(Rev, Gates).

q_out(Ins, O=E, O=Qb, S0, S) :- q_c(E, Qb, Ins, S0, S).

q_c(V, Q, Ins, S, S) :- atom(V), !, nth0(Q, Ins, V).
q_c(0, Q, _, Q-G, Q1-G) :- !, Q1 is Q + 1.
q_c(1, Q, _, Q-G, Q1-[x(Q)|G]) :- !, Q1 is Q + 1.
q_c(not(A), Q, Ins, S0, Q1-[x(Q), cnot(QA, Q)|G]) :-
    q_c(A, QA, Ins, S0, Q-G), Q1 is Q + 1.
q_c(and(A, B), Q, Ins, S0, Q1-[ccx(QA, QB, Q)|G]) :-
    q_c(A, QA, Ins, S0, S1), q_c(B, QB, Ins, S1, Q-G), Q1 is Q + 1.
q_c(or(A, B), Q, Ins, S0, Q1-[ccx(QA, QB, Q), cnot(QB, Q), cnot(QA, Q)|G]) :-
    q_c(A, QA, Ins, S0, S1), q_c(B, QB, Ins, S1, Q-G), Q1 is Q + 1.
q_c(xor(A, B), Q, Ins, S0, Q1-[cnot(QB, Q), cnot(QA, Q)|G]) :-
    q_c(A, QA, Ins, S0, S1), q_c(B, QB, Ins, S1, Q-G), Q1 is Q + 1.

q_run(P, Bits, Outs) :-
    prog_def(P, Ins, Defs),
    q_compile(Ins, Defs, circ(Q, Gates, OQs)),
    q_initial(Bits, Q, S0),
    foldl(apply_gate, Gates, S0, S),
    findall(O=V, ( member(O=Qb, OQs), nth0(Qb, S, V) ), Outs).

q_initial(Bits, Q, S) :-
    length(Bits, NI), NZ is Q - NI, length(Zs, NZ), maplist(=(0), Zs),
    append(Bits, Zs, S).

apply_gate(x(T), S0, S) :- flip_if(1, T, S0, S).
apply_gate(cnot(C, T), S0, S) :- nth0(C, S0, VC), flip_if(VC, T, S0, S).
apply_gate(ccx(C1, C2, T), S0, S) :-
    nth0(C1, S0, V1), nth0(C2, S0, V2), F is V1 * V2, flip_if(F, T, S0, S).

flip_if(0, _, S, S).
flip_if(1, T, S0, S) :- set_nth0(T, S0, Old, New, S), New is 1 - Old.

set_nth0(0, [Old|T], Old, New, [New|T]) :- !.
set_nth0(I, [H|T], Old, New, [H|R]) :- I1 is I - 1, set_nth0(I1, T, Old, New, R).

% ---- partwise visualisation -------------------------------------------------
explain(P, Bits) :-
    prog_def(P, Ins, Defs), env(Ins, Bits, Env),
    format("Prolog algorithm ~w with input ~w~n", [P, Env]),
    forall(member(O=E, Defs), format("  ~w = ~w~n", [O, E])),
    prolog_run(P, Bits, PO), format("Prolog output:  ~w~n~nNeural network, neuron by neuron:~n", [PO]),
    ann_trace(P, Bits, AL), forall(member(L, AL), format("  ~w~n", [L])),
    ann_run(P, Bits, AO), format("ANN output:     ~w~n~nQuantum circuit, gate by gate:~n", [AO]),
    q_trace(P, Bits, QL), forall(member(L, QL), format("  ~w~n", [L])),
    q_run(P, Bits, QO), format("Quantum output: ~w~n~nCircuit diagram (o control, + target, X not):~n", [QO]),
    q_diagram(P, Rows), forall(member(R, Rows), format("  ~w~n", [R])),
    ( PO == AO, AO == QO -> V = same ; V = different ),
    format("~nAll three give the ~w output for the same input.~n", [V]).

ann_trace(P, Bits, Lines) :-
    prog_def(P, Ins, Defs), env(Ins, Bits, Env),
    ann_compile(Defs, net(Ns, _)),
    foldl(trace_fire(Env), Ns, []-[], _-Rev), reverse(Rev, Lines).

trace_fire(Env, neuron(Id, Ins, B), A0-L0, [Id-V|A0]-[Line|L0]) :-
    findall(T, ( member(S-W, Ins), src_val(S, Env, A0, X), src_name(S, SN),
                 format(atom(T), '~w*~w(~w)', [W, SN, X]) ), Ts),
    foldl(weigh(Env, A0), Ins, B, Sum),
    ( Sum > 0 -> V = 1 ; V = 0 ),
    atomic_list_concat(Ts, ' + ', TA),
    format(atom(Line), 'n~w = step(~w + ~w = ~w) = ~w', [Id, TA, B, Sum, V]).

src_name(in(V), V).
src_name(n(I), N) :- format(atom(N), 'n~w', [I]).

q_trace(P, Bits, Lines) :-
    prog_def(P, Ins, Defs),
    q_compile(Ins, Defs, circ(Q, Gates, _)),
    q_initial(Bits, Q, S0),
    foldl(trace_gate, Gates, S0-[], _-Rev), reverse(Rev, Lines).

trace_gate(G, S0-L0, S-[Line|L0]) :-
    apply_gate(G, S0, S),
    atomic_list_concat(S0, B0), atomic_list_concat(S, B1),
    format(atom(Line), '~w: |~w> -> |~w>', [G, B0, B1]).

q_diagram(P, Rows) :-
    prog_def(P, Ins, Defs),
    q_compile(Ins, Defs, circ(Q, Gates, _)),
    Q1 is Q - 1,
    findall(Row, ( between(0, Q1, W), wire_label(W, Ins, Lab),
                   findall(C, ( member(G, Gates), gate_char(G, W, C) ), Cs),
                   atomic_list_concat(Cs, '-', Body),
                   format(atom(Row), '~w: -~w-', [Lab, Body]) ), Rows).

wire_label(W, Ins, L) :- ( nth0(W, Ins, V) -> L0 = V ; format(atom(L0), 'anc~w', [W]) ),
    format(atom(L), '~w', [L0]).

gate_char(x(T), W, C) :- ( W =:= T -> C = 'X' ; C = '-' ).
gate_char(cnot(Ct, T), W, C) :- ( W =:= Ct -> C = o ; W =:= T -> C = '+' ; C = '-' ).
gate_char(ccx(A, B, T), W, C) :- ( ( W =:= A ; W =:= B ) -> C = o ; W =:= T -> C = '+' ; C = '-' ).
