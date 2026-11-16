# neuralquantumprologvis

Shows, part by part, how a Prolog algorithm translates to an artificial neural network and to a quantum circuit. It also shows that data passing through each element gives the same output for the same input.

- Algorithms are Boolean Prolog definitions (`programs.pl`), such as the half adder, full adder, majority, parity, multiplexer and implication. You can also give your own as `expr(Inputs, [Out=Expr])`.
- ANN: each gate becomes integer-weighted threshold neurons (XOR uses 3). The trace shows every neuron's weighted sum and activation.
- Quantum: each gate becomes reversible X/CNOT/Toffoli gates writing to fresh ancilla qubits. The trace shows the basis state after every gate, and there is an ASCII circuit diagram.

```
?- explain(full_adder, [1,0,1]).
```

Proved properties: every gadget (not, and, or, xor, constants) is correct on its whole truth table, which by structural induction makes every translation correct. Also proved: every library program is equivalent on all its inputs, input qubits are never changed, circuits are reversible (run backwards they uncompute), the size formulas are right, and the ANN is feed-forward.

## Tests and proofs

```
swipl run_tests.pl        # runs the 200 saved I/O pairs and checks every proof
swipl tests/gen_io.pl     # regenerates tests/io_pairs.pl from spec.pl
```

- `tests/io_pairs.pl` has 200 saved `io(Id, Predicate, Input, ExpectedOutput)` facts.
- The expected outputs come from `spec.pl`, an independent specification written in a different style from the implementation (truth tables and size formulas computed straight from the expression tree). Because the implementation is checked against a separate oracle, a pass is real evidence and not the program checking itself.
- `proofs.pl` has machine-checked `proof(Name, Goal)` theorems. Each one is checked exhaustively on a bounded domain or over sample inputs, and its comment gives the general (usually inductive) argument.

All files are plain, portable SWI-Prolog, with no packs needed.
