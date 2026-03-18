// Calibration Algorithm Testbed: Simulation and Experimental Design
#set document(
  title: "Calibration Algorithm Testbed: Simulation and Experimental Validation",
)
#set page(paper: "us-letter", margin: (x: 1in, y: 1in), numbering: "1",
  header: align(right, text(size: 9pt, fill: gray)[_Calibration Algorithm Testbed_]))
#set text(font: "New Computer Modern", size: 11pt)
#set par(justify: true, leading: 0.65em)
#set heading(numbering: "I.A.1.")
#show heading.where(level: 1): it => { v(1.2em); text(size: 14pt, weight: "bold")[#it]; v(0.4em) }
#show heading.where(level: 2): it => { v(0.8em); text(size: 12pt, weight: "bold")[#it]; v(0.3em) }
#show heading.where(level: 3): it => { v(0.5em); text(size: 11pt, weight: "bold", style: "italic")[#it]; v(0.2em) }

#align(center)[
  #text(size: 18pt, weight: "bold")[
    Calibration Algorithm Testbed: \ Simulation and Experimental Validation
  ]
  #v(0.6em)
  #text(size: 12pt)[_A Minimal Model for Testing Gap-Filling Methods_]
  #v(0.4em)
  #text(size: 10pt, fill: gray)[March 2026]
  #v(1.5em)
]

#rect(width: 100%, inset: 12pt, stroke: 0.5pt + gray)[
  #text(weight: "bold")[Abstract.] #h(0.3em)
  We propose a two-track testbed --- simulation and experiment --- for validating the four gap-filling methods developed in our companion document. Track A is a Python-based _digital twin_ of a transmon processor, built on QuTiP and scqubits, that models multi-level transmons with frequency-dependent $T_1$ (TLS defects), flux noise, readout noise, and tunable couplers. Track B defines a minimal experimental protocol on a 5--10 qubit testbed. For each of the four gaps (Optimus DAG, Snake optimizer, TLS forecasting, control electronics), we specify the simulation model, experimental protocol, benchmark metrics, and iteration procedure. The simulation enables rapid prototyping ($tilde 10^4$ calibration cycles/hour) before committing to cryostat time.
]

#v(1em)
#outline(title: "Contents", indent: 1.5em, depth: 2)
#pagebreak()

// ════════════════════════════════════════════════════════════════
= Overview

== Two-Track Approach

#figure(
  table(
    columns: (auto, 1fr, 1fr),
    align: (center, left, left),
    table.header([], [*Track A: Simulation*], [*Track B: Experiment*]),
    [Purpose], [Rapid prototyping, algorithm debugging, parameter sweeps], [Ground-truth validation, hardware-specific tuning],
    [Platform], [Python (QuTiP + scqubits + NumPy)], [Dilution refrigerator + control electronics],
    [Scale], [1--20 qubits (Hamiltonian); 100+ (noise model only)], [5--10 qubits (initial); 20+ (scaled)],
    [Speed], [$tilde 10^4$ calibration cycles/hour], [$tilde 10$--$100$ cycles/hour],
    [TLS], [Synthetic (configurable)], [Real (device-specific)],
    [Cost], [Desktop CPU/GPU], [Cryostat time],
  ),
  caption: [Comparison of the two testbed tracks.],
)

== What We Are Testing

Each gap-filling method maps to specific testable components:

#figure(
  table(
    columns: (auto, 1.5fr, 1.5fr, 1.5fr),
    align: (center, left, left, left),
    table.header([*Gap*], [*Component Under Test*], [*Simulation Test*], [*Experimental Test*]),
    [1], [DAG traversal: node ordering, tolerances, timeouts], [Synthetic drift + DAG scheduler], [Full bring-up on testbed chip],
    [3], [Snake optimizer: inner loop, error model, weight training], [Synthetic frequency landscape + optimizer], [CZXEB on multi-qubit device],
    [5], [TLS forecasting: 6 algorithms], [Synthetic TLS with known trajectories], [$T_1$ monitoring on real device],
    [10], [Electronics noise budget], [Noise injection into simulation], [Measure gate fidelity vs.\ noise floor],
  ),
  caption: [Mapping of gap-filling methods to testbed components.],
)

