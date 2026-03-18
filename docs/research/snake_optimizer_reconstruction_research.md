# Reconstructing the Snake Optimizer: Comprehensive Research Report

**Date**: 2026-03-15
**Goal**: Independently reconstruct a Snake-like frequency optimizer for superconducting quantum processors

---

## 1. Snake Optimizer Paper Details

### Sources
- Klimov et al., arXiv:2006.04594 (2020) -- the original whitepaper
- Klimov et al., Nature Communications 15, 2442 (2024) -- arXiv:2308.02321 / PMC10948820

### What Is Disclosed

**Problem formulation**: Optimize frequency configuration F* = argmin_F E(F|A,D) where:
- F is a ~177-dimensional vector (68 idle + 109 interaction frequencies for N=68 qubits)
- A is the target quantum algorithm
- D is device characterization data
- The problem is non-convex, highly constrained, with ~k^|F| configurations (k~10^2 options per frequency)

**Error model structure**:
```
E(F|A,D) = sum_{g in A} sum_{m in M} w_{g,m}(A) * epsilon_{g,m}(F_{g,m} | D)
```
- g indexes gates in algorithm A
- m indexes physical error mechanisms in set M (4 types)
- w_{g,m} are algorithm-dependent trainable weights (only 16 total)
- epsilon_{g,m} are algorithm-independent error components (~40,000 total)
- F_{g,m} is the subset of frequencies relevant to gate g and mechanism m
- D = characterization data (flux-sensitivity spectra, T1 spectra, parasitic coupling params, pulse distortion params)
- Evaluator runs ~100 times/sec on desktop

**Four error mechanisms** (set M):
1. **Dephasing**: Increases at lower frequencies where flux sensitivity grows. Formula: 1/T_phi proportional to d(omega)/d(Phi). Biases qubits toward max frequency (sweet spot).
2. **Relaxation**: Peaks at TLS defect hotspots. Measured via energy-relaxation rate spectra. Biases qubits away from hotspots.
3. **Stray coupling**: During frequency collisions between parasitically coupled elements. Disperses qubits to avoid collisions.
4. **Pulse distortion**: During large frequency excursions. Biases idles toward a multi-layered checkerboard pattern near CZ resonances.

**16 trainable weights**:
- Reduced from many potential weights via homogeneity and symmetry assumptions
- Single-qubit and two-qubit gate weights parameterized separately
- Symmetric treatment of equivalent qubits/interactions
- Trained on ~6,500 CZXEB benchmarks across configurations of variable complexity
- Designed to reduce overfitting risk
- Predicts CZXEB cycle errors within two factors of experimental uncertainty

**Scope parameter S** (controls greediness):
- S ranges from 1 (local) to S_max ~ sqrt(3N) (global)
- |F_S| ~ S^2 frequencies optimized per step
- Splits one 3N-dimensional problem into ~3N/S^2 subproblems of ~k^(S^2) configs each
- S=2 (<=5D): best balance of performance and runtime (~130 seconds for N=68)
- S=4 (<=21D): best performance but longer runtime
- S=1 (local): poor performance, large outliers
- S=S_max (global): underperforms even after >6,500 seconds

**Graph traversal** (from the whitepaper pseudocode):
- Parameters mapped to graph nodes/edges
- Three distance parameters: d_P (parameter), d_T (traversal), d_R (constraint)
- X_g^d = set of graph elements within d edge-traversals of g
- Algorithm: calibrate_thread recursively traverses graph, optimizing local subsets
- Multiple seeds launched in parallel; traversal similar to the arcade game Snake

**Healing**: Surgically re-optimizes performance outliers. Suppresses outliers by ~48%. >10x faster than full re-optimization. Uses the same Algorithm 1 without modification.

**Stitching**: Splits processor into R disjoint regions, optimizes in parallel. Reduces runtime to sub-linear scaling. Risk: outliers at region boundaries ("seams"), but experiments show seams are not substantially amplified.

**Simulation environment**: Generative model produces simulated processors of arbitrary size (tested N=17 to 1057). Reproduces saturation trends from experimental data.

### What Is NOT Disclosed

1. **Inner-loop optimizer**: The paper states "optimize_error_model" but gives ZERO detail on whether this is exhaustive enumeration, gradient descent, CMA-ES, or something else.
2. **Exact error component formulas**: Only described qualitatively; no mathematical expressions for individual epsilon_{g,m} terms.
3. **Weight training loss function**: Not specified -- only that it predicts CZXEB errors.
4. **Frequency discretization details**: Only "k~10^2" with no specification of how frequency space is partitioned.
5. **Complete constraint set**: Not mathematically formalized.
6. **Patent details**: Referenced US16/434,513 but not publicly accessible in full detail.

---

## 2. Gradient-Free Optimization for Quantum Devices

### CMA-ES
- Successfully applied to closed-loop experimental optimization of quantum gates on superconducting transmons
- Noise-resilient and time-efficient; optimizes a population of normally distributed candidate solutions
- Demonstrated with up to 55 parameters using restless measurements
- **Recommended for inner loop** when subproblem dimension is moderate (5-21D for S=2 to S=4)

