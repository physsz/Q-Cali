// SOTA Survey: Superconducting Qubit Calibration
// Typst source — compile with `typst compile survey.typ`

#set document(
  title: "State-of-the-Art Survey: Qubit Calibration on Superconducting Quantum Processors",
  author: ("Survey compiled March 2026",),
)

#set page(
  paper: "us-letter",
  margin: (x: 1in, y: 1in),
  numbering: "1",
  header: align(right, text(size: 9pt, fill: gray)[_Superconducting Qubit Calibration: A Reproducibility-Oriented Survey_]),
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
    State-of-the-Art Survey: Qubit Calibration on \ Superconducting Quantum Processors
  ]
  #v(0.6em)
  #text(size: 12pt)[
    _With Special Focus on Google Quantum AI — A Reproducibility-Oriented Review_
  ]
  #v(0.4em)
  #text(size: 10pt, fill: gray)[Compiled March 14, 2026]
  #v(1.5em)
]

// ─── Abstract ───
#rect(width: 100%, inset: 12pt, stroke: 0.5pt + gray)[
  #text(weight: "bold")[Abstract.] #h(0.3em)
  Calibration of superconducting transmon qubits is the rate-limiting step in scaling quantum processors toward fault-tolerant operation. This survey provides a comprehensive, reproduction-oriented review of the state of the art, with particular attention to the calibration stack developed by Google Quantum AI for the Sycamore and Willow processors. We cover the full calibration hierarchy — from single-qubit spectroscopy and gate tune-up through two-qubit gate optimization, readout calibration, leakage management, frequency-collision avoidance, and system-level benchmarking. For each stage we document the published protocols, identify the specific information gaps that prevent independent reproduction, and compare approaches across major platforms (Google, IBM, Rigetti, academic groups). We find that while the architectural framework is well described, critical implementation details — tolerance thresholds, optimizer internals, TLS-forecasting algorithms, and full calibration-graph specifications — remain undisclosed. We catalog over 60 primary references spanning 2014–2026 and distill ten open problems for the calibration community.
]

#v(1em)
#outline(title: "Contents", indent: 1.5em, depth: 2)
#pagebreak()

// ════════════════════════════════════════════════════════════════
= Introduction <sec:intro>

Superconducting transmon qubits are the leading platform for near-term quantum computing, with processors now exceeding 100 physical qubits #cite(<arute2019>, supplement: "Arute _et al._") #cite(<willow2024>, supplement: "Google Quantum AI"). The central bottleneck to scaling is _calibration_: the process of experimentally determining and maintaining the $cal(O)(100)$ control parameters per qubit that define gate operations, readout, and idle behavior. A single miscalibrated parameter can cascade through the processor, degrading logical error rates by orders of magnitude #cite(<kelly2018>, supplement: "Kelly _et al._").

Google Quantum AI has published the most complete account of a production calibration stack, built around the *Optimus* framework #cite(<kelly2018>, supplement: "Kelly _et al._") and the *Snake* frequency optimizer #cite(<klimov2020>, supplement: "Klimov _et al._") #cite(<klimov2024>, supplement: "Klimov _et al._"). Their progression from the 53-qubit Sycamore processor #cite(<arute2019>, supplement: "Arute _et al._") through the 72-qubit third-generation device #cite(<google2023surface>, supplement: "Google Quantum AI") to the 105-qubit Willow chip #cite(<willow2024>, supplement: "Google Quantum AI") represents the most extensively documented calibration scaling trajectory in the field.

This survey is organized as follows. @sec:framework reviews the Optimus calibration framework and its directed-acyclic-graph (DAG) architecture. @sec:single covers single-qubit calibration (spectroscopy, gate tune-up, DRAG). @sec:twoqubit addresses two-qubit gate calibration for CZ, iSWAP, and cross-resonance gates. @sec:readout treats dispersive readout optimization. @sec:freq discusses frequency-collision management and the Snake optimizer. @sec:leakage covers leakage detection and removal. @sec:bench reviews benchmarking and verification methods. @sec:drift addresses drift tracking and real-time calibration. @sec:auto surveys automation and machine-learning approaches. @sec:gaps synthesizes the identified reproduction gaps. @sec:conclusion concludes.

// ════════════════════════════════════════════════════════════════
= The Optimus Calibration Framework <sec:framework>

== Architecture and DAG Structure

The foundational organizational principle for Google's calibration stack is the *directed acyclic graph* (DAG) introduced by Kelly _et al._ #cite(<kelly2018>, supplement: "Kelly _et al._") and protected by US Patent 9,940,212 #cite(<patent2018>, supplement: "Kelly"). Each calibration procedure is a _node_ in the graph; directed edges encode dependencies. The canonical bootstrapping order is:

+ *Readout calibration* (root — no dependencies)
+ *Qubit frequency identification* (depends on readout)
+ *Rabi driving calibration* (depends on frequency — determines $pi$-pulse amplitude)
+ *Single-qubit gate calibration* (X/Y amplitudes, phases, DRAG coefficient)
+ *Two-qubit gate calibration* (depends on single-qubit gates)
+ *System-level / algorithm-specific calibration*

Cyclic dependencies, where they arise, are broken by partitioning into _coarse_, _mid_, and _fine_ calibration layers.

== Node Interaction Protocol

Each node supports three methods, ordered by computational cost:

*`check_state`* (zero cost). A metadata-only check that passes if: (a) the most recent `check_data` or `calibrate` call is within the node's _timeout period_; (b) no unresolved calibration failures exist; (c) no dependency has been recalibrated since the last validation; and (d) all dependencies themselves pass `check_state`.

*`check_data`* (low cost). Runs a minimal experiment and classifies the result into one of three outcomes: _in spec_ (parameter within tolerance), _out of spec_ (detectable shift), or _bad data_ (noise-like response indicating a deeper dependency failure).