// ════════════════════════════════════════════════════════════════
= Track A: Simulation Model <sec:sim>

== Transmon Hamiltonian

The core simulator models $N$ transmon qubits with $L$ levels each (typically $L = 3$ to capture leakage). The single-qubit Hamiltonian for qubit $i$:

$ H_i = sum_(k=0)^(L-1) (k omega_i + binom(k, 2) alpha_i) |k angle.r angle.l k| $

where $omega_i$ is the $|0 angle.r arrow.r |1 angle.r$ transition frequency and $alpha_i$ is the anharmonicity.

For flux-tunable transmons, the frequency depends on external flux:
$ omega_i(Phi) = omega_i^("max") sqrt(|cos(pi Phi slash Phi_0)|) $

The coupling Hamiltonian between qubits $i$ and $j$:
$ H_(i j) = g_(i j)(a_i^dagger a_j + a_i a_j^dagger) $

with tunable coupling $g_(i j)(Phi_c)$ for tunable-coupler architectures.

=== Implementation

```python
# Core dependencies
import qutip as qt          # Lindblad master equation solver
import scqubits as scq      # Transmon spectrum computation
import numpy as np

class TransmonSimulator:
    """Minimal transmon processor simulator."""
    def __init__(self, n_qubits, n_levels=3):
        self.n_qubits = n_qubits
        self.n_levels = n_levels
        # Per-qubit parameters (randomized around design values)
        self.f01 = 5.0 + 0.5 * np.random.randn(n_qubits)      # GHz
        self.alpha = -0.20 + 0.01 * np.random.randn(n_qubits)  # GHz
        self.T1 = 50 + 20 * np.random.randn(n_qubits)          # us
        self.T2 = 60 + 20 * np.random.randn(n_qubits)          # us
```

== Noise Model

The noise model is the critical component---it must be realistic enough that calibration algorithms trained in simulation transfer to hardware.

=== Frequency-Dependent $T_1$ (TLS Landscape)

#rect(width: 100%, inset: 10pt, fill: rgb("#e3f2fd"), stroke: 0.5pt + rgb("#1565c0"))[
  *SIMULATION.* We model $T_1(f, t)$ as a background rate plus Lorentzian dips from $N_("TLS")$ synthetic defects:

  $ Gamma_1(f, t) = Gamma_(1,"bg")(f) + sum_(k=1)^(N_("TLS")) (g_k^2 gamma_k) / (gamma_k^2 + (f - f_("TLS",k)(t))^2) dot s_k(t) $

  where each TLS has: frequency $f_("TLS",k)(t)$ undergoing diffusion with $D = 2.2$ MHz/h#super[$1/2$], coupling $g_k tilde "LogNormal"(1, 0.5)$ MHz, linewidth $gamma_k tilde "Uniform"(0.05, 0.5)$ MHz, and switching state $s_k(t) in {0, 1}$ with rate $r_k tilde "LogUniform"(10^(-4), 1)$ Hz.
]

#rect(width: 100%, inset: 10pt, fill: rgb("#fce4ec"), stroke: 0.5pt + rgb("#c62828"))[
  *EXPERIMENT.* Measure $T_1$ at 50--100 frequency points across the qubit's tunable range. Repeat every 2--4 hours to build a time-resolved TLS map. This is swap spectroscopy.
]

=== Flux Noise (Dephasing)

#rect(width: 100%, inset: 10pt, fill: rgb("#e3f2fd"), stroke: 0.5pt + rgb("#1565c0"))[
  *SIMULATION.* Model $1/f$ flux noise with amplitude $A_Phi = 3 times 10^(-6)$ $Phi_0 slash sqrt("Hz")$. The dephasing rate at frequency $f$:
  $ Gamma_phi(f) = |d omega slash d Phi|_f dot sqrt(A_Phi dot ln(t_("gate") slash t_("IR"))) $
  This is maximum away from the sweet spot and zero at $f = f_("max")$.
]

#rect(width: 100%, inset: 10pt, fill: rgb("#fce4ec"), stroke: 0.5pt + rgb("#c62828"))[
  *EXPERIMENT.* Measure $T_2^*$ via Ramsey at multiple flux bias points. Extract $A_Phi$ from the parabolic dependence $1/T_2^*(Phi) prop |d omega / d Phi|$.
]