### Nelder-Mead
- Fast convergence for small dimensions but heavily affected by noise
- Best for speed and accuracy in specific tasks (e.g., Bell inequality violations)
- Degrades with even slight noise levels
- **Not recommended** for noisy quantum objectives unless noise is very low

### COBYLA
- Deterministic; poor at handling noisy observations
- Significantly impacted by noise
- **Not recommended** for noisy quantum calibration

### Bayesian Optimization
- DARBO (double adaptive-region Bayesian optimization) outperforms conventional optimizers
- Gaussian Process surrogates provide uncertainty quantification
- Graph-based BO with GNN surrogates for architecture search
- Robust to noise through GP surrogate models within adaptive trust regions
- **Highly recommended** for sample-efficient exploration

### Reinforcement Learning
- Multi-objective deep RL for multi-process quantum optimal control
- Demonstrated 3.5-fold improvement in logical error rate stability
- Considers multiple fidelity objectives simultaneously

### Proposed Inner-Loop Algorithm

Given the Snake's constraints (k~100 options per frequency, S^2 ~ 4-21 dimensions per subproblem):

```
INNER_LOOP_OPTIMIZER(F_S, F_fixed, error_model, k, constraints):
  # For S=2: ~4 frequencies, k~100 options => k^4 = 10^8 configs
  # This is borderline for exhaustive search but feasible if error_model is fast (~100 evals/sec)
  # For S=4: ~16-21 frequencies => exhaustive search impossible

  if |F_S| <= 5:
    # EXHAUSTIVE ENUMERATION (brute-force over discretized grid)
    best_cost = infinity
    for each config in product(freq_options, repeat=|F_S|):
      if satisfies_constraints(config, F_fixed):
        cost = error_model(config, F_fixed)
        if cost < best_cost:
          best_cost = cost
          best_config = config
    return best_config
  else:
    # CMA-ES or Bayesian Optimization for larger subproblems
    optimizer = CMA_ES(sigma=freq_range/4, popsize=4+3*ln(|F_S|))
    for generation in range(max_generations):
      candidates = optimizer.ask()
      costs = [error_model(c, F_fixed) for c in candidates if satisfies_constraints(c, F_fixed)]
      optimizer.tell(candidates, costs)
    return optimizer.best()
```

**Key insight**: For S=2 (the recommended default), |F_S|~4 and k~100 gives 10^8 configurations. At 100 evaluations/sec, exhaustive search takes ~10^6 seconds -- too slow. But with constraints pruning most configurations, the effective search space may be much smaller. More likely, Google uses **dynamic programming on the discretized grid** (consistent with the paper mentioning "dynamic programming" as a key concept) or a **branch-and-bound** approach that exploits the graph structure to prune infeasible regions.

**Alternative proposal: Dynamic programming on the graph**:
```
DP_INNER_LOOP(graph_neighborhood, freq_options, error_model):
  # Process nodes in topological order along the Snake's path
  # For each node, maintain a table of best partial costs
  # Key: frequency assignment for already-processed nodes
  # Value: minimum cost

  for each node v in traversal_order:
    for each freq_option f_v in freq_options[v]:
      if violates_hard_constraints(f_v, assigned_neighbors):
        continue
      partial_cost = sum of error components involving v and assigned neighbors
      dp_table[v][f_v] = min over compatible predecessor states of (
        dp_table[predecessor] + partial_cost
      )
  return backtrack(dp_table)
```

---

## 3. Frequency Collision Avoidance Rules

### For Fixed-Frequency Cross-Resonance Architecture (IBM-style)

Nine constraint families from Wen et al. (Phys. Rev. A 111, 012619, 2025):

| Constraint | Condition | Bound (MHz) |
|-----------|-----------|-------------|
| A1 | \|f_i - f_j\| >= delta | 17 |
| A2 | \|f_i - f_j - alpha\| >= delta | 30 |
| E1 | \|f_d - f_i\| >= delta | 17 |
| E2 | \|f_d - f_i - alpha\| >= delta | 30 |
| D1 | \|f_d - f_i - alpha/2\| >= delta | 2 |
| S1 | \|f_d - f_k\| >= delta | 17 |
| S2 | \|f_d - f_k - alpha\| >= delta | 25 |
| T1 | \|f_d + f_k - 2f_i - alpha\| >= delta | 17 |

Where alpha = -350 MHz (anharmonicity), f_d = drive frequency, f_k = spectator qubit frequency.

### For Frequency-Tunable (Google Sycamore-style)

Key collision types for CZ gates via |11>-|02> avoided crossing:

1. **iSWAP resonance (01-10)**: |f_01^i - f_01^j| must be large enough to avoid unwanted SWAP. The CZ trajectory must stay below this avoided crossing.

2. **CZ resonance (11-02)**: f_interaction is chosen near the |11>-|02> avoided crossing. For qubit i with anharmonicity alpha_i:
   ```
   f_CZ_ij ~ f_01^j + alpha_j   (when qubit j visits |2>)
   ```

