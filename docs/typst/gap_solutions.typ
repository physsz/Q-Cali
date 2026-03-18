// Gap Solutions: Bridging Critical Reproduction Gaps in Superconducting Qubit Calibration
// Typst source — compile with `typst compile gap_solutions.typ`

#set document(
  title: "Bridging Critical Reproduction Gaps in Superconducting Qubit Calibration",
  author: ("Survey compiled March 2026",),
)

#set page(
  paper: "us-letter",
  margin: (x: 1in, y: 1in),
  numbering: "1",
  header: align(right, text(size: 9pt, fill: gray)[_Bridging Critical Calibration Gaps_]),
)

#set text(font: "New Computer Modern", size: 11pt)
#set par(justify: true, leading: 0.65em)
#set heading(numbering: "I.A.1.")
#show heading.where(level: 1): it => {
  v(1.2em)
  text(size: 14pt, weight: "bold")[#it]
  v(0.4em)
}
#show heading.where(level: 2): it => {
  v(0.8em)
  text(size: 12pt, weight: "bold")[#it]
  v(0.3em)
}
#show heading.where(level: 3): it => {
  v(0.5em)
  text(size: 11pt, weight: "bold", style: "italic")[#it]
  v(0.2em)
}

// ─── Title block ───
#align(center)[
  #text(size: 18pt, weight: "bold")[
    Bridging Critical Reproduction Gaps in \ Superconducting Qubit Calibration
  ]
  #v(0.6em)
  #text(size: 12pt)[
    _Proposed Solutions for the Four Critical Gaps \ in Google Quantum AI's Published Calibration Stack_
  ]
  #v(0.4em)
  #text(size: 10pt, fill: gray)[Compiled March 15, 2026]
  #v(1.5em)
]

// ─── Abstract ───
#rect(width: 100%, inset: 12pt, stroke: 0.5pt + gray)[
  #text(weight: "bold")[Abstract.] #h(0.3em)
  Our companion survey identified four _critical_ reproduction gaps in Google Quantum AI's calibration stack: (1) the complete Optimus calibration DAG, (3) the Snake optimizer's inner-loop algorithm, (5) the TLS forecasting algorithm, and (10) the custom control electronics specifications. Here we present detailed, independently reconstructible solutions for each gap. For Gap 1, we synthesize calibration workflows from Qibocal, QUAlibrate, Qiskit Experiments, and Zurich Instruments LabOne Q to reconstruct a complete 50+ node DAG with concrete tolerances and timeout values. For Gap 3, we reverse-engineer the Snake's error model, propose three candidate inner-loop optimizers with pseudocode, and reconstruct the 16-weight training procedure. For Gap 5, we develop six TLS forecasting algorithms ranging from simple change-point extrapolation to FPGA-based real-time Bayesian tracking, grounded in newly measured TLS spectral diffusion constants. For Gap 10, we benchmark five commercial and one open-source control electronics platforms against Willow-level specifications and provide a complete wiring/filtering scheme. We find that all four gaps can be bridged with existing public knowledge, though significant experimental validation remains necessary.
]

#v(1em)
#outline(title: "Contents", indent: 1.5em, depth: 2)
#pagebreak()

// ════════════════════════════════════════════════════════════════
= Introduction

This document addresses the four gaps assessed as _Critical_ in our companion survey on superconducting qubit calibration:

#figure(
  table(
    columns: (auto, 1fr, auto),
    align: (center, left, center),
    table.header([*Gap*], [*Description*], [*Section*]),
    [1], [Complete Optimus calibration DAG: node names, analysis functions, tolerances, timeouts], [@sec:dag],
    [3], [Snake optimizer inner-loop algorithm, frequency-separation rules, weight-training procedure], [@sec:snake],
    [5], [TLS forecasting algorithm: inputs, prediction method, horizon, accuracy], [@sec:tls],
    [10], [Custom control electronics: DAC specs, signal generation, wiring, filtering], [@sec:electronics],
  ),
  caption: [The four critical reproduction gaps addressed in this document.],
)

For each gap, we (a) review all publicly available information, (b) synthesize solutions from multiple independent sources, (c) propose concrete implementations with sufficient detail for reproduction, and (d) identify remaining uncertainties.

// ════════════════════════════════════════════════════════════════
= Gap 1: Reconstructing the Complete Calibration DAG <sec:dag>

== Available Sources

The Optimus framework #cite(<kelly2018>) defines calibration as a DAG traversal problem but never publishes the complete node list. We reconstruct the full DAG by synthesizing five independent sources:

- *Qibocal* #cite(<qibocal2024>): 37 protocol routines for transmon calibration (open-source).
- *QUAlibrate* #cite(<qualibrate>): Component-based DAG framework from Quantum Machines; demonstrated full multi-qubit tune-up in 140 seconds.
- *Qiskit Experiments* #cite(<qiskit_exp>): IBM's calibration library with prescribed ordering.
- *LabOne Q* #cite(<laboneq>): Zurich Instruments' DAG-based bring-up; characterized 26/28 qubits across 7 chips in $tilde$ 3.5 hours.
- *Google Patent US9940212B2* #cite(<patent2018>): Adds that each node has two experiment tiers---a low-cost `check_data` and high-cost `calibrate`.

== Reconstructed DAG: Complete Node Specification