=== Readout Noise

#rect(width: 100%, inset: 10pt, fill: rgb("#e3f2fd"), stroke: 0.5pt + rgb("#1565c0"))[
  *SIMULATION.* Model as a confusion matrix per qubit:
  $ M = mat(1 - epsilon_0, epsilon_1; epsilon_0, 1 - epsilon_1) $
  with $epsilon_0 tilde "Uniform"(0.5%, 2%)$, $epsilon_1 tilde "Uniform"(1%, 5%)$, correlated with dispersive shift $chi$ and readout power.
]

#rect(width: 100%, inset: 10pt, fill: rgb("#fce4ec"), stroke: 0.5pt + rgb("#c62828"))[
  *EXPERIMENT.* Measure confusion matrix via repeated single-shot classification with qubit prepared in $|0 angle.r$ and $|1 angle.r$.
]

=== Gate Errors

#rect(width: 100%, inset: 10pt, fill: rgb("#e3f2fd"), stroke: 0.5pt + rgb("#1565c0"))[
  *SIMULATION.* Single-qubit gate error $= $ coherence-limited error $+$ calibration error:
  $ epsilon_("1Q") = t_g / (2 T_1) + t_g / (2 T_phi) + delta theta^2 / 2 + delta beta^2 dot (omega_R / alpha)^2 $
  where $delta theta$ is the rotation-angle miscalibration and $delta beta$ is the DRAG error. Two-qubit CZ error includes conditional-phase error, leakage, and stray-coupling contributions.
]

=== Parameter Drift

#rect(width: 100%, inset: 10pt, fill: rgb("#e3f2fd"), stroke: 0.5pt + rgb("#1565c0"))[
  *SIMULATION.* Inject realistic drift into all parameters:
  - Qubit frequency: Ornstein-Uhlenbeck process with $sigma = 25$ kHz, $tau = 6$ h.
  - $pi$-pulse amplitude: random walk with Allan deviation feature at $tilde 1000$ s.
  - $T_1$: TLS-driven telegraph noise (see above).
  - Readout: slow drift $sigma = 0.1%$/hour.
]

#rect(width: 100%, inset: 10pt, fill: rgb("#fce4ec"), stroke: 0.5pt + rgb("#c62828"))[
  *EXPERIMENT.* All of these drifts are naturally present. Log all calibration parameters with timestamps to build a drift database.
]

== Simulation Architecture

```python
class ProcessorModel:
    """Full processor model with noise, drift, and TLS."""
    def __init__(self, n_qubits, topology="linear"):
        self.qubits = [QubitModel(i) for i in range(n_qubits)]
        self.couplers = build_couplers(n_qubits, topology)
        self.tls_landscape = TLSLandscape(n_qubits, n_tls_per_qubit=5)
        self.clock = SimClock()  # tracks simulated wall-clock time

    def step_time(self, dt_hours):
        """Advance all drift/TLS processes by dt_hours."""
        self.tls_landscape.diffuse(dt_hours)
        for q in self.qubits:
            q.drift_frequency(dt_hours)
            q.update_T1(self.tls_landscape)

    def measure_T1(self, qubit_idx, frequency=None):
        """Simulate a T1 measurement with realistic noise."""
        ...

    def run_gate(self, gate_type, qubits, params):
        """Simulate a gate and return the fidelity."""
        ...

    def run_xeb(self, qubit_pairs, n_cycles, n_circuits):
        """Simulate cross-entropy benchmarking."""
        ...
```

The key design principle: the simulation exposes the _same API_ as the real hardware interface. Calibration algorithms are written once and run against either backend.

// ════════════════════════════════════════════════════════════════
= Testing Gap 1: DAG Traversal <sec:test_dag>

== Simulation Test Protocol