3. **Stray coupling collisions**: For parasitically coupled (non-nearest-neighbor) qubits, frequency collisions occur when:
   ```
   |f_idle^i - f_idle^k| < delta_stray     (for NNN qubits i,k)
   |f_idle^i - f_interaction^jk| < delta_stray
   |f_interaction^ij - f_interaction^kl| < delta_stray
   ```

4. **Spectator collisions**: During CZ_ij, spectator qubit k must satisfy:
   ```
   |f_interaction^ij - f_01^k| >> g_parasitic
   |f_interaction^ij - f_12^k| >> g_parasitic
   ```

### For Parametrically Modulated Systems

Nine primary transitions (from analysis of parametric collisions, arXiv:2511.05031):

**Co-rotating**: |01>-|10> (detuning Delta), |11>-|02> (Delta + alpha_2), |11>-|20> (Delta - alpha_1)

**Counter-rotating**: |00>-|11>, |01>-|12>, and higher combinations

Population error near collision: P_e = sum_i,n (2*g_eff^(n))^2 / ((2*g_eff^(n))^2 + Delta_{i,n}^2)

### Checkerboard Pattern

Idle frequencies are assigned in a checkerboard pattern of high/low values on the 2D lattice. This ensures nearest neighbors always have different idle frequencies. The interaction frequencies are assigned near the CZ resonances. The Snake paper mentions a "multi-layered checkerboard" with neighbors at one of two symmetric |11>-|02> CZ resonances.

---

## 4. Error Model Training

### Snake's Approach
- 16 trainable weights over ~40,000 error components
- Trained on ~6,500 CZXEB benchmarks
- Homogeneity + symmetry constraints reduce parameter count
- Training exploits frequency tunability to sample diverse configurations
- Goal: predict CZXEB cycle errors across the processor

### Sparse Pauli-Lindblad Noise Models (IBM)
- Model: Lambda(rho) = exp[L]rho, Lindbladian decomposed into simple Pauli channels
- Sparsity: restrict to one- and two-local Pauli terms following qubit topology
- Learning: nonnegative least-squares fitting from cycle benchmarking
  ```
  minimize ||M(B,K)*lambda + log(f_hat)/2||
  subject to: lambda >= 0
  ```
- Parameter count scales linearly with qubit count
- Requires ~9 measurement bases for representative topologies

### AlphaQubit Decoder Training
- Pretraining on up to 2 billion samples from detector error noise models
- DEMs fitted to detection error event correlations
- Weights derived from Pauli noise model approximating hardware noise
- Based on cross-entropy benchmark calibration data

### Proposed Weight Training Procedure

```
TRAIN_WEIGHTS(processor, num_benchmarks=6500):
  # Phase 1: Collect training data
  training_data = []
  for i in range(num_benchmarks):
    F_config = sample_diverse_configuration(processor)
    set_frequencies(processor, F_config)
    xeb_errors = run_CZXEB(processor)  # per-pair cycle errors
    training_data.append((F_config, xeb_errors))

  # Phase 2: Compute error components (algorithm-independent)
  for (F, xeb) in training_data:
    for each gate g:
      for each mechanism m in {dephasing, relaxation, stray_coupling, pulse_distortion}:
        epsilon[g,m] = compute_error_component(F, g, m, characterization_data)

  # Phase 3: Train weights via regularized regression
  # The predicted error for config F at gate g is:
  #   E_pred(g) = sum_m w_{type(g),m} * epsilon_{g,m}(F)
  # where type(g) reduces via symmetry (all SQ gates same type,
  # all CZ gates same type, by direction, by sublattice, etc.)

  # With 16 weights and ~40,000 components, this is heavily overconstrained
  # Loss: minimize sum over benchmarks of (E_pred - E_measured)^2
  # with regularization to prevent overfitting

  # Symmetry constraints that reduce to 16 weights:
  # - All SQ idle gates share weights (4 mechanisms => 4 weights)
  # - All CZ gates share weights (4 mechanisms => 4 weights)
  # - Gate-type dependent scaling (e.g., SQ during CZ layer vs standalone)
  #   => another 4+4 = 8 weights
  # Total: 16 weights

  weights = scipy.optimize.minimize(
    loss_function, x0=initial_weights,
    method='L-BFGS-B',  # or trust-constr
    bounds=[(0, None)] * 16  # weights non-negative
  )
  return weights
```

### Why 16 Weights Work

The key insight is **homogeneity and symmetry**: on a regular 2D lattice, all qubits/couplers of the same sublattice type experience statistically similar error mechanisms. The ~40,000 error *components* capture the physics (they are computed from characterization data), while the 16 *weights* capture how these components combine for a specific algorithm. This is analogous to a linear model with many features but few distinct coefficient classes.

The structure is likely:
- 4 mechanisms x 2 gate types (SQ, CZ) = 8 base weights
- 2 context-dependent variants (e.g., gate during parallel operation vs. isolated) x 4 mechanisms = 8 more weights
- Total: 16

---

## 5. Graph-Based Optimization Formulations