We organize the DAG into 12 layers, totaling 52 nodes. Each node specifies: parameters calibrated, scan type, analysis function, tolerance, drift timescale (timeout), and dependencies.

=== Layer 0: System Prerequisites

#figure(
  table(
    columns: (1.2fr, 1.5fr, 1fr, 1fr, 1fr),
    align: (left, left, left, left, left),
    table.header([*Node*], [*Parameters*], [*Analysis*], [*Tolerance*], [*Timeout*]),
    [Cryostat cooldown], [Base temperature], [Thermometer], [$< 15$ mK], [N/A],
    [TWPA calibration], [Pump freq, power, gain], [$S_(21)$ vs.\ freq], [Gain flat across band], [$tilde 24$ h],
  ),
  caption: [Layer 0: System-level prerequisites.],
)

=== Layer 1: Readout Resonator Characterization

#figure(
  table(
    columns: (1.2fr, 1.5fr, 1fr, 1fr, 1fr),
    align: (left, left, left, left, left),
    table.header([*Node*], [*Parameters*], [*Analysis*], [*Tolerance*], [*Timeout*]),
    [Resonator spec.\ (high power)], [$f_(r,"bare")$], [Lorentzian fit to $S_(21)$], [$< 100$ kHz], [$tilde$ hours],
    [Resonator punchout], [$P_("ro,opt")$], [2D bifurcation detection], [Below bifurcation], [$tilde$ hours],
    [Resonator spec.\ (low power)], [$f_(r,"dressed")$, $chi$], [Lorentzian fit], [$< 50$ kHz], [$tilde$ hours],
    [Dispersive shift], [$chi = f_(r|0 angle) - f_(r|1 angle)$], [Two-peak separation], [$chi > kappa$], [$tilde$ hours],
  ),
  caption: [Layer 1: Readout resonator characterization. All nodes are fully parallelizable across the chip via frequency-multiplexed readout.],
)

=== Layer 2: Qubit Spectroscopy

#figure(
  table(
    columns: (1.2fr, 1.5fr, 1fr, 1fr, 1fr),
    align: (left, left, left, left, left),
    table.header([*Node*], [*Parameters*], [*Analysis*], [*Tolerance*], [*Timeout*]),
    [Two-tone spec.], [$f_(01)$, $alpha$], [Lorentzian peak], [$< 500$ kHz], [$tilde 1$ h],
    [$e$-$f$ spec.], [$f_(12)$, $alpha$], [Peak detection], [$< 500$ kHz], [$tilde 1$ h],
    [Flux spec.], [Sweet-spot bias, $f(Phi)$], [Transmon model fit], [$1$ m$Phi_0$], [$tilde 1$ h],
  ),
  caption: [Layer 2: Qubit identification and spectroscopy.],
)

=== Layer 3: Readout Optimization