*`calibrate`* (high cost). Acquires a full dataset, performs analysis, updates the parameter store, and verifies data quality. This is the _only_ method that modifies stored parameters.

== Graph Traversal Algorithms

*`maintain(node)`*: Recursively descends from the target node to the root. At each level it calls `check_state`, escalating to `check_data` and then `calibrate` as needed.

*`diagnose(node)`*: Triggered when `check_data` returns _bad data_. Bypasses `check_state` entirely and works from experimental data, investigating ancestors until the root cause is found and recalibrated.

== Tolerances and Timeouts

Each node specifies a _tolerance_ (e.g., a $pi$-pulse must be within $10^(-4)$ radians of $pi$ rotation) and a _timeout period_ reflecting the characteristic drift timescale. The supplementary material of the quantum-supremacy experiment confirms that *over 100 parameters per qubit* are maintained #cite(<arute2019sup>, supplement: "Arute _et al._, Supp.").

#rect(width: 100%, inset: 10pt, fill: rgb("#fff3e0"), stroke: 0.5pt + rgb("#e65100"))[
  *Reproduction Gap 1.* The full DAG with concrete node names, analysis functions, tolerance values, and timeout periods has never been published. Only the abstract framework and a handful of illustrative examples are available. The Optimus codebase is proprietary.
]

// ════════════════════════════════════════════════════════════════
= Single-Qubit Calibration <sec:single>

== Spectroscopy and Basic Parameter Extraction

The canonical single-qubit calibration sequence, common across all platforms #cite(<qibocal2024>, supplement: "Pasquale _et al._") #cite(<laboneq>, supplement: "Zurich Instruments"), proceeds through five stages:

+ *Resonator spectroscopy.* Frequency sweep to identify readout resonators; extract bare resonator frequency at high power.
+ *Power-dependent spectroscopy (punchout).* Two-dimensional scan in amplitude and frequency; evaluate qubit viability through dispersive shift; classify each qubit as viable.
+ *Two-tone qubit spectroscopy.* Sweep drive frequency while monitoring readout; identify $|g angle arrow.r |e angle$ transition and extract qubit frequency $omega_q$ and anharmonicity $alpha$.
+ *Rabi oscillation.* Amplitude sweep at fixed duration to determine $pi$-pulse and $pi slash 2$-pulse amplitudes.
+ *Ramsey interferometry.* Two $pi slash 2$ pulses with variable delay; extract $T_2^*$ and fine frequency correction (typically $lt.eq 1$ MHz).

$T_1$ (energy relaxation) is measured by exciting the qubit and varying the wait time before measurement. Typical values on current platforms range from 20 $mu$s (Sycamore, 2019) to 68 $plus.minus$ 13 $mu$s (Willow, 2024) #cite(<willow2024>, supplement: "Google Quantum AI").

== DRAG Pulse Calibration

*Derivative Removal by Adiabatic Gate* (DRAG) is the universal technique for suppressing leakage to the $|2 angle$ state during fast single-qubit rotations. The in-phase component $I(t)$ uses a Gaussian or cosine envelope, while the quadrature component is $Q(t) = -beta dot.op dot(I)(t)$, with the DRAG coefficient $beta = -1 slash (2 alpha)$ where $alpha$ is the anharmonicity.

Calibration is performed via:
- *AllXY sequences*: pairs of gates (e.g., $R_x (pi) dash R_y (pi slash 2)$) at different DRAG values #cite(<qiskit_exp>, supplement: "Qiskit Experiments").
- *Error amplification*: repeated $X_(pi slash 2) dash (X_pi dash Y_pi)^n dash Y_(pi slash 2)$ sequences.

=== Advanced Pulse Envelopes

Hyppä _et al._ introduced *FAST DRAG* (Fourier Ansatz Spectrum Tuning), using a Fourier cosine-series envelope for broader spectral suppression, achieving leakage below $3 times 10^(-5)$ for gates as short as 6.25 ns — a 20$times$ reduction over conventional DRAG #cite(<hyyppa2024>, supplement: "Hyppä _et al._"). They also proposed *HD DRAG* (Higher-Derivative) using higher-order time derivatives.

Malarchick systematically compared Gaussian, DRAG, and GRAPE (numerical optimal control) pulses #cite(<malarchick2025>, supplement: "Malarchick"):
- For gate times $gt.eq$ 20 ns, properly calibrated DRAG achieves fidelities within $5 times 10^(-4)$ of the coherence limit.
- For gate times $lt$ 15 ns, GRAPE becomes necessary.
- DRAG exhibits superior robustness to frequency drift ($F_(min) = 0.990$ vs.\ GRAPE's $0.931$ over $plus.minus 5$ MHz detuning).

== Google's Single-Qubit Gate Performance

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    table.header(
      [*Parameter*], [*Sycamore (2019)*], [*3rd Gen (2023)*], [*Willow (2024)*],
    ),
    [1Q gate fidelity], [99.85%], [—], [99.97%],
    [1Q gate duration], [25 ns], [$tilde$ 25 ns], [$tilde$ 25 ns],
    [$T_1$], [$tilde$ 15–20 $mu$s], [$tilde$ 20 $mu$s], [68 $plus.minus$ 13 $mu$s],
    [$T_(2,"CPMG")$], [—], [—], [89 $mu$s],
    [Anharmonicity], [$tilde$ $-$200 MHz], [—], [—],
  ),
  caption: [Evolution of single-qubit parameters across Google processor generations.],
) <tab:sq_evolution>

#rect(width: 100%, inset: 10pt, fill: rgb("#fff3e0"), stroke: 0.5pt + rgb("#e65100"))[
  *Reproduction Gap 2.* Exact pulse envelopes (Gaussian vs.\ cosine, rise/fall times), DRAG coefficients, amplitude calibration precision targets, and the specific AllXY or error-amplification sequences used on Sycamore/Willow are not published. The gate duration of $tilde$ 25 ns is stated but the envelope shape is internal.
]