### Graph Coloring for Frequency Assignment
- Qubits = vertices, couplings = edges
- Idle frequencies: bipartite coloring (checkerboard) for 2D mesh
- Interaction frequencies: 8-coloring needed for 2D mesh to avoid all simultaneous gate conflicts
- SMT solvers (e.g., Z3) and MIP solvers (e.g., CPLEX) used for constraint satisfaction

### Mixed-Integer Programming (Wen et al., 2025)
- Decision variables: qubit frequencies f_i + binary orientation variables o(i,j)
- Objective: maximize sum of slack variables over all constraint types
- Edgewise difference constraint: ||f_k1 - f_k2| - |f_l1 - f_l2|| < delta_diff
- Solved with CPLEX MIP solver
- Scales to 1024 qubits with 10% yield at sigma=6.5 MHz dispersion

### Snake's Graph Formulation
- Nodes: individual frequency variables (idle frequencies, interaction frequencies)
- Edges: physical couplings and constraint dependencies
- Traversal: Snake moves along the graph, optimizing S^2-sized neighborhoods
- Previously optimized frequencies become fixed constraints for subsequent neighborhoods

### Proposed Graph Algorithm

```
SNAKE_TRAVERSE(graph, scope_S, error_model, seeds):
  # Initialize
  optimized = {}  # frequency -> optimal value
  threads = []

  for seed in seeds:
    thread = Thread(target=snake_thread, args=(
      graph, seed, scope_S, error_model, optimized
    ))
    threads.append(thread)
    thread.start()

  for thread in threads:
    thread.join()

  return optimized

def snake_thread(graph, current_node, S, error_model, optimized):
  visited = set()

  while True:
    # Find unoptimized neighbors within scope S
    neighborhood = get_neighborhood(graph, current_node, S)
    unoptimized = [n for n in neighborhood if n not in optimized]

    if not unoptimized:
      break

    # Construct local estimator E_S
    F_S = unoptimized  # variables to optimize
    F_fixed = {n: optimized[n] for n in neighborhood if n in optimized}

    # E_S = all error terms that depend only on F_S and F_fixed
    E_S = extract_local_estimator(error_model, F_S, F_fixed)

    # Solve subproblem
    F_S_optimal = inner_loop_solve(E_S, F_S, F_fixed, constraints)

    # Update optimized frequencies
    for node, freq in zip(F_S, F_S_optimal):
      optimized[node] = freq

    # Traverse to next node (heuristic: choose neighbor with most unoptimized connections)
    visited.add(current_node)
    candidates = [n for n in graph.neighbors(current_node)
                  if n not in visited and n.type == current_node.type]
    if not candidates:
      break
    current_node = max(candidates, key=lambda n: count_unoptimized_neighbors(n, optimized))
```

---

## 6. Alternative Frequency Optimizers

### Neural Network-Based (arXiv:2412.01183)
- MLP with position embedding predicts per-gate error from all qubit frequencies
- Iterative local window optimization: identify highest-error window, optimize within it
- No need for predetermined separation distances
- Captures nonlinear interactions between error mechanisms
- Fewer than 6,500 configurations needed for training

### GNN-Based Scalable Design (arXiv:2411.16354, PRL 2025)
- Three-stair scaling: train evaluator on small circuits, designer on medium circuits, deploy on large circuits
- Evaluator: supervised MLP per gate type, predicts crosstalk errors
- Designer: unsupervised GNN+MLP, outputs frequency assignments
- **Results: 51% of Snake's errors in 27 seconds vs. 90 minutes (870 qubits)**
- Loss: L = w_X * E_RX + w_Y * E_RY + w_XY * E_RXY

### MIP-Based (Wen et al., Phys. Rev. A 111, 012619, 2025)
- Mixed-integer programming with CPLEX solver
- Nine constraint families with explicit MHz bounds
- Modular design for 1000+ qubit processors
- Code available: https://github.com/AlvinZewen/SC_Freq_Allo

### Laser Annealing (LASIQ, Science Advances 2022)
- Post-fabrication frequency tuning via selective laser annealing
- 18.5 MHz tuning precision, no impact on coherence
- Enables collision-free lattices for fixed-frequency architectures

### Multi-Objective Deep RL (Scientific Reports, 2024)
- Considers multiple fidelity objectives simultaneously
- Gives global optimal solution considering multiple error sources
- Successfully applied to 1-qubit model

---

## 7. XEB-Based Training

### Linear XEB Fidelity Formula
```
f = sum_U (m_U - u_U)(e_U - u_U) / sum_U (e_U - u_U)^2
```
Where:
- m_U = experimental estimate of Tr(rho_U * O_U)
- e_U = ideal expectation <psi_U|O_U|psi_U> = sum of squared ideal probabilities
- u_U = Tr(O_U/D) = normalization factor
- f = circuit fidelity

### Depolarizing Model
```
rho_U = f * |psi_U><psi_U| + (1-f) * I/D
e_depol = E_PAULI / (1 - 1/D^2)
```
Fidelity decays exponentially with cycle depth: f ~ (1 - e_depol)^(4d)