#rect(width: 100%, inset: 10pt, fill: rgb("#e3f2fd"), stroke: 0.5pt + rgb("#1565c0"))[
  *SIMULATION.*

  *Setup*: Initialize a 10-qubit `ProcessorModel` with randomized parameters. Implement the 52-node DAG from the gap-solutions document.

  *Test 1 --- Cold Start*: Run the full DAG from scratch (all nodes uncalibrated). Measure: total wall-clock time, number of failed nodes, final gate fidelities.

  *Test 2 --- Maintenance Under Drift*: After initial calibration, advance simulated time in 15-minute steps. At each step, call `maintain(target_node)` on the top-level node. Measure: number of recalibrations triggered, fidelity stability over 24 simulated hours.

  *Test 3 --- Diagnosis*: Inject a sudden parameter failure (e.g., $T_1$ drops by 50% on one qubit). Measure: time to detect, correct diagnosis path, recovery fidelity.

  *Test 4 --- Tolerance Sweep*: Sweep tolerance values for each node and measure the trade-off between recalibration frequency and fidelity stability. Identify the Pareto frontier.

  *Test 5 --- Timeout Sweep*: Vary timeout periods and measure the fraction of `check_state` calls that correctly avoid unnecessary recalibration (true negative rate) vs.\ missed drift events (false negative rate).
]

#rect(width: 100%, inset: 10pt, fill: rgb("#fce4ec"), stroke: 0.5pt + rgb("#c62828"))[
  *EXPERIMENT.*

  *Protocol*: Deploy the DAG on a 5--10 qubit chip. Run the full bring-up sequence. Measure total time and success rate. Then run maintenance for 24+ hours continuously, logging every `check_state`, `check_data`, and `calibrate` call with timestamps and outcomes.

  *Metrics*: Compare against manual calibration baseline (human expert or existing framework like Qibocal).
]

== Benchmark Metrics for Gap 1

#figure(
  table(
    columns: (1.5fr, 2fr, 1fr),
    align: (left, left, center),
    table.header([*Metric*], [*Definition*], [*Target*]),
    [Bring-up time], [Wall-clock from cold start to all nodes passing], [$< 30$ min (10Q)],
    [Bring-up success rate], [Fraction of qubits fully calibrated], [$> 95%$],
    [Maintenance overhead], [Fraction of time spent recalibrating vs.\ computing], [$< 10%$],
    [Drift detection latency], [Time from parameter shift to recalibration trigger], [$< 2 times$ timeout],
    [False positive rate], [Unnecessary recalibrations / total checks], [$< 5%$],
    [Diagnosis accuracy], [Correct root cause identified / total diagnoses], [$> 90%$],
    [Fidelity stability ($sigma$)], [Std.\ dev.\ of gate fidelity over 24 h], [$< 0.05%$],
  ),
  caption: [Benchmark metrics for DAG traversal testing.],
)

// ════════════════════════════════════════════════════════════════
= Testing Gap 3: Snake Optimizer <sec:test_snake>

== Simulation Test Protocol

#rect(width: 100%, inset: 10pt, fill: rgb("#e3f2fd"), stroke: 0.5pt + rgb("#1565c0"))[
  *SIMULATION.*

  *Setup*: Create a synthetic frequency landscape for 20--68 qubits on a 2D grid. Define the four error components (dephasing, relaxation, stray coupling, pulse distortion) using physically motivated functions. Plant known $T_1$ hotspots, collision zones, and pulse-distortion penalties.

  *Test 1 --- Error Model Accuracy*: Generate random frequency configurations; compute predicted errors via the 4-component model; compare against "ground truth" errors from the full Hamiltonian simulation. Measure $R^2$ and residual bias.

  *Test 2 --- Weight Training*: Generate $tilde 1000$--$6500$ synthetic CZXEB measurements at varied frequency configurations. Train the 16 weights via least-squares. Measure: prediction accuracy on held-out configurations, weight stability across training runs.

  *Test 3 --- Inner-Loop Optimizer Comparison*: Run the Snake with each candidate inner loop (grid search, Nelder-Mead, CMA-ES) at scope $S = 1, 2, 4, S_("max")$. Measure: final cycle error, runtime, reproducibility across 10 random seeds.

  *Test 4 --- Scaling*: Test on grid sizes $N = 9, 17, 37, 68, 105$. Measure cycle error and runtime scaling. Compare against published Google data (@tab:snake_scaling).

  *Test 5 --- Healing*: After Snake optimization, introduce 5--10 outlier qubits (simulating TLS events). Run the healing procedure. Measure: outlier suppression fraction, runtime vs.\ full re-optimization.
]