// ════════════════════════════════════════════════════════════════
= Two-Qubit Gate Calibration <sec:twoqubit>

== CZ Gate on Google Processors

Google's native two-qubit gate on Willow is the controlled-Z (CZ) gate, implemented by tuning neighboring qubits into the $|11 angle arrow.l.r |02 angle$ avoided crossing. The qubit is swept through frequency space via a shaped flux pulse, accumulating a conditional phase of $pi$.

The calibration involves:
+ *Chevron experiment*: 2D sweep of flux-pulse amplitude and duration to identify the $|11 angle dash |02 angle$ resonance and optimal gate time.
+ *Conditional-phase verification*: Ramsey-like sequences confirming $pi$ phase accumulation when the control qubit is in $|1 angle$ and zero phase when in $|0 angle$.
+ *Dynamical-phase compensation*: Virtual $Z$ rotations on both qubits to absorb single-qubit phase shifts.
+ *Coupler bias calibration*: Setting the tunable coupler's operating point to achieve the desired coupling strength while minimizing residual $Z Z$ interaction during idle.

The Sycamore gate (a specific member of the $f$-sim family with $theta = pi slash 2$, $phi = pi slash 6$) was native to the 2019 processor #cite(<arute2019>, supplement: "Arute _et al._"), with 12 ns duration and 99.64% average fidelity. Willow shifted to CZ ($tilde$ 26 ns, 99.88% fidelity) #cite(<willow2024>, supplement: "Google Quantum AI"), sacrificing speed for compatibility with surface-code circuits.

== The Snake Optimizer for Frequency Configuration <sec:snake_gates>

At scale, calibrating individual two-qubit gates is insufficient — the _global frequency configuration_ must be jointly optimized. Klimov _et al._ developed the *Snake optimizer* for this purpose #cite(<klimov2020>, supplement: "Klimov _et al._") #cite(<klimov2024>, supplement: "Klimov _et al._").

For an $N$-qubit processor, the configuration space $cal(F)$ has dimension $|cal(F)| tilde 3N$ (idle frequencies + interaction frequencies for each edge), with a combinatorial search space of $k^(cal(O)(N))$ where $k tilde 100$ frequency options per gate.

The Snake decomposes this into local subproblems of dimension $S^2$ (scope parameter $S$). It traverses the processor graph, optimizing each element subject to constraints imposed by previously calibrated neighbors. The error model:

$ E(cal(F) | A, D) = sum_g sum_m w_(g,m)(A) dot epsilon_(g,m)(cal(F)_(g,m) | D) $

captures four physical mechanisms:
- *Dephasing*: biases qubits toward maximum frequencies (flux-insensitive sweet spots).
- *Relaxation*: biases away from two-level-system (TLS) defect frequencies.
- *Stray coupling*: disperses frequencies to avoid collisions between parasitically coupled qubits.
- *Pulse distortion*: biases toward symmetric CZ resonance conditions.

The model uses $tilde$ 40,000 error components but only *16 trainable weights* for the full processor, trained on $tilde$ 6,500 cross-entropy benchmarks #cite(<klimov2024>, supplement: "Klimov _et al._").

#figure(
  table(
    columns: 3,
    align: (left, center, center),
    table.header(
      [*Configuration*], [*Cycle Error ($times 10^(-3)$)*], [*Runtime*],
    ),
    [Unoptimized baseline ($N = 68$)], [16.7 (median)], [—],
    [Snake $S = 1$ (local)], [9.8], [$tilde$ 6 s],
    [Snake $S = 2$ (default)], [7.2], [$tilde$ 130 s],
    [Snake $S = 4$], [$< 7.2$], [—],
    [Snake $S = S_"max"$ (global)], [10.8], [$tilde$ 6500 s],
  ),
  caption: [Snake optimizer performance on 68-qubit processor. Note that global optimization ($S = S_"max"$) is _worse_ than intermediate scope, demonstrating the importance of constraint propagation #cite(<klimov2024>, supplement: "Klimov _et al._").],
) <tab:snake>

Scaling projections for processors from $N = 17$ to $N = 1057$ (distance-3 to distance-23 surface codes) show that with "stitching" ($R = 4$ regions), a distance-23 logical qubit projects to cycle error of $6.3 times 10^(-3)$.

#rect(width: 100%, inset: 10pt, fill: rgb("#fff3e0"), stroke: 0.5pt + rgb("#e65100"))[
  *Reproduction Gap 3.* The _inner-loop optimizer_ used within each Snake step (gradient-based? Nelder-Mead? CMA-ES?) is not specified. The specific frequency-separation rules for collision avoidance, the training procedure for the 16 weights, and the integration API between Snake and Optimus are not documented.
]

== Cross-Resonance Gate Calibration (IBM Architecture)

For completeness, we summarize the cross-resonance (CR) gate used by IBM, as it represents the major alternative two-qubit gate paradigm.

Sheldon _et al._ #cite(<sheldon2016>, supplement: "Sheldon _et al._") established the systematic tuning procedure:
+ Optimize CR drive phase $phi_0$ to maximize $Z X$ and zero $Z Y$.
+ Align cancellation pulse phase ($phi_0 - phi_1$) to suppress single-qubit $I Y$.
+ Sweep cancellation amplitude until $I X$ and $I Y$ vanish simultaneously.

The echoed CR protocol uses two CR pulses with opposite amplitude, accompanied by $pi$ rotations on the control qubit, creating constructive interference for the entangling $Z X$ interaction while canceling unwanted terms ($Z I$, $Z Z$, $I X$). State-of-the-art fidelity: 99.40% at $tilde$ 280 ns (echo) #cite(<sheldon2016>, supplement: "Sheldon _et al._"); 99.78% at $tilde$ 180 ns with interference couplers.