### CZXEB Protocol (as used in Snake training)
- Cycles of parallel SQ gates followed by parallel CZ gates
- Structure reflects surface code parity checks
- Per-pair errors e_{c,ij} extracted from exponential decay fits
- Reported as percentile boxplots (2.5%-97.5% range ~ +/-2 sigma)
- Empirically correlates with logical error rates

### Using XEB as Cost Function

```
XEB_COST_FUNCTION(F_config, processor):
  set_frequencies(processor, F_config)

  # Run CZXEB at multiple depths
  for depth d in [2, 4, 8, 12, 16]:
    for trial in range(num_random_circuits):
      circuit = random_CZXEB_circuit(depth=d)
      ideal_probs = classical_simulate(circuit)
      measured_counts = run_on_hardware(circuit, shots=1000)
      measured_probs = counts_to_probs(measured_counts)
      # Accumulate XEB statistics

  # Fit exponential decay to extract per-layer fidelity
  layer_fidelity = fit_exponential_decay(xeb_data_vs_depth)

  # Extract per-gate errors
  per_gate_errors = -log(layer_fidelity) / num_gates_per_layer

  return sum(per_gate_errors)  # or median, or worst-case
```

---

## 8. Dynamic Programming on Processor Graphs

### Relevance to Snake

The Snake paper explicitly cites "dynamic programming" as a core concept. The key connection:

**Tree-like subproblems**: When the Snake traverses the processor graph with scope S, the local neighborhood often forms a tree or near-tree structure (especially at the boundary of optimized/unoptimized regions). On trees, dynamic programming gives exact solutions in O(k * n) time rather than O(k^n).

### Belief Propagation (Message Passing)

For loopy graphs (which processor lattices are), **loopy belief propagation** approximates the marginal distributions:

```
BP_FREQUENCY_ASSIGNMENT(graph, freq_options, error_model, max_iter=100):
  # Initialize messages
  for each edge (i,j) in graph:
    message[i->j] = uniform over freq_options[j]

  for iteration in range(max_iter):
    for each edge (i,j) in graph:
      # Update message from i to j
      for f_j in freq_options[j]:
        message[i->j][f_j] = sum over f_i of (
          compatibility(f_i, f_j) *  # pairwise error/constraint
          product over k!=j of message[k->i][f_i]  # incoming messages
        )
      normalize(message[i->j])

  # Extract marginals and MAP assignment
  for each node i:
    belief[i] = product over j of message[j->i]
    optimal_freq[i] = argmax(belief[i])

  return optimal_freq
```

### Min-Sum Algorithm (for MAP estimation)

```
MIN_SUM_FREQUENCY(graph, freq_options, error_components):
  # Like max-product BP but in log domain for MAP estimation
  for each edge (i,j):
    mu[i->j][f_j] = 0  # initialize messages

  for iteration in range(max_iter):
    for each node i:
      for each neighbor j of i:
        for f_j in freq_options[j]:
          mu[i->j][f_j] = min over f_i of (
            local_error(i, f_i) +
            pairwise_error(i, j, f_i, f_j) +
            sum over k!=j of mu[k->i][f_i]
          )

  # Decode
  for each node i:
    total_msg[f_i] = local_error(i, f_i) + sum over j of mu[j->i][f_i]
    optimal[i] = argmin over f_i of total_msg[f_i]

  return optimal
```

---

## 9. Crosstalk Modeling

### ZZ Coupling Formula (from arXiv:2512.18148)

```
zeta_ij = 2*(alpha_i + alpha_j) * J_ij^2 / ((Delta_ij + alpha_i)*(Delta_ij - alpha_j))
```
Where:
- zeta_ij = static ZZ interaction strength
- alpha_i, alpha_j = transmon anharmonicities (~-200 MHz)
- J_ij = exchange coupling
- Delta_ij = frequency detuning

### Spatial Scaling

Coupling decays exponentially with distance:
- NN (distance 1): ~8 kHz ZZ after outlier removal (in test device)
- NNN (distance 2): ~5 kHz (70% reduction)
- Distance 3: ~2.5 kHz
- Fit: <zeta> proportional to exp(-D/0.83) where D is in lattice sites

### Capacitance Matrix Model

```
H_circuit = sum 4*E_{C,ij}*(n_i - n_{g,i})*(n_j - n_{g,j}) + sum E_{J,i}*cos(phi_i)
```

Critical insight: C is sparse (NN coupling only) but C^{-1} is dense, introducing long-range interactions. However, off-diagonal elements decay exponentially:
```
|(C^{-1})_ij| <= c * rho^(|i-j|/w)
```
where rho in (0,1).

### Direct coupling formula
```
g_ij = (E_{C,ij} / (4*E_{C,i}*E_{C,j})^{1/4}) * (E_{J,i}*E_{J,j})^{1/4}
```

### Enclosure-mediated (evanescent) coupling
```
G_ij = J_0^{env} * K_0(kappa * d_ij)
```
where K_0 is modified Bessel function, kappa = evanescent wavenumber below cutoff.

### Processor-Scale Crosstalk Model

