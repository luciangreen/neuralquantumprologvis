% programs.pl - Boolean Prolog algorithms to translate.
% prog(Name, Inputs, [Output=Expression, ...]).

prog(not_gate,   [a],       [y=not(a)]).
prog(and_gate,   [a, b],    [y=and(a, b)]).
prog(or_gate,    [a, b],    [y=or(a, b)]).
prog(xor_gate,   [a, b],    [y=xor(a, b)]).
prog(nand_gate,  [a, b],    [y=not(and(a, b))]).
prog(implies,    [p, q],    [r=or(not(p), q)]).
prog(equiv,      [p, q],    [r=not(xor(p, q))]).
prog(half_adder, [a, b],    [sum=xor(a, b), carry=and(a, b)]).
prog(full_adder, [a, b, c], [sum=xor(xor(a, b), c), carry=or(and(a, b), and(c, xor(a, b)))]).
prog(majority,   [a, b, c], [m=or(or(and(a, b), and(a, c)), and(b, c))]).
prog(parity3,    [a, b, c], [p=xor(xor(a, b), c)]).
prog(mux,        [s, a, b], [o=or(and(not(s), a), and(s, b))]).
prog(constant_true, [a],    [y=or(a, 1), z=and(a, 0)]).