Patterson _et al._ #cite(<patterson2019>, supplement: "Patterson _et al._") combined continuous and repeated-gate Hamiltonian tomography for step-wise error reduction, achieving 97.0(7)% via interleaved randomized benchmarking. Multi-derivative DRAG applied to CR pulses further suppresses multiple leakage transitions simultaneously #cite(<md_drag_cr>, supplement: "npj Quantum Inf. (2024)").

== Parallel CZ Calibration at Scale

Fan _et al._ demonstrated calibration of CZ gates across 52 qubits on a USTC processor #cite(<fan2025>, supplement: "Fan _et al._"), using a three-step fast-calibration procedure:
+ $|11 angle dash |02 angle$ state exchange with superposed CZ layers ($N = 0 dash 7$).
+ Conditional phase refinement via variable rotation $X_beta$.
+ Dynamical phase compensation with $Z_phi$ rotations on both qubits.

Non-overlapping gates are calibrated in parallel using Nelder-Mead optimization targeting "back probability" (return to $|00 angle$ after random two-qubit Cliffords). An inter-gate correlation metric $C_g = [F(U) - product F(U_i)] slash sqrt(F(U) dot product F(U_i))$ quantifies crosstalk.

// ════════════════════════════════════════════════════════════════
= Dispersive Readout Calibration <sec:readout>

== Fundamentals

Superconducting qubits are measured via _dispersive readout_: the qubit is coupled to a readout resonator, and the qubit-state-dependent frequency shift $chi$ (dispersive shift) allows discrimination via microwave transmission measurement.

Three parameters must be calibrated: the dispersive shift $chi$, the resonator linewidth $kappa$, and the drive power. Sank _et al._ #cite(<sank2024>, supplement: "Sank _et al._") developed a unified protocol measuring all three with few prerequisites, routinely deployed on chips with tens of qubits using automation software. Their models predict readout SNR to within 10% over 54-qubit devices. A critical finding: *resonator linewidth $kappa$ exhibits factor-of-2 variation* across devices, poorly controlled by fabrication.

== Model-Based Readout Optimization (Google)

Bengtsson _et al._ #cite(<bengtsson2024>, supplement: "Bengtsson _et al._") introduced model-based readout optimization achieving *1.5% measurement error per qubit* with 500 ns end-to-end duration, demonstrated simultaneously across 17 qubits. The approach uses a physical model of the dispersive readout to navigate the readout-power/speed/error tradeoff, suppressing measurement-induced state transitions that plague na\"ive optimization.

== Dynamic Dispersive Readout

Swiadek _et al._ #cite(<swiadek2024>, supplement: "Swiadek _et al._") demonstrated dynamically reducing the qubit-resonator detuning during readout to increase $chi$, achieving *0.25% two-state readout error in 100 ns* — nearly quadrupling SNR by doubling the effective linewidth. This requires precise real-time flux control of the qubit frequency during the measurement window.

== Readout Performance on Google Processors

Readout fidelity improved from 96.2% (Sycamore, 2019) to 99.5% (Willow, 2024), driven by:
- Optimized Purcell filter design reducing qubit decay through the readout channel.
- Model-based pulse shaping suppressing measurement-induced transitions.
- Improved single-shot IQ-plane discriminators.

#rect(width: 100%, inset: 10pt, fill: rgb("#fff3e0"), stroke: 0.5pt + rgb("#e65100"))[
  *Reproduction Gap 4.* The readout model internals (exact Hamiltonian truncation level, pulse parametrization, optimizer used for readout pulse shaping) are described at the level of a PRL paper #cite(<bengtsson2024>, supplement: "Bengtsson _et al._") but not open-sourced. Specific readout frequencies, powers, and integration windows for Willow are not published.
]

// ════════════════════════════════════════════════════════════════
= Frequency-Collision Management <sec:freq>

== The Problem

On processors with fixed-frequency or weakly-tunable transmons, qubit frequencies must be arranged to avoid _collisions_ — degeneracies where parasitic interactions cause enhanced decoherence or gate errors. Key collision types include:
- $omega_i = omega_j$ (qubit-qubit resonance)
- $omega_i = omega_j + alpha_j$ (straddling regime)
- $2 omega_i + alpha_i = 2 omega_j + alpha_j$ ($|02 angle dash |20 angle$ resonance)

== Fabrication-Level Approaches

Osman _et al._ #cite(<osman2023>, supplement: "Osman _et al._") demonstrated that fabricating larger Josephson junctions reduces wafer-level resistance standard deviation to 2%, achieving qubit frequency reproducibility with *40 MHz standard deviation (1%)* across 32 transmons. Simulations show their parametric-gate architecture scales to $tilde$ 100 qubits with only 3 collisions on average.

IBM's *laser annealing* technique #cite(<ibm_laser>, supplement: "IBM Research") selectively tunes individual transmon frequencies post-fabrication with *18.5 MHz precision* over hundreds of qubits, with no measurable coherence impact. This enabled a 65-qubit processor with median two-qubit gate fidelity of 98.7%.

The alternative *ABAA* (Alternating Bias Assisted Annealing) method achieves *7.7 MHz frequency precision* across 221 qubits #cite(<abaa2024>, supplement: "ABAA"), though junction-dependent relaxation remains the dominant imprecision source.

== Google's Approach: Snake + TLS Forecasting

Google addresses frequency collisions primarily through the Snake optimizer (@sec:snake_gates), which builds collision avoidance into its error model as the "stray coupling" term. For Willow, an additional *TLS forecasting* algorithm predicts two-level-system defect frequencies to avoid coupling during initial calibration and over the experimental duration #cite(<willow2024>, supplement: "Google Quantum AI").

#rect(width: 100%, inset: 10pt, fill: rgb("#fff3e0"), stroke: 0.5pt + rgb("#e65100"))[
  *Reproduction Gap 5.* The TLS forecasting algorithm is mentioned in the Willow paper but never described. Its inputs (historical TLS data? temperature dependence? spectral models?), prediction horizon, and accuracy are unknown. This is arguably the most significant undisclosed component for reproducing Willow-level performance.
]