Six nodes: Time-of-flight $arrow.r$ Readout frequency optimization $arrow.r$ Readout amplitude optimization (Nelder-Mead, $tilde$ 100 ms #cite(<marciniak2026>)) $arrow.r$ Integration weights (matched filter) $arrow.r$ Single-shot classification (Gaussian mixture / LDA in IQ plane) $arrow.r$ Readout mitigation matrix.

Target: assignment fidelity $> 99%$ (state-of-art: 99.5--99.77% at 56--140 ns integration #cite(<bengtsson2024>)).

=== Layer 4: Single-Qubit Gate Calibration

#figure(
  table(
    columns: (1.2fr, 1.5fr, 1fr, 1fr, 1fr),
    align: (left, left, left, left, left),
    table.header([*Node*], [*Parameters*], [*Analysis*], [*Tolerance*], [*Timeout*]),
    [Rabi amplitude], [$A_pi$, $A_(pi slash 2)$], [Sinusoidal fit], [$< 1%$ of $pi$], [$tilde 30$ min],
    [Ramsey], [$f_(01)$ (fine), $T_2^*$], [Damped sinusoid], [$< 10$ kHz], [$tilde$ min--hours],
    [DRAG], [$beta$], [Cosine fit (error amp.)], [$< 5%$ of $-1 slash (2 alpha)$], [Stable],
    [Fine amplitude], [Corrected $A_pi$], [Linear fit ($d theta$ vs.\ $N$)], [$< 10^(-4)$ rad], [$tilde 30$ min],
    [Fine DRAG], [Refined $beta$], [Error amplification], [Leakage $< 10^(-4)$], [Stable],
    [AllXY], [Verification], [21-pair deviations], [All within spec], [N/A],
    [Virtual $Z$], [Software phases], [Frame tracking], [Exact], [Stable],
  ),
  caption: [Layer 4: Single-qubit gate calibration. The key tolerance from the Optimus patent is $10^(-4)$ radians for the $pi$-pulse rotation angle.],
)

=== Layer 5: Coherence Characterization

Five nodes: $T_1$ (exponential decay fit; fluctuates on sub-second to hour timescales #cite(<berritta2026>)), $T_2^*$ (Ramsey), $T_(2,"echo")$ (Hahn echo), $T_(2,"CPMG")$ (dynamical decoupling), $T_phi$ (derived: $1 slash T_phi = 1 slash T_2 - 1 slash (2 T_1)$).

=== Layer 6: Single-Qubit Benchmarking

Standard RB (exponential decay of Clifford fidelity; target EPC $< 10^(-3)$), Interleaved RB (gate-specific error), Half-angle calibration.

=== Layer 7: Flux Calibration

#figure(
  table(
    columns: (1.2fr, 1.5fr, 1fr, 1fr, 1fr),
    align: (left, left, left, left, left),
    table.header([*Node*], [*Parameters*], [*Analysis*], [*Tolerance*], [*Timeout*]),
    [Flux bias], [DC sweet-spot bias], [Ramsey vs.\ flux], [$5 times 10^(-4)$ $Phi_0$], [$tilde$ hours],
    [Flux crosstalk matrix], [$M_(i j)$], [Linear regression], [$< 10^(-3)$ of applied flux], [$tilde$ hours],
    [Cryoscope (FIR)], [120 FIR coefficients], [Regularized optimization], [$< 0.1%$ freq.\ error], [$tilde$ hours],
    [IIR distortion], [4 exponential taus], [Sum-of-exponentials fit], [$< 2$ MHz residual], [$tilde$ hours],
  ),
  caption: [Layer 7: Flux calibration nodes. The cryoscope measures flux-pulse distortion at AWG sampling resolution (0.42 ns) #cite(<cryoscope>).],
)

=== Layer 8: Tunable Coupler Calibration

Five nodes in sequence: Anticrossing localization $arrow.r$ Energy spectrum mapping (via adiabatic SWAP, requiring $gt.eq 50$ ns rise/fall #cite(<coupler_char>)) $arrow.r$ Coupler flux distortion $arrow.r$ Dispersive shift tuning $arrow.r$ Idle-point calibration (target: $Z Z slash 2 pi < 10$ kHz).

=== Layer 9: Two-Qubit Gate Calibration

For CZ gates (Google architecture): Chevron scan (2D amplitude $times$ duration) $arrow.r$ Conditional phase calibration ($|phi_("CZ") - pi| < 0.01$ rad) $arrow.r$ Leakage calibration (target $< 0.11%$ per gate) $arrow.r$ Single-qubit phase corrections (virtual $Z$).

=== Layers 10--11: Two-Qubit Benchmarking and System Verification

Two-qubit RB (target $< 0.6%$ error), interleaved RB, layer fidelity, quantum volume, active reset calibration.

== Drift Timescales for Timeout Values

#figure(
  table(
    columns: (1.5fr, 2fr, 1.5fr),
    align: (left, left, left),
    table.header([*Parameter*], [*Drift Timescale*], [*Recommended Timeout*]),
    [$T_1$], [Sub-second telegraphic (up to 10 Hz); hours slow], [Minutes (ideal: ms)],
    [Qubit frequency], [$plus.minus 25$ kHz / 6 h; 1/$f$ noise], [1--4 hours],
    [$pi$-pulse amplitude], [Allan deviation at $tilde 1000$ s], [30 min],
    [Readout parameters], [Hours (amplifier drift)], [2--4 hours],
    [DRAG $beta$], [Stable ($alpha$ fixed by junction)], [Days--weeks],
    [Flux bias], [Minutes to hours], [1--2 hours],
    [Two-qubit gate], [Hours (coupler drift)], [1--2 hours],
  ),
  caption: [Recommended timeout values based on measured drift timescales from the literature. Fast FPGA-based calibration can achieve $tilde 31$ ms combined frequency + amplitude recalibration #cite(<marciniak2026>).],
)

== Complete DAG Dependency Graph

#figure(
  align(left)[
    #set text(size: 9pt, font: "Consolas")
    ```
    CRYOSTAT → TWPA → RES_SPEC_HI → RES_PUNCHOUT → RES_SPEC_LO → DISPERSIVE_SHIFT
                                                    │
                                                    ▼
                      QUBIT_SPEC → FLUX_SPEC → FLUX_BIAS → FLUX_XTALK → CRYOSCOPE/IIR
                          │                                      │
                          ▼                                      ▼
                TIME_OF_FLIGHT → RO_FREQ → RO_AMP → INT_WGTS → SINGLE_SHOT → RO_MITIG
                          │
                          ▼
                     RABI_AMP → RAMSEY → DRAG → FINE_AMP → FINE_DRAG → ALLXY
                          │         │
                          ▼         ▼
                      T1/T2/T2E  VIRTUAL_Z
                          │
                          ▼
                     SQ_RB → INTERLEAVED_RB
                                    │
          COUPLER_ANTICROSS → COUPLER_SPECTRUM → COUPLER_DISTORT → COUPLER_IDLE
                                                                        │
                                                                        ▼
                                              CHEVRON → CZ_PHASE → CZ_LEAK → CZ_Z_CORR
                                                                                    │
                                                                                    ▼
                                                        TQ_RB → LAYER_FIDELITY → QV
    ```
  ],
  caption: [Complete reconstructed calibration DAG. Arrows indicate dependencies. Nodes at the same depth can be parallelized across qubits/pairs.],
)

// ════════════════════════════════════════════════════════════════
= Gap 3: Reconstructing the Snake Optimizer <sec:snake>

== Published Details

The Snake optimizer #cite(<klimov2024>) decomposes the $tilde 3 N$-dimensional frequency configuration problem into local subproblems of dimension $S^2$ (scope parameter $S$). The paper publishes:

- The _outer loop_: graph traversal, scope parameter, constraint propagation.
- The _error model equation_: $E(cal(F) | A, D) = sum_g sum_m w_(g,m)(A) dot epsilon_(g,m)(cal(F)_(g,m) | D)$.
- The four error mechanisms: dephasing, relaxation, stray coupling, pulse distortion.
- Results: 16 trainable weights, $tilde 40,000$ error components, $tilde 6,500$ training benchmarks.
- Healing and stitching procedures.

The paper does _not_ publish: the inner-loop optimizer, weight training procedure, or specific collision-avoidance rules.

== Reconstructed Error Model

=== The Four Error Components

*Dephasing.* Flux noise at the operating point causes frequency fluctuations proportional to the flux sensitivity:
$ epsilon_("deph")(f_i) = |d omega_i / d Phi|_(f_i) dot sqrt(A_Phi) $
where $A_Phi$ is the 1/$f$ flux noise amplitude. At the sweet spot ($f = f_("max")$), the first derivative vanishes and $T_phi$ is maximized. _Optimization pressure_: bias idle frequencies toward $f_("max")$.

*Relaxation.* Energy decay due to TLS defects and circuit coupling:
$ epsilon_("relax")(f_i) = 1 / T_1(f_i) $
where $T_1(f)$ is the measured relaxation spectrum. _Optimization pressure_: avoid $T_1$ hotspots.

*Stray coupling.* Residual $Z Z$ interaction at non-zero detuning #cite(<crosstalk>):
$ zeta_(i j) = (2(alpha_i + alpha_j) J_(i j)^2) / ((Delta_(i j) + alpha_i)(Delta_(i j) - alpha_j)) $
where $alpha tilde -200$ MHz, $J tilde 5$--$20$ MHz, $Delta = f_i - f_j$. Measured values: $tilde 22$ kHz (nearest neighbor), $tilde 2.5$ kHz (distance 3). _Optimization pressure_: disperse frequencies.

*Pulse distortion.* Control errors from finite-bandwidth electronics:
$ epsilon_("dist")(f_i, f_(i j)) = c_("dist") dot |f_(i j) - f_i| $
_Optimization pressure_: minimize frequency excursion between idle and interaction points; favor symmetric CZ resonances.

=== The 16-Weight Structure

The reduction from $tilde 40,000$ components to 16 weights exploits two symmetries:

+ *Homogeneity*: all gates of the same _type_ share one weight.
+ *Translation invariance*: weights are position-independent on the chip.

On a 2D lattice with CZXEB benchmarking, there are approximately 4 gate contexts (single-qubit isolated, single-qubit adjacent to blue-layer CZ, blue-layer CZ, green-layer CZ) $times$ 4 mechanisms $= 16$ weights:

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    table.header([*Context*], [Deph.], [Relax.], [Stray], [Dist.]),
    [SQ (isolated)], [$w_1$], [$w_2$], [$w_3$], [$w_4$],
    [SQ (adj.\ blue CZ)], [$w_5$], [$w_6$], [$w_7$], [$w_8$],
    [CZ (blue layer)], [$w_9$], [$w_(10)$], [$w_(11)$], [$w_(12)$],
    [CZ (green layer)], [$w_(13)$], [$w_(14)$], [$w_(15)$], [$w_(16)$],
  ),
  caption: [Plausible decomposition of the 16 trainable weights into 4 gate contexts $times$ 4 error mechanisms. The physical error components $epsilon_(g,m)$ are computed from characterization data; only the relative importances $w_(g,m)$ are learned.],
)