#rect(width: 100%, inset: 10pt, fill: rgb("#fce4ec"), stroke: 0.5pt + rgb("#c62828"))[
  *EXPERIMENT.*

  *Protocol (5--10 qubits)*: Measure the four characterization datasets (flux sensitivity, $T_1$ spectra, $Z Z$ couplings, pulse distortion). Run the Snake optimizer at $S = 1$ and $S = 2$. Measure CZXEB cycle errors before and after optimization.

  *Protocol (20+ qubits)*: Full Snake deployment with weight training from CZXEB data. Compare against manual frequency assignment by an expert.
]

== Benchmark Metrics for Gap 3

#figure(
  table(
    columns: (1.5fr, 2fr, 1fr),
    align: (left, left, center),
    table.header([*Metric*], [*Definition*], [*Target*]),
    [Cycle error reduction], [Optimized / unoptimized median cycle error], [$> 2 times$],
    [Error model $R^2$], [Predicted vs.\ measured cycle error correlation], [$> 0.8$],
    [Outlier fraction], [Gates with error $> 2 times$ median after optimization], [$< 5%$],
    [Runtime ($S = 2$, $N = 68$)], [Wall-clock for full optimization], [$< 5$ min],
    [Weight stability], [Std.\ dev.\ of weights across 10 training runs], [$< 20%$],
    [Scaling exponent], [Runtime $prop N^beta$; measure $beta$], [$beta < 2$],
  ),
  caption: [Benchmark metrics for Snake optimizer testing.],
) <tab:snake_scaling>

// ════════════════════════════════════════════════════════════════
= Testing Gap 5: TLS Forecasting <sec:test_tls>

== Simulation Test Protocol

#rect(width: 100%, inset: 10pt, fill: rgb("#e3f2fd"), stroke: 0.5pt + rgb("#1565c0"))[
  *SIMULATION.*

  This is the most critical simulation test because TLS behavior on real devices is slow to observe (hours--days). The simulation enables years of synthetic TLS data in minutes.

  *Setup*: Create a `TLSLandscape` with 5--20 synthetic TLS per qubit, each with:
  - Initial frequency drawn from $"Uniform"(4, 7)$ GHz
  - Coupling $g slash 2 pi tilde "LogNormal"(0.7, 0.5)$ MHz
  - Diffusion constant $D = 2.2$ MHz/h#super[$1/2$] (with per-TLS scatter $plus.minus 30%$)
  - Switching rate $r tilde "LogUniform"(10^(-4), 10)$ Hz
  - Linewidth $gamma tilde "LogNormal"(-1, 0.5)$ MHz

  Run the landscape forward in simulated time, generating synthetic $T_1$ measurements.

  *Test 1 --- Algorithm Accuracy*: For each of the 6 proposed algorithms, measure:
  - *Mean Absolute Error (MAE)* of predicted TLS frequency vs.\ actual, at horizons $tau = 1, 4, 12, 24$ h.
  - *Coverage probability*: fraction of true TLS positions within predicted 95% confidence interval.
  - *False alarm rate*: predicted TLS-in-band events that don't materialize.
  - *Miss rate*: actual TLS-in-band events not predicted.

  *Test 2 --- Frequency Allocation Quality*: Integrate each forecaster with a frequency allocator. Measure the fraction of time qubits spend with $T_1$ below a threshold ($< 20$ $mu$s) over 100 simulated hours.

  *Test 3 --- Robustness to Model Mismatch*: Vary the true $D$ by $plus.minus 50%$ from the assumed value. Measure degradation of forecast accuracy.

  *Test 4 --- Cosmic Ray Injection*: Every $tilde 600$ s, randomly scramble 3--5 TLS frequencies simultaneously. Measure detection latency and recovery time for each algorithm.

  *Test 5 --- Scaling*: Test with $N_("TLS") = 5, 20, 100, 500$ per qubit. Measure computational cost scaling.
]