```
CROSSTALK_MODEL(processor_graph, freq_assignment):
  total_error = 0
  for each qubit pair (i, j) within interaction range:
    delta_ij = freq_assignment[i] - freq_assignment[j]
    J_ij = coupling_strength(i, j, processor_graph)

    # Static ZZ
    zz = 2 * (alpha_i + alpha_j) * J_ij^2 / ((delta_ij + alpha_i) * (delta_ij - alpha_j))

    # Error contribution proportional to zz * gate_time
    total_error += abs(zz) * gate_duration

  return total_error
```

---

## 10. Reproducibility Attempts

### No Direct Reproductions Found

No published work explicitly attempts to reproduce the Snake optimizer. The algorithm is proprietary to Google Quantum AI, with key details deferred to patents (US16/434,513).

### Closest Alternatives

1. **GNN-based approach (PRL 2025)**: Achieves 51% of Snake's error at 0.5% of runtime. The most competitive alternative. Uses a fundamentally different approach (learned surrogate + gradient-based optimization rather than graph traversal + analytical model).

2. **Neural network MLP approach (CPL 2025)**: Also uses learned surrogate models. Validates on smaller processors.

3. **MIP-based approach (PRA 2025)**: For fixed-frequency architectures only. Uses CPLEX solver with explicit constraint formulation. Code available on GitHub.

---

## 11. Weight Learning Details

### How 16 Weights Cover ~40,000 Components

The decomposition exploits three symmetry principles:

1. **Homogeneity**: All qubits of the same sublattice type are treated identically. On a checkerboard lattice, there are ~2 sublattice types.

2. **Gate-type symmetry**: All SQ gates share the same weight vector; all CZ gates share the same weight vector.

3. **Mechanism independence**: Each of 4 error mechanisms gets its own weight per gate type.

**Likely weight structure** (4 mechanisms x 4 contexts = 16):

| Weight | Mechanism | Context |
|--------|-----------|---------|
| w1 | Dephasing | SQ idle (during SQ layer) |
| w2 | Relaxation | SQ idle (during SQ layer) |
| w3 | Stray coupling | SQ idle (during SQ layer) |
| w4 | Pulse distortion | SQ idle (during SQ layer) |
| w5 | Dephasing | SQ idle (during CZ layer) |
| w6 | Relaxation | SQ idle (during CZ layer) |
| w7 | Stray coupling | SQ idle (during CZ layer) |
| w8 | Pulse distortion | SQ idle (during CZ layer) |
| w9 | Dephasing | CZ interaction |
| w10 | Relaxation | CZ interaction |
| w11 | Stray coupling | CZ interaction |
| w12 | Pulse distortion | CZ interaction |
| w13-16 | Context-dependent adjustments (e.g., boundary vs. bulk qubits, different CZ directions) |

### Analogous Sparse Models in Literature

**Sparse Pauli-Lindblad** (IBM, Nature Physics 2023): Parameters scale linearly with qubits. One- and two-local Pauli terms following topology. Learned via nonneg least-squares from cycle benchmarking.

**Fast Estimation of Sparse Quantum Noise** (PRX Quantum 2021): Estimates s nonzero Pauli error rates using O(n^2) measurements and O(sn^2) classical processing.

**Machine learning for error mitigation** (Nature Machine Intelligence 2024): Linear regression, random forests, MLPs, and GNNs benchmarked on up to 100 qubits. Lasso regression with regularization controls sparsity.

### Proposed Training Algorithm

```
TRAIN_SNAKE_WEIGHTS(processor, D_char, num_configs=6500):
  """
  Train 16 weights for the Snake error model.

  D_char: characterization data (T1 spectra, flux sensitivity,
          parasitic couplings, pulse distortion params)
  """

  # 1. Define weight structure via symmetry
  W = np.zeros(16)  # 4 mechanisms x 4 gate contexts

  # 2. Collect diverse training configurations
  configs = []
  for _ in range(num_configs):
    # Use frequency tunability to explore configuration space
    F = sample_configuration(processor, strategy='diverse')
    set_frequencies(processor, F)
    xeb_results = run_CZXEB_benchmark(processor)
    configs.append((F, xeb_results))

  # 3. Compute all error components
  epsilon = {}  # (config_idx, gate, mechanism) -> error value
  for idx, (F, _) in enumerate(configs):
    for gate g in all_gates:
      epsilon[idx, g, 'dephasing'] = compute_dephasing(F, g, D_char)
      epsilon[idx, g, 'relaxation'] = compute_relaxation(F, g, D_char)
      epsilon[idx, g, 'stray'] = compute_stray_coupling(F, g, D_char)
      epsilon[idx, g, 'distortion'] = compute_pulse_distortion(F, g, D_char)

  # 4. Fit weights to minimize prediction error
  def loss(W):
    total = 0
    for idx, (F, xeb_measured) in enumerate(configs):
      for gate g in all_gates:
        context = get_gate_context(g)  # returns 0-3 for which weight set
        E_pred = sum(W[4*context + m] * epsilon[idx, g, mechanism_list[m]]
                     for m in range(4))
        E_meas = xeb_measured[g]
        total += (E_pred - E_meas)**2
    return total / len(configs)

  # 5. Optimize with bounds (weights >= 0)
  from scipy.optimize import minimize
  result = minimize(loss, W, method='L-BFGS-B',
                    bounds=[(0, None)] * 16)

  # 6. Cross-validate
  train_set, test_set = split(configs, ratio=0.8)
  train_loss = evaluate(result.x, train_set, epsilon)
  test_loss = evaluate(result.x, test_set, epsilon)
  assert test_loss < 2 * train_loss, "Overfitting detected"

  return result.x
```