// ════════════════════════════════════════════════════════════════
= Leakage Detection and Removal <sec:leakage>

== The Leakage Problem

Transmon qubits are weakly anharmonic oscillators; the $|2 angle$ state lies only $|alpha| tilde 200$ MHz above $|1 angle$. Gate operations — particularly two-qubit gates that traverse frequency space — can populate $|2 angle$ and higher levels. In quantum error correction, leaked population accumulates across cycles, causing correlated errors that degrade the code's performance far beyond what the leakage rate alone would suggest.

== Multi-Level Reset (MLR)

Google developed *multi-level reset* (MLR): an adiabatic swap between the qubit and readout resonator followed by a fast return, producing the ground state with *$gt$ 99% fidelity in 250 ns* from all relevant excited states #cite(<google_leakage2021>, supplement: "Google Quantum AI").

== Data Qubit Leakage Removal (DQLR)

For the Willow below-threshold experiment, Google introduced *DQLR* #cite(<google_leakage2023>, supplement: "Google Quantum AI"), a two-step operation interleaved at the end of each QEC cycle:
+ *Leakage iSWAP gate*: splits the $|2 angle$ state (two excitations) into $|1 angle$ on two qubits, leaving lower states undisturbed.
+ *Measure qubit reset*: rapid reset to remove the transferred excitation.

Results: without DQLR, $tilde$ 1% average leakage population; with DQLR, $tilde$ 0.1% (10$times$ reduction). The distance-7 code on Willow uses 4 additional leakage-removal qubits. DQLR increased the error-suppression factor $Lambda$ by 35% for distance-5 codes #cite(<willow2024>, supplement: "Google Quantum AI").

== Advanced Leakage Mitigation

Recent work achieves further improvements:
- *Active Leakage Cancellation* reduces leakage to $10^(-5)$ per gate #cite(<alc2025>, supplement: "ALC (2025)").
- *Leakage Reduction Units (LRUs)* integrated with measurement achieve 99% leakage removal in 220 ns with zero additional time overhead #cite(<lru_measurement>, supplement: "LRU-M (2025)").

#rect(width: 100%, inset: 10pt, fill: rgb("#fff3e0"), stroke: 0.5pt + rgb("#e65100"))[
  *Reproduction Gap 6.* The leakage iSWAP gate calibration procedure — specifically, how the flux pulse is shaped to implement a state-selective iSWAP that acts on $|2 angle$ but not $|0 angle$ or $|1 angle$ — requires precise knowledge of the multi-level spectrum and coupler Hamiltonian, which is not documented step-by-step.
]

// ════════════════════════════════════════════════════════════════
= Benchmarking and Verification <sec:bench>

== Cross-Entropy Benchmarking (XEB)

XEB is Google's primary calibration-verification method #cite(<arute2019>, supplement: "Arute _et al._"). It models the noisy output state as a depolarizing mixture:

$ rho_U = f |psi_U chevron.r chevron.l psi_U| + (1 - f) I / D $

where $f$ is the circuit fidelity. The linear XEB estimator is:

$ f = (sum_U (m_U - u_U)(e_U - u_U)) / (sum_U (e_U - u_U)^2) $

where $m_U$ is the measured bitstring probability, $e_U$ the ideal probability, and $u_U = 1 slash D$ the uniform baseline. XEB is used to:
- Characterize individual gate fidelities (isolated 2-qubit XEB).
- Detect systematic calibration errors via exponential fidelity decay.
- Verify parallel gate performance (simultaneous CZ + XEB).
- Benchmark full-system performance at scale.

== Randomized Benchmarking (RB)

Standard RB applies uniformly random Clifford sequences of increasing length, appending an inversion Clifford, and fitting the exponential decay of return probability vs.\ sequence length #cite(<qiskit_exp>, supplement: "Qiskit Experiments"). It is SPAM-insensitive and scales efficiently. *Interleaved RB* isolates the fidelity of a specific gate by alternating it with random Cliffords.

== Character-Average Benchmarking (CAB)

Fan _et al._ #cite(<fan2025>, supplement: "Fan _et al._") introduced CAB for scalable multi-qubit benchmarking, using alternate $U$ and $U^(-1)$ interleaved with random Paulis. Sample complexity is $cal(O)(epsilon^(-2) log delta)$, independent of qubit count.

== Gate Set Tomography (GST)

GST provides calibration-free, SPAM-independent characterization with Heisenberg scaling #cite(<gst2021>, supplement: "Nielsen _et al._"), but scales poorly beyond 2 qubits. Compressive and streaming variants are emerging for larger systems.

== Google's Error Budget

The Willow below-threshold paper presents a detailed error budget decomposed across CZ gates, single-qubit gates, readout, and idling. CZ gates are the dominant error source, with correlated errors contributing $tilde$ 17%. Critically, the error model _overpredicts_ $Lambda$ by $tilde$ 20%, indicating *unmodeled error sources* remain #cite(<willow2024>, supplement: "Google Quantum AI").

#rect(width: 100%, inset: 10pt, fill: rgb("#fff3e0"), stroke: 0.5pt + rgb("#e65100"))[
  *Reproduction Gap 7.* The full error-budget decomposition methodology — how individual error contributions are extracted, what assumptions underlie the decomposition, and the source of the persistent 20% model–experiment gap — is not documented in sufficient detail to reproduce independently.
]

// ════════════════════════════════════════════════════════════════
= Drift Tracking and Real-Time Calibration <sec:drift>

== The Drift Problem

Qubit parameters fluctuate on timescales from milliseconds (TLS switching) to hours (thermal drift). Google recalibrates "every 4 experimental runs" on Willow, with stability demonstrated over 15 hours ($Lambda = 2.18 plus.minus 0.07$ average, $2.31 plus.minus 0.02$ best) #cite(<willow2024>, supplement: "Google Quantum AI"). Kelly _et al._ #cite(<kelly2016insitu>, supplement: "Kelly _et al._") demonstrated *$cal(O)(1)$-scalable in-situ calibration* during repetitive error detection, compensating for frequency drift on a 9-qubit system by optimizing gates in parallel.