#rect(width: 100%, inset: 10pt, fill: rgb("#fce4ec"), stroke: 0.5pt + rgb("#c62828"))[
  *EXPERIMENT.*

  *Protocol (1--3 qubits, 1--2 weeks)*:
  + Perform swap spectroscopy at the start of each cooldown to catalog TLS.
  + Monitor $T_1$ continuously at 1 measurement / 10 seconds at the operating frequency.
  + Every 4 hours, perform a $T_1$-vs.-frequency scan (50 points, 5 min).
  + Run each forecasting algorithm in parallel on the accumulated data.
  + Measure: which algorithm best predicts the next 4-hour $T_1$ trajectory?

  *Protocol (5--10 qubits, 1 month)*:
  + Deploy the best 2--3 algorithms from the single-qubit test.
  + Integrate with the Snake optimizer's relaxation-rate component.
  + Measure: improvement in median gate fidelity when TLS forecasting is active vs.\ static frequency assignment.
]

== Benchmark Metrics for Gap 5

#figure(
  table(
    columns: (1.5fr, 2fr, 1fr),
    align: (left, left, center),
    table.header([*Metric*], [*Definition*], [*Target*]),
    [MAE (4 h horizon)], [Mean absolute TLS frequency prediction error], [$< 5$ MHz],
    [Coverage (95% CI)], [Fraction of true positions within predicted interval], [$> 90%$],
    [Miss rate], [TLS-in-band events not predicted / total events], [$< 10%$],
    [False alarm rate], [False TLS-in-band predictions / total predictions], [$< 20%$],
    [$T_1$ time-below-threshold], [Fraction of time with $T_1 < 20$ $mu$s (with forecasting)], [$< 2%$],
    [Detection latency], [Time from TLS appearance to detection], [$< 30$ min],
    [Cosmic ray recovery], [Time from scramble event to re-optimized frequencies], [$< 5$ min],
  ),
  caption: [Benchmark metrics for TLS forecasting testing.],
)

// ════════════════════════════════════════════════════════════════
= Testing Gap 10: Electronics Noise Budget <sec:test_elec>

== Simulation Test Protocol

#rect(width: 100%, inset: 10pt, fill: rgb("#e3f2fd"), stroke: 0.5pt + rgb("#1565c0"))[
  *SIMULATION.*

  *Setup*: Add controllable noise injection to the gate simulation layer:
  - DAC amplitude noise: white noise with configurable SNR (50--70 dB).
  - Phase noise: colored noise with configurable spectral density ($-80$ to $-140$ dBc/Hz at 10 kHz offset).
  - Timing jitter: Gaussian jitter with configurable $sigma$ (0.1--10 ps).
  - Thermal photon noise: configurable mean photon number $bar(n) in [10^(-4), 10^(-1)]$.

  *Test 1 --- Noise-to-Fidelity Map*: Sweep each noise parameter independently while holding others at nominal values. Plot gate fidelity vs.\ noise parameter. Identify the noise level at which electronics noise begins to dominate over decoherence.

  *Test 2 --- Combined Budget*: Set all noise parameters to values corresponding to each commercial platform (ZI, QM, Qblox, Keysight, QICK). Predict achievable fidelity for each.

  *Test 3 --- Calibration Sensitivity*: Determine how much worse the calibration algorithms (DAG tolerances, Snake optimization) perform when electronics noise increases by $2 times$ and $5 times$.
]

#rect(width: 100%, inset: 10pt, fill: rgb("#fce4ec"), stroke: 0.5pt + rgb("#c62828"))[
  *EXPERIMENT.*

  *Protocol*: On the testbed chip with a specific electronics platform:
  + Measure 1Q and 2Q gate fidelity via RB.
  + Intentionally degrade signal quality (add attenuators, reduce DAC resolution via bit masking, add noise sources).
  + Measure fidelity at each degradation level.
  + Compare measured noise-to-fidelity curve against simulation predictions.
  + Validate that decoherence dominates at the nominal operating point.
]

// ════════════════════════════════════════════════════════════════
= Integration Test: Full Calibration Stack <sec:integration>

== End-to-End Test

The ultimate test combines all four gap-filling methods into a single calibration run:

#rect(width: 100%, inset: 10pt, fill: rgb("#e3f2fd"), stroke: 0.5pt + rgb("#1565c0"))[
  *SIMULATION (20-qubit processor, 48 simulated hours).*

  + $t = 0$: Cold start. Run full DAG bring-up (Gap 1).
  + $t = 0.5$ h: Run Snake optimizer for frequency assignment (Gap 3).
  + $t = 1$ h: Begin continuous operation with TLS forecasting active (Gap 5).
  + $t = 1$--$48$ h: Run simulated QEC cycles. Every 15 min:
    - DAG `maintain()` checks all nodes.
    - TLS forecaster updates predictions.
    - If TLS predicted in-band: trigger Snake healing.
  + Inject 3 cosmic ray events and 2 sudden $T_1$ drops.

  *Success criterion*: Median gate fidelity $> 99.5%$ sustained for 48 h with $< 15%$ calibration overhead.
]

#rect(width: 100%, inset: 10pt, fill: rgb("#fce4ec"), stroke: 0.5pt + rgb("#c62828"))[
  *EXPERIMENT (5--10 qubit processor, 24+ hours).*

  Same protocol on real hardware. Compare against baseline (manual calibration or Qibocal `qq auto`).
]

// ════════════════════════════════════════════════════════════════
= Iteration Workflow <sec:iteration>

== Development Cycle

#figure(
  align(center)[
    #rect(inset: 8pt, fill: rgb("#e3f2fd"), stroke: 1pt + rgb("#1565c0"))[
      *1. Implement algorithm*
    ]
    #v(0.3em)
    $arrow.b$
    #v(0.3em)
    #rect(inset: 8pt, fill: rgb("#e3f2fd"), stroke: 1pt + rgb("#1565c0"))[
      *2. Run simulation benchmarks* (minutes--hours)
    ]
    #v(0.3em)
    $arrow.b$
    #v(0.3em)
    #rect(inset: 8pt, fill: rgb("#fff3e0"), stroke: 1pt + rgb("#e65100"))[
      *3. Analyze: Does it meet targets?* (see metric tables)
    ]
    #v(0.3em)
    #grid(columns: 2, column-gutter: 2em,
      align(center)[
        $arrow.b$ No
        #v(0.3em)
        #rect(inset: 8pt, fill: rgb("#ffebee"), stroke: 1pt + rgb("#c62828"))[
          *4a. Debug/tune parameters* \ Go to step 2
        ]
      ],
      align(center)[
        $arrow.b$ Yes
        #v(0.3em)
        #rect(inset: 8pt, fill: rgb("#fce4ec"), stroke: 1pt + rgb("#c62828"))[
          *4b. Run on hardware* (days--weeks)
        ]
      ],
    )
    #v(0.3em)
    $arrow.b$
    #v(0.3em)
    #rect(inset: 8pt, fill: rgb("#e8f5e9"), stroke: 1pt + rgb("#2e7d32"))[
      *5. Compare sim vs.\ experiment* $arrow.r$ Update sim model $arrow.r$ Go to step 2
    ]
  ],
  caption: [Development iteration cycle. The simulation-first approach minimizes expensive cryostat time.],
)

== Key Design Principles

+ *Same API*: calibration code imports `ProcessorBackend` --- either `SimulatedProcessor` or `RealProcessor`. No algorithm changes between sim and experiment.
+ *Reproducibility*: all simulation runs use seeded RNG. All experimental data is timestamped and version-controlled.
+ *Metrics-driven*: every test reports the standardized metrics from the tables above. A CI/CD pipeline runs simulation benchmarks on every commit.
+ *Incremental complexity*: start with 1 qubit (test basic calibration nodes), then 2 qubits (test 2Q gates, couplers), then 5--10 (test Snake, TLS), then 20+ (test scaling).

// ════════════════════════════════════════════════════════════════
= Minimal Hardware Requirements <sec:hardware>

== Simulation Track

- Python 3.10+, QuTiP $gt.eq$ 5.0, scqubits, NumPy, SciPy, matplotlib.
- Desktop CPU: 4+ cores, 16 GB RAM (sufficient for 10-qubit Hamiltonian simulation).
- Optional GPU: NVIDIA with CuPy for parallelized noise simulation at 20+ qubits.

== Experimental Track