---

## 12. Scope Parameter Analysis

### Why Intermediate Scope Outperforms

**Local (S=1) fails because**:
- Cannot make tradeoffs between interacting gates
- Neighboring frequency choices are coupled through stray interactions
- Optimizing one gate in isolation may worsen its neighbors
- Results in many large outliers

**Global (S=S_max) fails because**:
- Search space grows as k^{S^2} ~ k^{3N}
- For N=68 and k=100: ~10^{354} configurations -- astronomically large
- Even sophisticated optimizers get trapped in local minima in such high dimensions
- Runtime: >6,500 seconds with poor results

**Intermediate (S=2-4) succeeds because**:
- Physical interactions are predominantly local (engineered NN + parasitic NNN)
- Crosstalk coupling decays exponentially with distance (characteristic length ~0.83 lattice sites)
- S=2 captures NN interactions; S=4 captures most NNN interactions
- Problem decomposes naturally into weakly-coupled subproblems
- The "seam" errors between independently-optimized regions are small due to exponential decay

### Theoretical Framework

The success of intermediate scope connects to:

1. **Exponential decay of correlations**: ZZ coupling ~ exp(-D/0.83) means that qubits >2 sites apart interact very weakly. This makes the optimization problem approximately decomposable.

2. **Block coordinate descent theory**: Optimizing blocks of size S^2 while fixing others converges if the coupling between blocks is weak relative to within-block coupling. The exponential decay ensures this condition.

3. **Computational complexity**: S=2 gives ~5D subproblems with ~10^{10} configurations each. With constraint pruning and fast evaluator (100 evals/sec), each subproblem is solvable in seconds.

---

## Complete Proposed Implementation

### Architecture Overview

```
class SnakeOptimizer:
    def __init__(self, processor_graph, characterization_data, scope=2):
        self.graph = processor_graph
        self.D = characterization_data
        self.scope = scope
        self.weights = None  # trained separately

    def build_error_model(self):
        """Construct the error estimator from characterization data."""
        self.error_components = {}
        for node in self.graph.nodes:
            for mechanism in ['dephasing', 'relaxation', 'stray', 'distortion']:
                self.error_components[node, mechanism] = (
                    self._compute_component_function(node, mechanism, self.D)
                )

    def _compute_component_function(self, node, mechanism, D):
        """Return a callable that maps frequency -> error contribution."""
        if mechanism == 'dephasing':
            # epsilon_dephasing(f) ~ |d_omega/d_Phi(f)| / omega_qubit
            # Use flux sensitivity spectrum from D
            return lambda f: interp1d(D.flux_sensitivity_spectrum)(f)

        elif mechanism == 'relaxation':
            # epsilon_relaxation(f) ~ 1/T1(f)
            # Use T1 spectrum from D, with TLS hotspots
            return lambda f: 1.0 / interp1d(D.t1_spectrum)(f)

        elif mechanism == 'stray':
            # epsilon_stray(f_i, f_j, ...) ~ sum_k g_ik^2 / delta_ik^2
            # for all parasitically coupled qubits k
            return lambda f_set: sum(
                D.parasitic_coupling[i,k]**2 / (f_set[i] - f_set[k])**2
                for k in D.parasitic_neighbors[node]
                if abs(f_set[i] - f_set[k]) > 1e-6
            )

        elif mechanism == 'distortion':
            # epsilon_distortion(f_idle, f_interaction) ~ |f_idle - f_interaction| * distortion_coeff
            return lambda f_idle, f_int: abs(f_idle - f_int) * D.distortion_params[node]

    def evaluate(self, F):
        """Evaluate total error for frequency configuration F."""
        total = 0
        for gate in self.graph.gates:
            for m_idx, mechanism in enumerate(['dephasing', 'relaxation', 'stray', 'distortion']):
                context = self._get_context(gate)
                w = self.weights[4 * context + m_idx]
                eps = self.error_components[gate.node, mechanism](F)
                total += w * eps
        return total

    def optimize(self, seeds=None, num_threads=4):
        """Run Snake optimization."""
        if seeds is None:
            seeds = self._select_seeds(num_threads)

        optimized = {}

        # Launch threads from seeds
        for seed in seeds:
            self._snake_thread(seed, optimized)

        # Healing pass
        self._heal(optimized)

        return optimized

    def _snake_thread(self, seed, optimized):
        """Single Snake traversal thread."""
        current = seed
        visited = set()

        while current is not None:
            # Get neighborhood within scope
            neighborhood = self._get_neighborhood(current, self.scope)
            to_optimize = [n for n in neighborhood if n not in optimized]

            if not to_optimize:
                current = self._next_unvisited(current, visited, optimized)
                continue

            # Build local estimator
            fixed = {n: optimized[n] for n in neighborhood if n in optimized}

            # Solve subproblem
            best_config = self._solve_subproblem(to_optimize, fixed)

            # Update
            for node, freq in zip(to_optimize, best_config):
                optimized[node] = freq

            visited.add(current)
            current = self._next_node(current, visited, optimized)

    def _solve_subproblem(self, variables, fixed):
        """Inner-loop solver for scope-bounded subproblem."""
        dim = len(variables)

        if dim <= 5:
            # Small enough for exhaustive/DP approach
            return self._dp_solve(variables, fixed)
        else:
            # Use CMA-ES for larger subproblems
            return self._cmaes_solve(variables, fixed)

    def _dp_solve(self, variables, fixed):
        """Dynamic programming on the local subgraph."""
        # Discretize frequency options
        freq_options = self._get_freq_options(variables)  # k~100 per variable

        # Order variables along the Snake's path
        ordered = self._topological_order(variables)

        # DP tables
        dp = [{} for _ in ordered]

        for v_idx, var in enumerate(ordered):
            for f in freq_options[var]:
                if self._violates_constraints(var, f, fixed):
                    continue

                local_cost = self._local_error(var, f, fixed)

                if v_idx == 0:
                    dp[v_idx][f] = (local_cost, None)
                else:
                    best_prev_cost = float('inf')
                    best_prev_freq = None
                    for f_prev, (cost_prev, _) in dp[v_idx - 1].items():
                        pair_cost = self._pairwise_error(
                            ordered[v_idx-1], f_prev, var, f
                        )
                        total = cost_prev + local_cost + pair_cost
                        if total < best_prev_cost:
                            best_prev_cost = total
                            best_prev_freq = f_prev
                    dp[v_idx][f] = (best_prev_cost, best_prev_freq)

        # Backtrack
        return self._backtrack(dp, ordered, freq_options)

    def _heal(self, optimized):
        """Heal performance outliers."""
        errors = self._evaluate_per_gate(optimized)
        threshold = np.percentile(list(errors.values()), 95)

        outlier_gates = [g for g, e in errors.items() if e > threshold]

        for gate in outlier_gates:
            # Re-optimize just this gate's frequencies
            neighborhood = self._get_neighborhood(gate, self.scope)
            to_optimize = list(neighborhood)
            fixed = {n: optimized[n] for n in self.graph.nodes
                     if n not in neighborhood and n in optimized}

            new_config = self._solve_subproblem(to_optimize, fixed)
            for node, freq in zip(to_optimize, new_config):
                optimized[node] = freq
```