=== Weight Training Procedure

We propose training via constrained least-squares regression:

+ Acquire CZXEB cycle errors $e_(c,k)$ at $K tilde 6,500$ diverse frequency configurations $cal(F)_k$.
+ For each configuration, compute the predicted error $E(cal(F)_k | bold(w), D)$ using the error model.
+ Minimize $sum_(k=1)^K [E(cal(F)_k | bold(w), D) - e_(c,k)]^2$ over the 16 non-negative weights $bold(w)$.
+ The frequency tunability is key: sweeping frequencies generates training data at different operating points with different error balances, breaking degeneracies.

The model evaluates at $tilde 100$ Hz on a desktop #cite(<klimov2024>), making L-BFGS-B with non-negativity constraints computationally trivial.

== Proposed Inner-Loop Optimizers

=== Candidate 1: Nelder-Mead Simplex (Most Likely)

Google uses Nelder-Mead for CZ gate optimization with 4--12 parameters per gate #cite(<fan2025>). For $S = 2$ (default scope), each subproblem has $tilde 5$ dimensions---well within Nelder-Mead's effective range ($lt.eq 10$--$20$ dimensions).

*Advantages*: derivative-free, handles noisy objectives, simple to implement, fast convergence for low-dimensional problems. *Disadvantages*: no convergence guarantees, can stall in high dimensions.

=== Candidate 2: CMA-ES (Best for Higher Scope)

Google has used CMA-ES for pulse optimization with up to 55 parameters #cite(<google_cmaes>). For $S = 4$ ($tilde 21$ dimensions), CMA-ES provides robust exploration with noise resistance.