#figure(
  table(
    columns: (1.5fr, 2fr),
    align: (left, left),
    table.header([*Component*], [*Minimum Specification*]),
    [Qubits], [5--10 frequency-tunable transmons with tunable couplers],
    [Control electronics], [QICK (ZCU216) or OPX1000 or SHFQC+],
    [Dilution refrigerator], [Base $< 15$ mK, $> 400$ $mu$W at 4 K],
    [Readout amplifier], [TWPA or JPA at MXC, HEMT at 4 K],
    [DC bias sources], [24-ch, $< 20$ nV/$sqrt("Hz")$ noise (e.g., QDAC-II)],
    [Compute], [Linux server for real-time control and data analysis],
  ),
  caption: [Minimum experimental hardware for the testbed.],
)

// ════════════════════════════════════════════════════════════════
= Timeline <sec:timeline>

#figure(
  table(
    columns: (auto, 2fr, 1fr, 1fr),
    align: (center, left, center, center),
    table.header([*Phase*], [*Activity*], [*Sim*], [*Exp*]),
    [1], [Build `ProcessorModel` with TLS, drift, noise], [Weeks 1--4], [---],
    [2], [Implement 52-node DAG; test on 1--5 sim qubits], [Weeks 3--6], [---],
    [3], [Implement Snake optimizer; test on 10--20 sim qubits], [Weeks 5--8], [---],
    [4], [Implement 6 TLS forecasting algorithms; benchmark], [Weeks 6--10], [---],
    [5], [Electronics noise model; validate against specs], [Weeks 8--10], [---],
    [6], [Integration test: full stack on 20-qubit sim], [Weeks 10--12], [---],
    [7], [Deploy DAG on 5--10 qubit chip; cold-start bring-up], [---], [Weeks 10--14],
    [8], [Run TLS monitoring campaign (2 weeks continuous)], [---], [Weeks 14--16],
    [9], [Deploy Snake on testbed; measure CZXEB improvement], [---], [Weeks 16--20],
    [10], [Full integration test on hardware (24+ hours)], [---], [Weeks 20--24],
    [11], [Iterate: update sim model from experimental data], [Ongoing], [Ongoing],
  ),
  caption: [Development timeline. Simulation phases (blue) and experimental phases (red) overlap after week 10.],
)

// ════════════════════════════════════════════════════════════════
= Appendix: Software Architecture <sec:arch>

```
q-cali/
├── src/
│   ├── simulator/           # Track A: simulation
│   │   ├── transmon.py      # Single transmon model
│   │   ├── processor.py     # Multi-qubit processor model
│   │   ├── tls.py           # TLS landscape simulation
│   │   ├── noise.py         # Noise models (flux, readout, electronics)
│   │   └── backend.py       # SimulatedProcessor backend
│   ├── calibration/         # Gap 1: DAG framework
│   │   ├── dag.py           # DAG engine (maintain, diagnose)
│   │   ├── nodes/           # Individual calibration nodes
│   │   │   ├── spectroscopy.py
│   │   │   ├── rabi.py
│   │   │   ├── ramsey.py
│   │   │   ├── drag.py
│   │   │   ├── readout.py
│   │   │   ├── cz.py
│   │   │   └── ...
│   │   └── tolerances.py    # Default tolerance/timeout values
│   ├── optimizer/           # Gap 3: Snake optimizer
│   │   ├── snake.py         # Snake outer loop
│   │   ├── error_model.py   # 4-component error estimator
│   │   ├── inner_loop.py    # NM / CMA-ES / grid search
│   │   └── collision.py     # Frequency collision rules
│   ├── tls_forecast/        # Gap 5: TLS forecasting
│   │   ├── particle_filter.py
│   │   ├── hmm.py
│   │   ├── changepoint.py   # Algorithm 5 (most likely Google)
│   │   ├── gp_forecast.py
│   │   ├── neural_forecast.py
│   │   └── fpga_tracker.py
│   └── backend/             # Hardware abstraction
│       ├── base.py          # ProcessorBackend ABC
│       └── hardware.py      # RealProcessor backend (wraps Qibocal/QICK)
├── tests/                   # Unit + integration tests
├── benchmarks/              # Benchmark scripts (simulation)
├── notebooks/               # Jupyter analysis notebooks
├── docs/                    # PDF survey + gap solutions
├── pyproject.toml
└── README.md
```