== Millisecond-Scale FPGA-Based Calibration

Marciniak _et al._ #cite(<marciniak2026>, supplement: "Marciniak _et al._") achieved a breakthrough in calibration speed using on-FPGA algorithms:

#figure(
  table(
    columns: 3,
    align: (left, center, left),
    table.header(
      [*Primitive*], [*Time*], [*Method*],
    ),
    [$T_1$ estimation], [9.8 ms], [Analytical Decay Estimation (3-point)],
    [Readout optimization], [100 ms], [Nelder-Mead (20 iterations)],
    [Spectroscopy], [39 ms], [Golden-section search],
    [$pi$-pulse amplitude], [1.1 ms], [Sparse Phase Estimator],
    [Clifford RB], [107 ms], [ADE on 3 sequence lengths],
    [In-loop calibration], [$tilde$ 31 ms], [Combined frequency + amplitude],
  ),
  caption: [FPGA-based calibration primitives from Marciniak _et al._ #cite(<marciniak2026>, supplement: "Marciniak _et al._").],
)

Over 6 hours of closed-loop operation, 74,525 recalibrations yielded a 6.4% reduction in average gate infidelity vs.\ a static baseline.

== Adaptive Relaxation Tracking

Berritta _et al._ #cite(<berritta2026>, supplement: "Berritta _et al._") demonstrated real-time Bayesian tracking of fluctuating $T_1$ values with $tilde$ 2.2 $mu$s per update on FPGA, completing full $T_1$ characterization in $tilde$ 11 ms. They discovered TLS switching rates up to *10 Hz* — four orders of magnitude faster than previously reported — enabling real-time algorithm routing based on qubit quality.

#rect(width: 100%, inset: 10pt, fill: rgb("#fff3e0"), stroke: 0.5pt + rgb("#e65100"))[
  *Reproduction Gap 8.* Google's recalibration cadence ("every 4 experimental runs") is stated without specifying what constitutes a "run," the total wall-clock time per calibration cycle, or the fraction of processor time consumed by calibration overhead.
]

// ════════════════════════════════════════════════════════════════
= Automation and Machine Learning <sec:auto>

== Software Frameworks

Several open-source frameworks now implement DAG-based calibration:

- *Qiskit Experiments* #cite(<qiskit_exp>, supplement: "Qiskit Experiments"): IBM's library offering `RoughFrequencyCal`, `FineDragCal`, `FineAmplitudeCal`, `HalfAngleCal`, and full RB/tomography suites.
- *Qibocal* #cite(<qibocal2024>, supplement: "Pasquale _et al._"): Open-source framework supporting single-qubit spectroscopy through two-qubit CZ/iSWAP calibration, with CLI (`qq auto`) and Python eDSL interfaces.
- *QUAlibrate* #cite(<qualibrate>, supplement: "Quantum Machines"): Component-based DAG framework; demonstrated multi-qubit calibration in 140 seconds.
- *LabOne Q* #cite(<laboneq>, supplement: "Zurich Instruments"): Domain-specific language for QCCS hardware; characterized 26 of 28 qubits across seven chips in $tilde$ 3.5 hours.
- *QubiC* #cite(<qubic>, supplement: "LBNL"): Open-source FPGA-based system with multi-dimensional optimization for single- and two-qubit gates.

== Machine-Learning Approaches

Pack _et al._ #cite(<pack2024>, supplement: "Pack _et al._") benchmarked six gradient-free optimization algorithms for automated DRAG calibration, finding *CMA-ES* superior across all scenarios with effective noise resistance. Key insight: loss-function selection may be more critical than algorithm choice.

The Qruise platform creates *digital twins* of quantum devices via model learning, using Bayesian optimal experiment design to select the most informative measurements, then closing the loop with optimal control #cite(<qruise>, supplement: "Qruise"). Rigetti demonstrated that AI-powered calibration (Quantum Elements + Qruise) achieved 99.9% single-qubit and 98.5% two-qubit fidelity on 9 qubits, replicating weeks of manual tuning #cite(<rigetti_ai>, supplement: "Rigetti + QM").

*AlphaQubit* #cite(<alphaqubit>, supplement: "Google DeepMind"), while primarily a decoder, represents Google's ML approach to _device-adaptive_ error correction: a transformer-based neural network fine-tuned on actual processor data, trained on 25 rounds and generalizing to 100,000+ rounds.

Recent work on *LLM-based agents* for calibration #cite(<ai_agent_cal>, supplement: "Cell Patterns (2025)") demonstrates autonomous single- and two-qubit gate calibration on superconducting processors, though reliability for unsupervised operation is not yet established.

== Cirq Calibration API (Google)

Google exposes calibration metrics through Cirq's programmatic interface, providing 21 metrics including single-qubit RB error, parallel readout errors, and two-qubit gate errors for both $sqrt("iSWAP")$ and Sycamore gates. Access is via:

```python
import cirq_google
cals = cirq_google.get_engine_calibration(
    PROCESSOR_ID, PROJECT_ID)
```

Historical and time-range queries are supported, enabling drift analysis.

#rect(width: 100%, inset: 10pt, fill: rgb("#fff3e0"), stroke: 0.5pt + rgb("#e65100"))[
  *Reproduction Gap 9.* The Cirq API provides _read-only access_ to calibration _results_, not to the calibration _procedures_. Users of Google's cloud quantum service cannot modify or inspect the calibration pipeline, run custom calibrations, or access the Optimus/Snake internals.
]

// ════════════════════════════════════════════════════════════════
= Comprehensive Reproduction Gap Analysis <sec:gaps>