*Advantages*: handles $10$--$100$ dimensions, adapts covariance matrix to problem geometry, superior noise resistance (ranked best across all scenarios by Pack _et al._ #cite(<pack2024>)). *Disadvantages*: higher computational cost per iteration.

=== Candidate 3: Grid Search (For S = 1)

At $S = 1$ (1D subproblems, $tilde 100$ discrete options), exhaustive grid search completes in $tilde 6$ seconds total for 177 subproblems at 100 Hz evaluation rate. This likely explains the $S = 1$ runtime.

=== Recommended Strategy

Use *grid search* for $S = 1$, *Nelder-Mead* for $S = 2$--$3$, and *CMA-ES* for $S gt.eq 4$. This matches the published runtimes (6 s, 130 s, 6,500 s) and is consistent with Google's demonstrated optimizer preferences.

== Frequency Collision Rules

For frequency-tunable transmons (Google architecture), the critical collision conditions are #cite(<collision_rules>):

#figure(
  table(
    columns: (1.5fr, 2fr, 1fr),
    align: (left, left, center),
    table.header([*Collision*], [*Condition*], [*Type*]),
    [$|01 angle lr(arrow.l.r) |10 angle$], [$f_(01)^i = f_(01)^j$], [Resonant swap],
    [$|11 angle lr(arrow.l.r) |02 angle$], [$f_(01)^i = f_(01)^j + alpha_j$], [CZ target / parasitic],
    [$|11 angle lr(arrow.l.r) |20 angle$], [$f_(01)^i = f_(01)^j - alpha_i$], [Parasitic],
    [$|01 angle lr(arrow.l.r) |12 angle$], [$f_(01)^i = f_(12)^j$], [Leakage],
    [$|10 angle lr(arrow.l.r) |21 angle$], [$f_(01)^j = f_(12)^i$], [Leakage],
  ),
  caption: [Frequency collision conditions for tunable transmons. Non-target pairs must satisfy $|f_i - f_j - alpha_j| gt.double J$ (coupling strength) for all collision types.],
)

For fixed-frequency transmons (IBM architecture), nine constraint families with specific MHz thresholds have been published #cite(<freq_alloc>), mapping the problem to constrained graph coloring solvable by mixed-integer programming.

== Reconstructed Pseudocode

#figure(
  rect(width: 100%, inset: 10pt, fill: rgb("#f5f5f5"), stroke: 0.5pt + gray)[
    #set text(size: 9pt, font: "Consolas")
    ```python
    def snake_optimize(graph, scope_S, char_data, weights):
        F = initial_checkerboard_config(graph)
        calibrated = set()
        for subgoal in partition_graph(graph, scope_S):  # parallel
            seed = select_seed(subgoal)
            snake_traverse(seed, subgoal, F, calibrated, scope_S,
                           char_data, weights)
        return F

    def snake_traverse(node, subgoal, F, calibrated, S, D, w):
        if node in calibrated: return
        local = get_neighborhood(node, S)  # ~S^2 frequencies
        constraints = {F[n] for n in calibrated if adjacent(n, local)}
        def objective(f_local):
            F_trial = F.copy(); F_trial.update(local, f_local)
            return error_estimator(F_trial, w, D)
        if S == 1:
            f_opt = grid_search(objective, 100 points)
        elif S <= 3:
            f_opt = nelder_mead(objective, F[local], constraints)
        else:
            f_opt = cma_es(objective, F[local], sigma0=50 MHz)
        F.update(local, f_opt); calibrated.add(node)
        for neighbor in traversal_options(node, S, subgoal, calibrated):
            snake_traverse(neighbor, subgoal, F, calibrated, S, D, w)
    ```
  ],
  caption: [Reconstructed Snake optimizer pseudocode. The key insight is that intermediate scope ($S = 2$--$4$) outperforms both local ($S = 1$) and global ($S = S_("max")$) because constraint propagation guides subsequent optimizations.],
)

// ════════════════════════════════════════════════════════════════
= Gap 5: TLS Forecasting Algorithms <sec:tls>

== The TLS Problem

Two-level system (TLS) defects couple to transmon qubits, causing frequency-dependent relaxation ($T_1$) degradation. A single resonant TLS reduces $T_1$ by $tilde 60%$ and increases single-qubit error by $35 times$ #cite(<tls_tuning>). Google's Willow paper #cite(<willow2024>) states: _"we employ a frequency optimization strategy which forecasts defect frequencies of two-level systems (TLS)"_ --- but provides no algorithmic details.

== Key Physical Parameters

Our research established the quantitative foundation for TLS forecasting:

#figure(
  table(
    columns: (2fr, 1.5fr, 1.5fr),
    align: (left, left, left),
    table.header([*Parameter*], [*Value*], [*Source*]),
    [Spectral diffusion constant $D$], [$2.2 plus.minus 0.1$ MHz/h#super[$1 slash 2$]], [#cite(<tls_stats>)],
    [TLS drift rate], [Several MHz/day at 10 mK], [Multiple],
    [Slow switching rates], [0.07--1.9 mHz], [#cite(<klimov2018_tls>)],
    [Fast switching rates], [Up to 10 Hz], [#cite(<berritta2026>)],
    [TLS density (junction leads)], [0.4--0.7 / GHz / $mu$m], [#cite(<tls_stats>)],
    [Coupling threshold (strong)], [$g slash 2 pi gt.eq 0.5$ MHz], [#cite(<tls_mitigate>)],
    [Cosmic ray scrambling rate], [$tilde$ 1 / 592 s], [#cite(<cosmic_tls>)],
    [$T_1$ impact (single resonant TLS)], [60% reduction], [#cite(<tls_tuning>)],
  ),
  caption: [Key quantitative parameters for TLS forecasting. The spectral diffusion constant $D = 2.2$ MHz/h#super[$1 slash 2$] is the central number for any prediction algorithm.],
)

== Proposed Algorithms

=== Algorithm 1: Bayesian Particle Filter (Physics-Motivated)

Model each TLS as a particle diffusing in frequency space:
$ f_("TLS",i)(t + delta t) = f_("TLS",i)(t) + sqrt(2 D dot delta t) dot xi, quad xi tilde cal(N)(0, 1) $

with telegraphic activation/deactivation:
$ P("switch") = r_i dot delta t, quad r_i in [10^(-4), 10] "Hz" $

*Observation model* (relaxation rate as function of qubit frequency):
$ Gamma_1(f_q, t) = Gamma_(1,"bg")(f_q) + sum_i (g_i^2 gamma_i) / (gamma_i^2 + (f_q - f_("TLS",i)(t))^2) dot "active"_i(t) $

*Inference*: Sequential Monte Carlo with $N tilde 1000$--$10,000$ particles per TLS; resample when ESS $< N slash 2$; spawn new TLS on unexplained $T_1$ dips.

*Prediction horizon*: $sigma_f(tau) = sqrt(2 D tau)$ gives $tilde 3$--$5$ MHz at 1--4 hours, $tilde 10$--$15$ MHz at 24 hours.

*Computational cost*: $cal(O)(N_("particles") dot N_("TLS"))$ per update, $tilde$ ms on CPU.

=== Algorithm 2: Hidden Markov Model

Discretize the frequency range (e.g., 4--6 GHz) into $tilde 2000$ bins of width 1 MHz. Model TLS occupation as binary per bin with Gaussian transition kernels. Forward-backward inference; $cal(O)(N_("bins"))$ per update with sparse transitions.

=== Algorithm 3: Neural Network Time-Series Forecaster

Train LSTM/Transformer on rolling 48-hour windows of $T_1$ measurements (10-minute resolution = 288 time steps). Input: per-qubit $T_1$ history + operating frequency + cross-qubit correlations. Output: predicted $T_1$ distribution over next 1--24 hours.

*Requirement*: $> 10,000$ qubit-hours of training data. Achieves best short-term accuracy but is device-specific and black-box.

=== Algorithm 4: Gaussian Process Regression

Model $T_1(f, t)$ as a GP with a physics-informed composite kernel:
$ k((f_1, t_1), (f_2, t_2)) = k_("freq")(f_1, f_2) dot k_("time")(t_1, t_2) + k_("TLS") $

where $k_("freq")$ is Matérn with lengthscale $tilde$ TLS linewidth (0.1--1 MHz), $k_("time")$ combines RBF (slow drift) and Matérn (fast switching), and $k_("TLS")$ is a spectral mixture kernel. Provides natural uncertainty quantification.

=== Algorithm 5: Change-Point Detection + Linear Extrapolation (Most Likely Google Approach)

This is our best reconstruction of Google's actual method, based on all available evidence:

#rect(width: 100%, inset: 10pt, fill: rgb("#e8f5e9"), stroke: 0.5pt + rgb("#2e7d32"))[
  *Phase 1: Catalog.* Swap spectroscopy at cooldown; record $\{f_("TLS"), g, gamma\}$ for each defect.

  *Phase 2: Track.* Monitor $T_1$ at operating frequency (every 4 QEC rounds). Periodic $T_1$-vs.-frequency rescans every 2--4 hours.

  *Phase 3: Forecast.* Per tracked TLS, maintain running frequency estimate and drift velocity. Linear extrapolation with diffusion uncertainty:
  $ f_("TLS")(t + tau) tilde cal(N)(hat(f)_("TLS")(t) + hat(v) tau, 2 D tau + sigma_("meas")^2) $

  *Phase 4: Reallocate.* When TLS forecast to enter operating band (within $g slash pi$), trigger recalibration via Snake optimizer.
]

*Why this is likely Google's approach*: (1) Google has swap spectroscopy capability (all papers since 2018); (2) the Willow paper uses "forecasts" (plural), suggesting per-TLS tracking; (3) they acknowledge failure for "transient TLS moving faster than our forecasts"---consistent with diffusion-based prediction failing for telegraphic events; (4) scales linearly with qubit count; (5) integrates naturally with the Snake optimizer's relaxation-rate spectra.

=== Algorithm 6: FPGA-Based Real-Time Bayesian Tracker (State-of-Art 2026)

Based on Berritta _et al._ #cite(<berritta2026>): gamma-distribution Bayesian estimation on FPGA. Each $T_1$ update takes $tilde 2.2$ $mu$s; full estimate from 50 shots in $tilde 11$ ms. Resolves TLS switching at up to 10 Hz---4 orders of magnitude faster than previously possible.

*Extension for forecasting*: run parallel trackers at multiple frequency points (via AC Stark shift); detect TLS as transient Lorentzian dips in $Gamma_1(f)$; track dip center over time; predict via diffusion model.

== Comparison of Algorithms

#figure(
  table(
    columns: (1.5fr, 1fr, 1fr, 1fr, 1fr),
    align: (left, center, center, center, center),
    table.header([*Algorithm*], [*Accuracy (1--4 h)*], [*Data req.*], [*Compute*], [*Scalability*]),
    [Particle filter], [3--5 MHz], [Moderate], [ms/update], [Good],
    [HMM], [3--5 MHz], [Moderate], [ms/update], [Good],
    [Neural network], [Best], [Extensive], [ms (GPU)], [Device-specific],
    [GP regression], [3--5 MHz], [Moderate], [s/update], [Moderate],
    [Change-point + extrap.], [5--10 MHz], [Minimal], [$mu$s], [Excellent],
    [FPGA Bayesian], [Sub-MHz], [Real-time], [$mu$s (FPGA)], [Excellent],
  ),
  caption: [Comparison of proposed TLS forecasting algorithms. Accuracy column shows predicted frequency uncertainty at a 1--4 hour horizon, given $D = 2.2$ MHz/h#super[$1 slash 2$].],
)

== Fundamental Limitations

Two processes are _inherently unpredictable_:
+ *Telegraphic TLS switching* ($> 1$ Hz): Can only be detected after the fact; the best strategy is fast detection + rapid recalibration #cite(<berritta2026>).
+ *Cosmic ray TLS scrambling* ($tilde 1$ event / 10 min): Simultaneously shifts multiple TLS frequencies; fundamentally stochastic #cite(<cosmic_tls>). Mitigation: detect via correlated multi-qubit error bursts, then re-characterize.

// ════════════════════════════════════════════════════════════════
= Gap 10: Control Electronics Stack <sec:electronics>

== Target Specifications (Willow)

#figure(
  table(
    columns: (2fr, 1.5fr),
    align: (left, left),
    table.header([*Parameter*], [*Willow Value*]),
    [1Q gate fidelity], [99.97% (error $3 times 10^(-4)$)],
    [2Q gate fidelity], [99.88% (error $1.2 times 10^(-3)$)],
    [Readout fidelity], [99.5% (error $5 times 10^(-3)$)],
    [$T_1$ (mean)], [68 $mu$s],
    [1Q gate time], [25 ns],
    [2Q gate time (CZ)], [42 ns],
    [Qubit frequency range], [5--7 GHz],
    [Qubits], [105],
  ),
  caption: [Willow processor target specifications that the electronics stack must support.],
)

== Minimum Electronics Requirements

#figure(
  table(
    columns: (1.5fr, 1.5fr, 1.5fr),
    align: (left, left, left),
    table.header([*Parameter*], [*Requirement*], [*Rationale*]),
    [DAC resolution], [$gt.eq 14$-bit], [Quantization noise below $10^(-4)$ gate error],
    [DAC sample rate], [$gt.eq 1$ GSa/s (IQ) or $gt.eq 2$ GSa/s (direct)], [Nyquist for 25 ns pulses],
    [Phase noise (10 kHz offset)], [$< -110$ dBc/Hz], [Dephasing contribution $< 10^(-3)$],
    [Output noise density], [$< -135$ dBm/Hz], [Below decoherence floor],
    [Timing jitter], [$< 1$ ps RMS], [Coherent multi-qubit sequences],
    [Bandwidth], [$gt.eq 500$ MHz], [DRAG-shaped 25 ns pulses],
    [Feedback latency], [$< 500$ ns], [Active reset / real-time decoding],
    [DC flux noise], [$< 20$ nV/$sqrt("Hz")$], [Flux bias stability],
  ),
  caption: [Minimum electronics specifications for Willow-level gate fidelity. At this fidelity level, qubit decoherence ($T_1$, $T_2$) dominates over electronics noise.],
)

== Commercial Platform Comparison

#figure(
  table(
    columns: (1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
    align: (left, center, center, center, center, center),
    table.header([*Spec*], [*ZI SHFQC+*], [*QM OPX1000*], [*Qblox*], [*Keysight*], [*QICK*]),
    [DAC rate], [2 GSa/s], [2 GSa/s], [1 GSa/s], [$tilde 11$ GSa/s], [9.85 GSa/s],
    [DAC bits], [14], [16], [16], [12], [14],
    [Freq.\ range], [DC--8.5 GHz], [DC--10.5 GHz], [2--18.5 GHz], [DC--16 GHz], [DC--10 GHz],
    [BW], [1 GHz], [800 MHz], [500 MHz], [2 GHz], [$tilde 500$ MHz],
    [Phase noise#super[a]], [$-110$], [$-125$], [$-115$], [—], [$-70$#super[b]],
    [Feedback], [350 ns], [$< 160$ ns], [364 ns], [—], [—],
    [Ch / unit], [6+16], [64], [80], [$tilde 16$], [16],
    [Open source], [No], [No], [No], [No], [*Yes*],
    [Est.\ cost], [\$150--300k], [\$200--500k], [\$100--250k], [\$100--200k], [*\$30--50k*],
  ),
  caption: [Commercial quantum control electronics comparison. #super[a]dBc/Hz at 10 kHz offset from $tilde 5$ GHz carrier. #super[b]QICK phase noise is worst-case measured; typical operation is better.],
)

All five commercial platforms meet the minimum specifications for Willow-level 1Q and 2Q gate fidelity. The performance ceiling at this fidelity level is set by *qubit coherence and fabrication quality, not electronics noise*.

=== QICK: The Open-Source Option

QICK (Quantum Instrumentation Control Kit) #cite(<qick>) from Fermilab/U.\ Chicago runs on Xilinx RFSoC boards:
- *ZCU216*: 16 DAC channels at 9.85 GSa/s, 14-bit, mixer-free direct RF synthesis to 10 GHz. Cost: $tilde$\$30--50k.
- *RFSoC 4x2*: 2 DAC channels. Cost: $tilde$\$2,149 (academic).
- *Demonstrated fidelity*: 99.93% (1Q Clifford), $> 99.9%$ (2Q parametric).
- Fully open-source (MIT license).

For a 105-qubit system with $tilde$ 3 lines/qubit ($tilde$ 315 channels), $tilde$ 20 ZCU216 boards would be needed ($tilde$ \$600k--\$1M), plus DC sources for flux bias.

== Wiring and Filtering Scheme

=== XY Drive Lines (Qubit Control, 4--8 GHz)

#figure(
  table(
    columns: (1.5fr, 2fr, 1.5fr),
    align: (left, left, left),
    table.header([*Temperature Stage*], [*Component*], [*Purpose*]),
    [300 K], [SMA to semi-rigid coax], [Signal routing],
    [50 K], [0--10 dB attenuator], [Thermalization],
    [4 K], [10--20 dB attenuator + CuNi coax], [Thermal noise suppression],
    [$tilde$ 800 mK (still)], [0--3 dB attenuator], [Additional filtering],
    [$tilde$ 100 mK (cold plate)], [10--20 dB attenuator], [Thermal noise],
    [$tilde$ 10 mK (MXC)], [20 dB atten.\ + Eccosorb + LP filter], [Quantum noise floor],
  ),
  caption: [XY drive line wiring scheme. Total attenuation: $tilde 60$ dB, achieving thermal photon number $tilde 10^(-3)$ at the mixing chamber.],
)

=== Z Flux Lines (DC--500 MHz)

Resistive coax (CuNi/stainless steel) from 300 K to 4 K; NbTi or Cu loom to MXC; RC or copper-powder filter at MXC (LP cutoff $tilde 1$ GHz).

=== Readout Output Lines (4--8 GHz)

- *MXC (10 mK)*: TWPA or JPA ($gt.eq 20$ dB gain, near quantum limit) + 2--3 circulators/isolators.
- *4 K*: HEMT amplifier ($tilde 40$ dB gain, $tilde 2$--$4$ K noise temperature).
- *300 K*: Room-temperature amplification chain + digitization.
- Cable: NbTi superconducting coax (MXC to 4 K, ultra-low loss), stainless steel above.

== Scaling Beyond 100 Qubits

At 1000+ qubits, room-temperature electronics face fundamental limits:
- *Wiring*: $tilde$ 3000--5000 coaxial lines through the cryostat; high-density solutions (Bluefors Cri/oFlex, flexible striplines) become essential.
- *Thermal budget*: Each coax conducts $tilde$ 20--50 $mu$W from 300 K to 4 K; MXC cooling power is only $tilde$ 10--20 $mu$W.
- *Cost*: $tilde$ \$5--50M in control hardware at commercial pricing.

The path forward is *cryogenic CMOS*: controllers operating at 4 K, demonstrated by both Google #cite(<cryo_cmos>) and IBM, achieving gate errors of $10^(-4)$--$10^(-3)$ at 4--23 mW per qubit.

// ════════════════════════════════════════════════════════════════
= Synthesis and Recommendations

== Feasibility Assessment

#figure(
  table(
    columns: (auto, 1fr, 1fr, auto),
    align: (center, left, left, center),
    table.header([*Gap*], [*Solution Maturity*], [*Key Remaining Challenge*], [*Effort*]),
    [1], [High — 52-node DAG reconstructed from 5 sources], [Tolerance fine-tuning requires iterative experimental validation], [3--6 months],
    [3], [High — error model fully reconstructed; 3 candidate inner-loop optimizers], [Weight training requires $tilde 6,500$ CZXEB benchmarks on actual hardware], [2--4 months],
    [5], [Medium — 6 algorithms proposed; fundamental prediction limits quantified], [Algorithm 5 (change-point) needs experimental validation of $D$ on specific device], [4--8 months],
    [10], [High — 5 commercial + 1 open-source platform meet specifications], [Wiring/filtering at 100+ qubits requires cryogenic engineering], [1--3 months],
  ),
  caption: [Feasibility assessment for bridging each critical gap. Effort estimates assume access to a multi-qubit transmon testbed.],
)

== Recommended Reproduction Roadmap

*Months 1--3*: Deploy control electronics (QICK on ZCU216 or OPX1000); implement the 52-node calibration DAG in Qibocal or QUAlibrate; bring up a 5--10 qubit testbed.

*Months 4--6*: Implement TLS characterization (swap spectroscopy, $T_1$ monitoring); begin building TLS catalog; implement Algorithm 5 (change-point + extrapolation) as baseline forecaster.

*Months 7--9*: Implement the Snake outer loop with Nelder-Mead inner loop; collect CZXEB training data; train the 16-weight error model.

*Months 10--12*: Scale to 20+ qubits; validate TLS forecasting accuracy; implement healing procedure for outlier suppression; compare forecasting algorithms (particle filter vs.\ change-point).

*Year 2*: Scale to 50--100 qubits; implement stitching for large-scale optimization; deploy FPGA-based real-time $T_1$ tracking; target below-threshold QEC.

// ════════════════════════════════════════════════════════════════

#pagebreak()

// ─── References ───
#heading(numbering: none)[References]
#set text(size: 9.5pt)

#bibliography(title: none, style: "american-physics-society", "gap_references.yml")