---

## Key References

### Primary Snake Papers
1. Klimov et al., "The Snake Optimizer for Learning Quantum Processor Control Parameters," arXiv:2006.04594 (2020)
2. Klimov et al., "Optimizing quantum gates towards the scale of logical qubits," Nature Communications 15, 2442 (2024)

### Frequency Collision Rules
3. Wen et al., "Efficient frequency allocation for superconducting quantum processors using improved optimization techniques," Phys. Rev. A 111, 012619 (2025) -- GitHub: https://github.com/AlvinZewen/SC_Freq_Allo
4. Berke et al., "Mitigation of frequency collisions in superconducting quantum processors," Phys. Rev. Research 5, 043001 (2023)

### Alternative Optimizers
5. Neural network-based frequency optimization, arXiv:2412.01183 (2024)
6. GNN-based scalable parameter design, arXiv:2411.16354 (PRL 2025) -- achieves 51% of Snake's error at 0.5% runtime
7. MIP-based frequency allocation, Phys. Rev. A 111, 012619 (2025)

### Crosstalk and ZZ Modeling
8. "Crosstalk dispersion and spatial scaling in superconducting qubit arrays," arXiv:2512.18148 (2025)
9. "Cross-talk in superconducting qubit lattices with tunable couplers," arXiv:2504.10298 (2025)
10. "Analysis of frequency collisions in parametrically modulated superconducting circuits," arXiv:2511.05031 (2025)

### Noise Models
11. "Probabilistic error cancellation with sparse Pauli-Lindblad models," Nature Physics (2023)
12. "Techniques for learning sparse Pauli-Lindblad noise models," Quantum (2024)
13. "Fast estimation of sparse quantum noise," PRX Quantum 2, 010322 (2021)

### Gradient-Free Optimization
14. CMA-ES for quantum gate optimization -- multiple papers via Nature/npj Quantum Information
15. Bayesian optimization for quantum calibration -- arXiv:2304.12923

### CZ Gate Physics
16. "Optimization of flux trajectories for adiabatic CZ gate," AIP Advances 12, 095306 (2022)

### XEB Theory
17. Google Cirq XEB Theory documentation: https://quantumai.google/cirq/noise/qcvv/xeb_theory

### Error Correction and Decoders
18. AlphaQubit: "Learning high-accuracy error decoding for quantum processors," Nature (2024)