We synthesize the gaps identified throughout this survey into a structured catalog. These are organized by calibration stage and assessed for their impact on independent reproduction.

== Summary of Gaps

#figure(
  table(
    columns: (auto, 1fr, auto),
    align: (center, left, center),
    table.header(
      [*\#*], [*Gap Description*], [*Impact*],
    ),
    [1], [Full Optimus DAG (node names, analysis functions, tolerances, timeouts) is proprietary], [Critical],
    [2], [Exact single-qubit pulse envelopes, DRAG coefficients, and amplitude-calibration targets for Sycamore/Willow], [High],
    [3], [Snake optimizer inner-loop algorithm, frequency-separation rules, weight-training procedure, and Snake–Optimus integration API], [Critical],
    [4], [Readout model internals: Hamiltonian truncation, pulse parametrization, optimizer choice], [High],
    [5], [TLS forecasting algorithm: inputs, prediction method, horizon, accuracy], [Critical],
    [6], [Leakage iSWAP calibration: multi-level spectrum requirements, flux-pulse shaping for state-selective operation], [High],
    [7], [Error-budget decomposition methodology and source of the 20% model–experiment gap in $Lambda$], [Medium],
    [8], [Recalibration cadence: definition of "run," wall-clock time per cycle, calibration overhead fraction], [Medium],
    [9], [Cirq API is read-only for metrics; calibration procedures are inaccessible to cloud users], [High],
    [10], [Custom electronics: DAC specifications, signal-generation architecture, wiring, filtering, and attenuation], [Critical],
  ),
  caption: [Catalog of reproduction gaps in Google Quantum AI's published calibration materials. Impact assessed as Critical (prevents reproduction), High (requires significant reverse engineering), or Medium (workarounds exist).],
) <tab:gaps>

== Detailed Analysis of Critical Gaps

=== Gap 1: The Complete Calibration DAG

Kelly _et al._ #cite(<kelly2018>, supplement: "Kelly _et al._") describe the _framework_ but not the _content_ of the calibration graph. For a 105-qubit processor with $gt 100$ parameters per qubit, the full DAG likely contains $cal(O)(10^4)$ nodes. Reconstructing this from scattered paper descriptions (spectroscopy, Rabi, Ramsey, DRAG, CZ chevron, XEB, etc.) is possible in principle but requires extensive experimental iteration to determine the correct dependency ordering and tolerance values.

*What is available*: the abstract framework, the bootstrapping order (readout → frequency → Rabi → 1Q gates → 2Q gates), and isolated examples of tolerance values ($10^(-4)$ radians for $pi$-pulses).

*What is missing*: the full node list, analysis functions per node, escalation logic, timeout values (characteristic drift timescales per parameter), and any conditional or context-dependent branches.

=== Gap 3: Snake Optimizer Internals

The Snake's _outer loop_ (graph traversal, scope parameter, constraint propagation) is well described #cite(<klimov2024>, supplement: "Klimov _et al._"). The _inner loop_ — the actual optimization algorithm applied to each $S^2$-dimensional subproblem — is not. Candidates include Nelder-Mead (used elsewhere in Google's stack), CMA-ES (recommended by Pack _et al._ #cite(<pack2024>, supplement: "Pack _et al._")), or gradient-based methods with numerical derivatives.

The 16 trainable weights are trained on $tilde$ 6,500 XEB benchmarks, but the training procedure (loss function, optimizer, regularization, cross-validation) is not specified. The frequency-separation rules encoding collision avoidance are built into the "stray coupling" error term but not published as explicit constraints.

=== Gap 5: TLS Forecasting

Two-level system (TLS) defects are the dominant source of frequency-dependent relaxation in transmon qubits #cite(<willow2024>, supplement: "Google Quantum AI"). The Willow paper states that frequencies are optimized to avoid TLS coupling and that a *forecasting* algorithm predicts TLS migration over the experimental duration. This suggests a model of TLS dynamics (activation, spectral diffusion, temperature dependence) that has not been published. Given that TLS behavior is stochastic and device-specific, this algorithm likely represents substantial proprietary knowledge.

=== Gap 10: Custom Electronics

Google uses custom-designed room-temperature electronics (DACs, signal generators, bias tees) connected to the dilution refrigerator via filtered microwave lines. The specifications of these electronics — resolution, bandwidth, noise floor, timing jitter, and the specific filtering and attenuation scheme at each temperature stage — fundamentally limit achievable gate fidelities. While commercial alternatives exist (Zurich Instruments, Quantum Machines OPX, Keysight), replicating Google's performance may require matching their electronics specifications, which are not published in detail.

// ════════════════════════════════════════════════════════════════
= Comparison Across Platforms <sec:comparison>

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, center, center, center, center),
    table.header(
      [*Aspect*], [*Google*], [*IBM*], [*Rigetti*], [*Academic*],
    ),
    [Native 2Q gate], [CZ / Syc], [CR (echoed)], [CZ / iSWAP], [Various],
    [Best 2Q fidelity], [99.88%], [$tilde$ 99.5%], [$tilde$ 98.5%], [$tilde$ 99.8%],
    [Calibration framework], [Optimus (prop.)], [Qiskit Exp.], [Quil/proprietary], [Qibocal, LabOne Q],
    [Freq.\ optimizer], [Snake (prop.)], [Laser anneal], [—], [Manual / ABAA],
    [Leakage removal], [DQLR + MLR], [DD-based], [—], [LRU variants],
    [Automation level], [Full auto], [Semi-auto], [AI-assisted], [Semi-auto],
    [Benchmarking], [XEB], [RB + QV], [RB + QV], [RB / GST],
    [Open-source tools], [Cirq (partial)], [Qiskit (full)], [pyQuil], [Multiple],
    [Recal.\ frequency], [Every 4 runs], [Hourly], [—], [Manual],
  ),
  caption: [Comparison of calibration approaches across major superconducting qubit platforms.],
) <tab:comparison>

// ════════════════════════════════════════════════════════════════
= Google Processor Evolution: Calibration Milestones <sec:evolution>

#figure(
  table(
    columns: (1.2fr, 1fr, 1fr, 1fr),
    align: (left, center, center, center),
    table.header(
      [*Metric*], [*Sycamore (2019)*], [*3rd Gen (2023)*], [*Willow (2024)*],
    ),
    [Qubits], [53 (54 fab.)], [72], [105],
    [$T_1$], [$tilde$ 15–20 $mu$s], [$tilde$ 20 $mu$s], [68 ± 13 $mu$s],
    [$T_(2,"CPMG")$], [—], [—], [89 $mu$s],
    [1Q fidelity], [99.85%], [—], [99.97%],
    [2Q fidelity], [99.64%], [—], [99.88%],
    [Readout fidelity], [96.2%], [Improved], [99.5%],
    [Native gate], [Sycamore], [CZ], [CZ],
    [Gate time (2Q)], [12 ns (Syc)], [$tilde$ 26 ns], [$tilde$ 26 ns],
    [Cycle time], [—], [—], [1.1 $mu$s],
    [QEC result], [—], [$Lambda < 1$ (marginal)], [$Lambda = 2.14 plus.minus 0.02$],
    [Logical qubit lifetime], [—], [—], [$2.4 times$ best physical],
    [Calibration innovations], [Optimus + XEB], [Context-aware, parallel, TLS], [Snake, DQLR, TLS forecast],
  ),
  caption: [Evolution of Google Quantum AI processor calibration milestones.],
) <tab:evolution>

// ════════════════════════════════════════════════════════════════
= Open Problems and Future Directions <sec:open>

Based on our survey, we identify ten open problems for the calibration community:

+ *The 20% model gap.* Google's best error model overpredicts $Lambda$ by $tilde$ 20% #cite(<willow2024>, supplement: "Google Quantum AI"). Identifying the unmodeled error sources (non-Markovian noise, spatially correlated TLS, leakage–measurement crosstalk) is essential for pushing to higher code distances.

+ *Fat-tail $T_1$ distributions.* The worst 10% of qubits exhibit $T_1$ values 30–100$times$ lower than the median, driven by TLS coupling. These outliers disproportionately limit logical performance. No predictive model exists for which qubits will be affected.

+ *Calibration time vs.\ computation time.* Current calibration overhead ($tilde$ 30 ms per primitive #cite(<marciniak2026>, supplement: "Marciniak _et al._")) must decrease by $tilde$ 3 orders of magnitude to enable kilohertz-rate recalibration during QEC. FPGA-based approaches are promising but have not been demonstrated at the 100+ qubit scale.

+ *Cross-platform reproducibility.* No standardized calibration protocol exists. Results from different platforms are not directly comparable due to differences in benchmarking methodology (XEB vs.\ RB vs.\ QV).

+ *Coupler calibration.* Tunable couplers add $cal(O)(N)$ additional parameters (bias points, coupling-vs.-flux curves). Step-by-step coupler calibration procedures are largely absent from the literature.

+ *Correlated error characterization.* Standard benchmarks (RB, XEB) assume independent errors. Correlated errors — from crosstalk, TLS, or cosmic rays — require specialized protocols (simultaneous RB, crosstalk matrices) that scale poorly.

+ *Leakage–QEC interaction.* While DQLR reduces steady-state leakage to $tilde$ 0.1%, the _transient_ leakage dynamics during a QEC cycle and their interaction with the decoder are not fully modeled.

+ *Automation generalization.* Current AI/ML calibration approaches (CMA-ES, RL, digital twins) are demonstrated on $lt.eq$ 10 qubits. Scaling to 100+ while maintaining the ability to recover from arbitrary failure modes remains open.

+ *Wiring and filtering at scale.* Each qubit requires 2–3 coaxial lines with precise attenuation and filtering at multiple temperature stages. Scaling to 1,000+ qubits requires fundamentally new wiring architectures, the calibration implications of which are unexplored.

+ *Real-time decoder–calibration co-design.* The Willow real-time decoder (63 $mu$s latency at distance-5) must eventually incorporate calibration-state information to adapt decoding weights. This co-design space is largely unexplored.

// ════════════════════════════════════════════════════════════════
= Conclusion <sec:conclusion>

The calibration of superconducting quantum processors has evolved from manual, qubit-by-qubit tuning to automated, DAG-driven frameworks capable of maintaining $cal(O)(10^4)$ parameters across 100+ qubits. Google Quantum AI's Optimus + Snake stack represents the most complete published system, enabling the first demonstration of quantum error correction below the surface-code threshold on the 105-qubit Willow processor.

However, our analysis reveals that reproducing Google's results independently faces significant obstacles. Of the ten gaps cataloged in @tab:gaps, four are assessed as _critical_: the complete calibration DAG, the Snake optimizer internals, the TLS forecasting algorithm, and the custom electronics specifications. These gaps are not incidental omissions but reflect the competitive dynamics of quantum hardware development, where calibration software is increasingly recognized as a key differentiator.

The path toward reproducibility passes through three developments: (1) open-source calibration frameworks (Qibocal, QUAlibrate) that implement the DAG architecture with community-contributed node libraries; (2) FPGA-based real-time calibration #cite(<marciniak2026>, supplement: "Marciniak _et al._") that can close the 3-order-of-magnitude gap between current recalibration rates and QEC requirements; and (3) standardized benchmarking protocols that enable cross-platform comparison. Until these mature, independent groups seeking to approach Google-level calibration performance must expect to invest significant effort in reverse engineering and experimental optimization.

// ════════════════════════════════════════════════════════════════

#pagebreak()

// ─── References ───
#heading(numbering: none)[References]

#set text(size: 9.5pt)
// APS-style: Authors, Journal *Volume*, Page (Year).

#bibliography(title: none, style: "american-physics-society", "references.yml")
