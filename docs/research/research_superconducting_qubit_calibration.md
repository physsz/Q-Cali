# Theoretical Foundations and Known Gaps in Superconducting Qubit Calibration

**Research compilation date: 2026-03-14**

---

## Table of Contents

1. [Hamiltonian Parameter Extraction](#1-hamiltonian-parameter-extraction)
2. [Qubit Spectroscopy and Calibration Protocols](#2-qubit-spectroscopy-and-calibration-protocols)
3. [T1/T2 Coherence Measurement and Calibration](#3-t1t2-coherence-measurement-and-calibration)
4. [Readout Optimization and Dispersive Shift Calibration](#4-readout-optimization-and-dispersive-shift-calibration)
5. [Flux-Tunable Transmon Calibration and Sweet Spot](#5-flux-tunable-transmon-calibration-and-sweet-spot)
6. [Parasitic Coupling Calibration](#6-parasitic-coupling-calibration)
7. [ZZ Coupling Mitigation and Calibration](#7-zz-coupling-mitigation-and-calibration)
8. [Leakage Reduction Calibration](#8-leakage-reduction-calibration)
9. [Gate Set Tomography for Calibration](#9-gate-set-tomography-for-calibration)
10. [Google Surface Code Calibration and Error Budget](#10-google-surface-code-calibration-and-error-budget)
11. [Scalability Challenges at Hundreds/Thousands of Qubits](#11-scalability-challenges-at-hundredsthousands-of-qubits)
12. [Calibration DAG and Dependency Structure](#12-calibration-dag-and-dependency-structure)
13. [Recent Automation Advances (2024-2026)](#13-recent-automation-advances-2024-2026)
14. [Key Google Publications (Klimov, Neill)](#14-key-google-publications-klimov-neill)
15. [QEC Threshold Calibration Requirements](#15-qec-threshold-calibration-requirements)
16. [Synthesis: Known Gaps and Open Problems](#16-synthesis-known-gaps-and-open-problems)

---

## 1. Hamiltonian Parameter Extraction

### Key Reference
- Dutkiewicz et al., "Robustly learning the Hamiltonian dynamics of a superconducting quantum processor," Nature Communications (2024).
  - arXiv: [2108.08319](https://arxiv.org/abs/2108.08319)
  - Published: [Nature Comms](https://www.nature.com/articles/s41467-024-52629-3)

### Methodology: TensorESPRIT Algorithm
A two-step identification method exploiting system structure:
1. **Step 1 — Frequency extraction**: Novel super-resolution technique called tensorESPRIT extends the classical ESPRIT algorithm (Estimation of Signal Parameters via Rotational Invariance Technique) to matrix-valued time series using tensor network techniques. Standard ESPRIT fails for N > 12 qubits due to spectral crowding; tensorESPRIT overcomes this via tensor denoising and rotational invariance computation.
2. **Step 2 — Eigenbasis reconstruction**: Non-convex optimization over the orthogonal group reconstructs Hamiltonian eigenspaces from the extracted frequencies.

### Precision Achieved
- **Sub-MHz accuracy** across all tested Hamiltonians
- Most entries deviated < 0.5 MHz from targets; some showed 1-2 MHz deviations
- Eigenfrequency implementation error: **0.32 +/- 0.00 MHz** for a 5-mode system
- Full Hamiltonian implementation error: up to 4x larger than frequency errors alone (due to eigenbasis reconstruction)
- Median frequency identification error: < 1 MHz across 51 different magnetic flux values

### Scale Demonstrated
- Up to **14 coupled superconducting qubits** on two Sycamore processors
- 27-qubit spatial error map constructed via overlapping 5-qubit subsets
- Significant variation in implementation errors across device components revealed

### SPAM Error Handling
- Pre-processing via initial ramp removal (pseudoinverse application)
- Post-processing for final ramp (fitting diagonal orthogonal estimate)
- Tomographic estimation of initial map via time-averaged formula
- Key finding: initial ramping produces substantially larger non-diagonal orthogonal components than final ramping

### Known Limitations
- **O(N^2) experimental time series** required (measuring N x N canonical coordinate expectations)
- Focuses exclusively on non-interacting (single-particle sector) Hamiltonian component
- Cannot generalize predictive power beyond single-particle sector without extensions
- Median T1 = 16.1 us, T2 = 5.3 us on Sycamore limits evolution duration
- Ramp distortions with ~100 ns response time after pre-distortion compensation
- 1000 measurement shots per expectation value required
- Linear inversion approaches fail for N > 20; structure exploitation extends range

### Gap: Theory vs. Practice
Sycamore #2 exhibited "much worse" overall implementation error than Sycamore #1, demonstrating device-to-device variability that purely theoretical Hamiltonian models cannot predict. The 20% model-experiment discrepancy in error budget (see Section 10) suggests unmodeled long-range or high-energy interactions.

---

## 2. Qubit Spectroscopy and Calibration Protocols

### Standard Calibration Sequence (Single-Qubit Tune-Up)

The canonical five-step protocol, as documented by Qblox and multiple experimental groups:

1. **Resonator spectroscopy** — Find frequency response of readout resonator when qubit is in |0>
2. **Qubit spectroscopy (two-tone)** — Find |0> -> |1> drive frequency (f01)
3. **Rabi oscillation** — Determine precise pi-pulse amplitude/duration
4. **Ramsey oscillation** — Fine-tune f01 and measure T2*
5. **T1 measurement** — Measure energy relaxation time

### References
- Qblox documentation: [Single transmon qubit characterization](https://docs.qblox.com/en/v0.11.1/applications/quantify/tuning_transmon_qubit.html)
- ENCCS Quantum Autumn School 2023: [Qubit Spectroscopy Analysis Tutorial](https://enccs.github.io/qas2023/notebooks/Qubit_Spectroscopy_Analysis/)
- Zurich Instruments: [Automated Transmon Qubit Tune-up](https://www.zhinst.com/sites/default/files/documents/2025-07/appnote_automated_transmon_2025.pdf)

### Spectroscopy Details
- **Pulsed vs. continuous**: Pulsed spectroscopy requires calibration of excitation power and readout timing; continuous is simpler but less precise
- **Saturation vs. pi-pulse excitation**: Pi-pulses give sharper spectral features but require prior Rabi calibration (circular dependency resolved by iterative refinement)
- From geometrical properties (design parameters), a rough frequency search range is established; the signal at the resonator frequency is monitored while sweeping the qubit drive frequency

### DRAG Pulse Calibration
DRAG (Derivative Removal by Adiabatic Gate) is essential for high-fidelity single-qubit gates on transmons:
- Adds derivative component to pulse shape compensating for anharmonicity
- Key parameter: beta = -1/(2*alpha), independent of amplitude and gate time (depends only on anharmonicity)
- **FAST DRAG** (Fourier Ansatz Spectrum Tuning): Achieved leakage error below 3.0 x 10^-5 down to 6.25 ns gate duration (20x reduction vs. conventional DRAG)
- **HD DRAG** (Higher-Derivative): Uses second-derivative terms for multiplicative spectral suppression
- Reference: [PRX Quantum 5, 030353 (2024)](https://link.aps.org/doi/10.1103/PRXQuantum.5.030353), arXiv [2402.17757](https://arxiv.org/html/2402.17757v1)

### When Does Numerical Optimization Help?
Critical analysis from arXiv [2511.12799](https://arxiv.org/html/2511.12799):
- At 20 ns gate time (T1=37 us, T2=9.6 us, alpha/2pi = -200 MHz):
  - DRAG coherent error: 4.9 x 10^-4
  - GRAPE coherent error: < 10^-15 (machine precision)
  - **Decoherence floor: ~7 x 10^-4** (dominated by T2 dephasing)
  - Result: both are decoherence-limited, DRAG only 1.2x above GRAPE
- **Critical crossover at ~15 ns**: Below this, DRAG fails and GRAPE becomes necessary
- **Robustness tradeoff**: DRAG maintains 0.990 fidelity over +/-5 MHz drift; GRAPE drops to 0.931 (7x worse)
- **Key insight**: "T2 improvement is the highest-leverage hardware upgrade"

---

## 3. T1/T2 Coherence Measurement and Calibration

### Temporal Fluctuations — The Fundamental Challenge

**Key Reference**: Dynamics of superconducting qubit relaxation times, npj Quantum Information (2022).
- URL: [Nature](https://www.nature.com/articles/s41534-022-00643-y)

Superconducting qubit T1 values fluctuate significantly over time due to interaction with two-level system (TLS) defects:
- Autocorrelation in T1 fluctuations introduces challenges for obtaining representative measurements
- T1 values can vary by factors of 2-3x over hours
- TLS defects fluctuate stochastically, coupling/decoupling to the qubit

**Decoherence Benchmarking Reference**: npj Quantum Information (2019).
- URL: [Nature](https://www.nature.com/articles/s41534-019-0168-5)

### Millisecond-Scale Calibration (State of the Art)

**Key Reference**: arXiv [2602.11912](https://arxiv.org/html/2602.11912v1) (2026)

On-FPGA closed-loop calibration achieving:

| Primitive | Latency | Conventional |
|-----------|---------|-------------|
| T1 estimation | **9.8 ms** | ~250 ms |
| Readout optimization | **100 ms** | seconds |
| Spectroscopic peak-finding | **39 ms** | hundreds of ms |
| Pi-pulse amplitude correction | **1.1 ms** | tens of ms |
| Clifford RB | **107 ms** | seconds |

**Sparse Sampling Techniques**:
- **Analytical Decay Estimation (ADE)**: Extracts exponential decay from only 3 measurement points using closed-form mathematics. SPAM-independent, minimal memory.
- **Sparse Phase Estimation (SPE)**: Determines phase offsets from 3 symmetrically placed points for frequency correction, pulse-amplitude calibration, DRAG adjustment.

**6-hour continuous recalibration experiment**:
- 74,525 calibration loops, 290 ms cycle time, ~31 ms in-loop latency
- **6.4% average reduction** in gate infidelity vs. static baseline
- T1 fluctuations tracked at 30 ms intervals (range: 14.5-27.5 us)
- Drive-frequency drift of +/-25 kHz monitored at 7.5 ms resolution

**Allan deviation analysis**:
- T1 fluctuations dominated by white noise plus Lorentzian components (characteristic timescale ~10 seconds)
- Amplitude parameters show non-monotonic structure at ~1000 seconds

### Calibration Implication
Under continuous recalibration, residual gate error becomes more tightly linked to instantaneous T1 while decoupling from frequency and amplitude drifts. This confirms that **coherence-limited errors set the ultimate floor** that calibration cannot cross.

---

## 4. Readout Optimization and Dispersive Shift Calibration

### Dispersive Readout Fundamentals
In circuit QED, the qubit state shifts the resonator frequency by the dispersive shift chi. Readout fidelity depends on:
- Readout pulse width and energy
- Resonator and qubit design parameters
- Qubit-resonator coupling strength
- Noise in the readout chain

### Dynamic Dispersive Shift Control
**Key Reference**: PRX Quantum 5, 040326 (2024)
- URL: [PRX Quantum](https://journals.aps.org/prxquantum/abstract/10.1103/PRXQuantum.5.040326)
- By dynamically reducing qubit-resonator detuning (increasing dispersive shift): **0.25% two-state readout error in 100 ns** integration time (beyond state-of-the-art)

### Measurement-Induced State Transitions (MISTs)

**Key Reference**: Phys. Rev. Applied 22, 064038 (2024), arXiv [2402.07360](https://arxiv.org/abs/2402.07360)

**Fundamental tradeoff**: Increased readout power shortens readout time and reduces state discrimination error, but promotes transitions to noncomputational states (|2>, |3>, ...).

**Mechanism**:
- Transitions arise from resonances between composite qubit-resonator energy levels
- For transmons: level bending causes resonances between computational and higher-lying states
- The critical parameter is NOT the dispersive approximation breakdown n_crit = Delta^2/(4g^2), which **overestimates** safe photon numbers
- Example: n_crit ~ 90 photons, but MISTs begin at n ~ 20 photons

**Calibration metrics for safe readout**:
- **Qubit purity** (1 - P0): Flat below transition region (~10^-3), jumps 100x (~10^-1) during MISTs
- **Dressed matrix element error**: Order-of-magnitude jump through transition regions; requires only time-independent Hamiltonian terms (no time-domain simulation)

**Mitigation strategies**:
- Flux tuning to avoid resonance conditions (omega_04 ~ 2*omega_r crossings)
- Resonator frequency optimization
- Accounting for dissipation effects (resonator decay increases MIST probability)

### Throughput Optimization
**Reference**: arXiv [2602.22174](https://arxiv.org/html/2602.22174) (2026)
- Goes beyond single-shot fidelity to Chernoff-based throughput optimization
- For high-duty-cycle QEC processors, the interplay between speed, noise, and nonlinearity requires careful temporal resource optimization

---

## 5. Flux-Tunable Transmon Calibration and Sweet Spot

### Sweet Spot Physics
The flux sweet spot is the maximum frequency point (f01_max) where first-order flux sensitivity vanishes (dω/dΦ = 0), providing protection against flux noise dephasing. Calibration protocols restrict target frequencies to one portion of the spectrum with buffers from both upper and lower sweet spots.

### ABAA Frequency Tuning (State of the Art)

**Key Reference**: arXiv [2407.06425](https://arxiv.org/html/2407.06425v1) (2024)

**Alternating-Bias Assisted Annealing (ABAA)**:
- Applied simultaneously to both Josephson junctions at room temperature
- Monitors resistance at each pulse cycle against predetermined threshold

**Precision across hundreds of qubits**:
- 10-fold reduction in spread: from 3.5% (untuned) to **0.34%** (tuned) across 221 qubits
- **Frequency-equivalent precision: 7.7 MHz** (0.17%)
- Tuning range capability: up to 18.5%
- 9-qubit processor empirical precision: 18.4 MHz standard deviation

**Scaling predictions**:
- 86% yield for 9-qubit chips at 7.7 MHz frequency spread
- ~182 yielded chips (1,638 qubits) per 6-inch wafer
- Chip yield does not drop to zero until exceeding **100-qubit chip scale**

**Post-tuning relaxation and aging**:
- Power-law relaxation with exponent 0.11 over days
- Junction-dependent relaxation is the **dominant factor in tuning imprecision**
- Requires pre-calibration of aging budgets (typically 2%)

**Two-qubit gate performance on ABAA-tuned devices**:
- Median iSWAP fidelities: 99.00% and 99.22% on two 9-qubit devices
- Peak fidelity: **99.51 +/- 0.20%**

### Flux Crosstalk Calibration (Machine Learning)

**Key Reference**: Phys. Rev. Applied 20, 024070 (2023)
- URL: [PRA](https://journals.aps.org/prapplied/abstract/10.1103/PhysRevApplied.20.024070)
- Learning-based calibration of flux crosstalk in transmon qubit arrays
- Relative flux crosstalk typically on the order of a few percent

### Dynamical Sweet Spot Engineering

**Key Reference**: PRX Quantum 3, 020337 (2022)
- URL: [PRX Quantum](https://link.aps.org/doi/10.1103/PRXQuantum.3.020337)
- Two-tone flux modulation creates effective dynamical sweet spots even away from the static sweet spot

---

## 6. Parasitic Coupling Calibration

### Flux Crosstalk in Large-Scale Circuits

**Key Reference**: arXiv [2105.14360](https://ar5iv.labs.arxiv.org/html/2105.14360)
- Approach relies on symmetries of superconducting circuits
- Automated for large-scale implementation
- Relative DC flux crosstalk: **few percent** in recent implementations

### Parasitic RF-SQUIDs from Wirebonds

**Key Reference**: arXiv [2505.20458](https://arxiv.org/abs/2505.20458) (2025)
- Parasitic Josephson junctions within wirebonds enclosed in superconducting loops create RF-SQUIDs
- Add decoherence channels and can **completely spoil qubit operability**
- Represent a fundamental packaging/fabrication challenge

### Tunable Coupler Approaches

Tunable couplers mediate qubit-qubit interactions, allowing couplings to be turned on/off. They mitigate:
- Parasitic coupling
- Frequency crowding
- Control crosstalk
- Leakage to non-computational states

**Phase modulation scheme** (arXiv [2510.20192](https://arxiv.org/html/2510.20192v1)):
- Provides decoupled control knob for coupling strength
- No parasitic frequency shifts
- Greatly simplifies calibration process

### TLS Defect Detection

**Reference**: NTT Press Release (2022)
- Novel method for detecting parasitic defects in superconducting qubits
- Paves way for systematic defect removal in quantum processors

---

## 7. ZZ Coupling Mitigation and Calibration

### Comprehensive Theory of ZZ Coupling

**Key Reference**: arXiv [2408.15402](https://arxiv.org/abs/2408.15402) (2024)

**Definition**: ZZ coupling (cross-Kerr term) is the state-dependent energy shift:
```
zeta = E'_11 - E'_10 - E'_01 + E'_00
```

**Sources in transmon architectures**:
1. Capacitive couplings between qubits and couplers
2. Level-repulsion effects from avoided crossings
3. Excitation-conserving mechanisms (coupled intermediate states)
4. Non-excitation-conserving mechanisms (higher-order corrections)

### Impact on Gate Fidelity

For an iSWAP gate with ZZ coupling:
```
F = 1 - (3/10)[1 - cos(zeta_bar * t_g)]
```
For weak coupling: F ~ 1 - (3/20)(zeta_bar * t_g)^2

**Critical threshold**: With t_g = 100 ns, T1 = 100 us:
- ZZ coupling must be below **~2pi x 100 kHz** for it not to dominate the error budget
- For CZ gates: required ZZ ~ **2pi x 5 MHz**, tunable between 100 kHz - 5 MHz

### Analytical Framework
- Schrieffer-Wolff perturbation theory with diagrammatic expansion
- Anharmonic oscillator approximation valid when E_C/E_J << 1
- State-assignment algorithm maps to "stable marriage problem" for eigenstate labeling

### Mitigation Strategies
1. **Parametric control**: Complete removal of residual ZZ + driven CZ gates
2. **Tunable C-shunt flux couplers**: More efficient than tunable transmon couplers
3. **AC Stark shift method**: Weak microwave drive on coupler for ZZ cancellation
4. **Driven resonator**: Amplitude and frequency as control knobs to neutralize static ZZ

### Crosstalk Spatial Scaling

**Key Reference**: arXiv [2512.18148](https://arxiv.org/html/2512.18148) (2025)

Unified scaling law:
```
J_ij = J_0 * K_0(kappa * d_ij) * f(Delta_omega_ij)
```
- Exponential decay with distance, characteristic length ~8.3 mm (~1 lattice spacing)
- Long-range couplings suppress algebraically with detuning: ~1/Delta_ij

**Quantitative nearest-neighbor values**:
- Range: 401 kHz to 1.064 MHz (mean 623 kHz, std 173 kHz)
- ZZ at distance D=1: ~22 kHz; D=2: ~5 kHz; D=3: ~2.5 kHz (~4x reduction D=1 to D=3)

**Critical finding**: Naive frequency-independent models overestimate non-nearest-neighbor interactions by **5-10x**. Frequency-aware models required for accurate calibration.

### Open Problems
- Applicability to larger systems with higher-order couplings (ZZZ, etc.)
- Extension to alternative qubit types (fluxonium, different anharmonicities)
- Systematic study of non-excitation-conserving fifth-order corrections
- Optimization across multi-qubit arrays simultaneously

---

## 8. Leakage Reduction Calibration

### The Leakage Problem
Transmon qubits have weak anharmonicity (alpha ~ -200 to -350 MHz), making the |1> -> |2> transition accessible during fast gate operations. Leakage is particularly harmful for QEC because it creates non-Pauli errors.

### Approach 1: Closed-Loop Optimal Control
**Reference**: npj Quantum Information (2020), [Nature](https://www.nature.com/articles/s41534-020-00346-2)
- Simultaneous adaptation of all control parameters via Clifford-gate cost function
- Achieved: **4.16 ns single-qubit pulse, 99.76% fidelity, 0.044% leakage**

### Approach 2: Active Leakage Cancellation (ALC)
**Reference**: arXiv [2503.14731](https://arxiv.org/html/2503.14731v1) (2025)

Second drive tone at leakage transition frequency (f21) destructively interferes with population transfer:
- **10-20 fold reduction** in leakage vs. standard DRAG
- For alpha = 158 MHz: leakage from 1.8 x 10^-4 to **1.5 x 10^-5** at 12 ns
- For alpha = 196 MHz: leakage from 1.5 x 10^-4 to **9.2 x 10^-6** at 9.75 ns
- ALC drive amplitude: ~10-20% of main pulse
- Calibration: Ramsey Error Filter (REF) sequence with two-parameter optimization (amplitude + detuning)

**Limitation**: Incoherent background heating of ~5 x 10^-6 per gate sets a floor. Iterative calibration underperforms simultaneous global optimization by 2-3x.

### Approach 3: FAST DRAG Pulse Shaping
**Reference**: PRX Quantum 5, 030353 (2024)
- Leakage error below **3 x 10^-5** down to 6.25 ns gate duration
- 7x reduction vs. previous record at 6.2 ns gates
- Calibration parameters are "mostly decoupled," simplifying optimization

### Approach 4: Leakage Reduction Units (LRUs)

**All-Microwave LRUs**: arXiv [2302.09876](https://arxiv.org/html/2302.09876) (2023)
- Microwave drive transfers |f> population to |g> via intermediate resonator modes
- **99% leakage removal** from |2> state in 220 ns
- AC-Stark shift of ~71 kHz correctable by virtual Z gates
- Average gate fidelity: 98.9%
- In QEC: error detection increase reduced from ~8% to ~2% over 50 rounds

**LRUs Integrated into Measurement**: arXiv [2511.17460](https://arxiv.org/html/2511.17460) (2025)
- **98.4% leakage removal** from |f> state, zero time overhead
- 99.2% assignment fidelity for two-level readout maintained
- Three-level readout (3RO) capability transforms leakage into heralded errors
- In distance-3 repetition code: 54% improvement in error suppression factor with LRU + 3RO

### Key Gap
LRUs for higher excited states (|3>, |4>) exist but become progressively more complex. Measurement-induced transitions to these higher states during readout remain an unsolved source of leakage in scaled systems.

---

## 9. Gate Set Tomography for Calibration

### Key Reference
- Nielsen et al., "Gate Set Tomography," Quantum 5, 557 (2021)
  - URL: [Quantum Journal](https://quantum-journal.org/papers/q-2021-10-05-557/)
  - Introduction: arXiv [1509.02921](https://arxiv.org/abs/1509.02921)

### Core Innovation: Calibration-Free Characterization
GST characterizes all operations in a gate set simultaneously and self-consistently, **without relying on pre-calibrated state preparations and measurements (SPAM)**. This is its defining advantage over quantum process tomography (QPT).

### Mathematical Properties
- Parameterizes gate sets as CPTP maps via Choi-Jamiolkowski isomorphism
- Inherent **gauge freedom**: multiple equivalent descriptions produce identical predictions
- Gauge-fixing procedures required for physically meaningful parameters
- Long-sequence protocol achieves **Heisenberg scaling** (1/N uncertainty)

### Comparison with Other Methods

| Method | SPAM-independent | Detailed gate info | Scalability | Computational cost |
|--------|-----------------|-------------------|-------------|-------------------|
| GST | Yes | Full process matrix | Poor (multi-qubit) | High |
| RB | Yes (average) | Average fidelity only | Good | Low |
| QPT | No | Full process matrix | Poor | Medium |
| IRB | Partially | Single-gate average | Good | Low |
| XEB | Yes (correlation) | Aggregate fidelity | Good | Medium |

### Practical Limitations
- **Computational complexity** scales exponentially with qubit count
- Full GST for multi-qubit (> 2) systems is extremely resource-intensive
- Data requirements scale with Hilbert space dimension
- **Compressive GST** (PRX Quantum 4, 010325) reduces circuit count via randomized sampling
- **Streaming GST** with extended Kalman filter (arXiv [2306.15116]) enables real-time tracking

### Calibration Applications
- Reveals systematic errors (over/under-rotation, drift)
- Identifies context-dependent errors and crosstalk
- Enables iterative feedback loop for gate optimization
- Certified gate quality below fault-tolerance thresholds in trapped-ion systems

### Implementation
- **pyGSTi**: Open-source Python implementation
- Handles maximum-likelihood estimation, gauge fixing, error analysis

---

## 10. Google Surface Code Calibration and Error Budget

### Below-Threshold Results (Willow Processor, 2024)

**Key Reference**: Nature 638, 920 (2025), arXiv [2408.13687](https://arxiv.org/abs/2408.13687)

**Processor**: 105-qubit superconducting processor
- Mean T1: **68 us**
- Mean T2,CPMG: **89 us**

**Surface Code Performance**:
- Distance-7 code: Lambda = **2.14 +/- 0.02** (neural network decoder)
- Logical error per cycle: epsilon_7 = **(1.43 +/- 0.03) x 10^-3**
- Logical qubit lifetime: **291 +/- 6 us** (2.4x best physical qubit)
- Real-time decoder average latency: **63 +/- 17 us** (distance-5, up to 1M cycles)

### Error Budget Breakdown (72-qubit processor simulation)

| Error Source | Contribution | Notes |
|---|---|---|
| CZ gate errors (local) | **Largest** | Dominant source |
| CZ stray interactions | Significant | ZZ and swap-like errors |
| Data qubit idle errors | Moderate | During measurement/reset cycles |
| Measurement/reset errors | Moderate | Signal classification and state prep |
| Leakage | Moderate | To higher transmon states |
| Single-qubit gate errors | Small | Well-calibrated |
| **Correlated errors (total)** | **~17% of budget** | Cross-qubit effects |

**Model-experiment gap**: Simulations overpredicted Lambda by **~20%**, indicating unidentified error mechanisms. Suspected contributors:
- Out-of-model long-range interactions
- High-energy leakage events
- Higher detection probability increasing with code distance (parasitic couplings, finite-size effects)

### Calibration Procedures for QEC
1. **Frequency optimization**: Forecasts TLS defect frequencies to avoid qubit-TLS coupling during calibration
2. **Recalibration interval**: Every 4 experimental runs over 15-hour stability tests
3. **Context-aware parallel calibrations**: Minimize drift, optimize for QEC circuit structure
4. **Leakage mitigation (DQLR)**: Data qubit leakage removal via neighbor swap; **35% improvement** in Lambda for distance-5

### Key Insight
"Continuing to improve both coherence and calibration will be crucial to further reduce logical error." — The 20% model gap represents a concrete, unresolved challenge.

### Previous Milestone (2023)

**Reference**: arXiv [2207.06431](https://arxiv.org/abs/2207.06431)
- 72-qubit processor, distance-5 surface code
- First demonstration that scaling surface code slightly surpasses subset performance
- Established that Google's system has sufficient performance for error suppression

### CaliQEC: In-Situ Calibration for QEC

**Reference**: ISCA 2025, [ACM](https://dl.acm.org/doi/10.1145/3695053.3731042)
- Integrates calibration directly within QEC cycles
- Calibration and correction at kilohertz rates (10x faster than drift onset)
- Total closed-loop latency must remain under **a few tens of microseconds**

---

## 11. Scalability Challenges at Hundreds/Thousands of Qubits

### The Tyranny of Calibration

**Key Reference**: Oxford Ionics blog, [link](https://www.oxionics.com/blogs/the-tyranny-of-calibration-in-quantum-computing/)

Quantitative scaling analysis:
- Typical QPU: dozens of signal sources per qubit, each with dozens of parameters
- **Hundreds of parameters per qubit** are dynamically updated during calibration
- At **100 qubits**: full recalibration ~once/day, takes **up to 2 hours**
- At **1000 qubits**: system becomes "effectively unusable" due to constant recalibration
- Rate of outlier qubit emergence is **proportional to qubit count**
- "At scale, calibration time can exceed useful uptime unless automation and hierarchy are designed in from day one"

### Scaling Roadmap

**Key Reference**: arXiv [2411.10406](https://arxiv.org/html/2411.10406v2) (2024)

| Scale | Key Challenge | Calibration Impact |
|-------|--------------|-------------------|
| 100 qubits | TLS defect fluctuations | Daily 2-hour recalibration |
| 1000 qubits | Control electronics cost + thermal budget | Constant recalibration needed |
| 10k qubits | Real-time QPU characterization OS needed | Offline analysis insufficient |
| 100k+ qubits | HPC-integrated real-time decoding | Full system co-design required |

### Hardware Error Distribution

**Critical observation**: Best-case qubit metrics mask system-level problems. For published Google and IBM data, "the worst 10% of T1 data drops significantly (**30-100x**) away from a Gaussian distribution." This fat-tail distribution means system performance degrades faster than average-case metrics suggest.

### Wiring and Infrastructure

- Cryostat for 150-qubit processor with coaxial wires: **$5M**, with **$4M for wiring alone**
- Without circulators: **10-100x more qubits per fridge**; potentially 20k qubits on single 14x14 cm die
- But: EM simulations validated only for ~6 qubits; scaling to thousands is an open problem

### Proposed Solutions

1. **GPU-accelerated DAG-based calibration** with reinforcement learning
2. **Improved fabrication** to reduce TLS defects and outlier rates
3. **Hardware-aware calibration protocols**: 8-25x reduction in overhead vs. sequential calibration (ISCA 2025)
4. **Hierarchical calibration**: Coarse/fine multi-pass approaches
5. **In-situ calibration during QEC** (CaliQEC approach)

### Timeline
Utility-scale quantum computers (1-10M physical qubits) projected for **2030-2035**, requiring "a major increase in the rate of progress over the next five years" — substantially driven by solving calibration scaling.

---

## 12. Calibration DAG and Dependency Structure

### Foundational Framework: Optimus

**Key Reference**: Kelly et al., "Physical qubit calibration on a directed acyclic graph," arXiv [1803.03226](https://arxiv.org/abs/1803.03226) (2018)
- From the Martinis group at UCSB/Google

### DAG Node Structure

Each calibration node contains five attributes:
1. **Target parameters** (e.g., pulse duration, frequency)
2. **Dual scan protocols**: minimal-data `check_data` and comprehensive `calibrate`
3. **Analysis functions** for both scan types plus supplementary checks
4. **Tolerance thresholds** for figures of merit
5. **Timeout periods** reflecting expected parameter drift timescales

### Three Interaction Methods

| Method | Data Required | Purpose |
|--------|--------------|---------|
| `check_state` | None | Passes if: within timeout, no failed dependencies, no recalibrated dependencies |
| `check_data` | Minimal | Determines if parameter matches expectation; distinguishes in-spec / out-of-spec / bad-data |
| `calibrate` | Full | Complete calibration loop with extensive data acquisition |

### Graph Traversal Algorithms

**Maintain Algorithm**:
1. Call maintain on desired calibration node
2. Recursively traverse to root node
3. At first failing `check_state`: run `check_data`
   - In spec: proceed upward
   - Out of spec: run `calibrate`, then proceed
   - Bad data: call `diagnose`

**Diagnose Algorithm**:
1. Invoked when `check_data` identifies bad data (experimental mismatch)
2. Investigate each dependent recursively
3. For each: in-spec -> continue; out-of-spec -> calibrate; bad data -> recurse

### Cyclic Dependency Resolution
"Unwrap cyclic dependence into layers of coarse, mid, and fine calibration" — iteratively refine through parameter space. Alternatively: design a single cal scan optimizing both parameters simultaneously.

### Example Dependency Flow
```
Root: Measurement calibration
  -> Qubit frequency (depends on measurement)
    -> Rabi driving (depends on frequency)
      -> Single-qubit gates (depends on Rabi + frequency)
        -> Two-qubit gates (depends on SQ gates + coupling calibration)
```

### Scalability Limitation
"Manual control is not scalable, so a fully autonomous solution is desireable to operate systems with more than a few dozen qubits." The paper provides the framework but **no concrete parameter values, error budgets, or complete calibration sequence** — these are platform-specific.

### Modern Implementations

**Qibocal** (arXiv [2410.00101](https://arxiv.org/html/2410.00101v1), 2024):
- Open-source framework within Qibo ecosystem
- Supports both DAG-based (YAML runcards) and programmatic (Python eDSL) execution
- DAGs "purposefully prevent cyclic dependencies" and "any runtime conditional" — Python approach offers greater flexibility
- Calibration routines: spectroscopy, Rabi, Ramsey, T1/T2, DRAG, RB, QPT/QST, CHSH/Mermin
- Monitoring: Docker + Grafana + PostgreSQL, 30-minute measurement intervals
- Limitation: As of v0.1.0, focused on superconducting platforms; cross-resonance CNOT "in progress"

**QUAlibrate** (Quantum Machines):
- URL: [QUAlibrate Documentation](https://qua-platform.github.io/qualibrate/)
- Calibration graphs as DAGs with adaptive branching based on results

**Zurich Instruments Automated Tune-Up**:
- URL: [Application Note](https://www.zhinst.com/sites/default/files/documents/2025-07/appnote_automated_transmon_2025.pdf)
- Automated transmon qubit tune-up in magnetic refrigerator

---

## 13. Recent Automation Advances (2024-2026)

### AI/ML-Driven Calibration

**Agent-Based AI Framework** (Patterns, 2025):
- URL: [Cell/Patterns](https://www.cell.com/patterns/fulltext/S2666-3899(25)00220-X)
- Automating quantum computing laboratory experiments with agent-based AI

**Reinforcement Learning for QEC** (arXiv [2511.08493](https://arxiv.org/html/2511.08493v1), 2025):
- RL calibrates the system while continuing logical computation
- Utilizes information in error detection events
- Significant advantage over separate calibration + code deformation

**Statistical Model Checking** (arXiv [2507.12323](https://arxiv.org/pdf/2507.12323), 2025):
- Tailored quantum device calibration with statistical verification

### Automated Spin Qubit Tuning (2025)
- arXiv [2506.10834](https://arxiv.org/html/2506.10834v1)
- All-RF tuning: median 15 minutes per qubit
- 12 distinct charge transitions identified in under 17 hours

### Hardware-Aware Calibration Protocol
- ISCA 2025: [ACM](https://dl.acm.org/doi/10.1145/3695053.3731036)
- **8-25x reduction** in total calibration overhead vs. sequential calibration

### Key Trend
Calibration is transitioning from manual/sequential to **autonomous, concurrent, ML-assisted** workflows. The DAG framework remains foundational but is being augmented with:
- Real-time inference on FPGA
- Reinforcement learning for continuous adaptation
- Statistical model checking for verification
- GPU acceleration for large-scale optimization

---

## 14. Key Google Publications (Klimov, Neill)

### Klimov et al. — "Optimizing quantum gates towards the scale of logical qubits"

**Citation**: Nature Communications 15, 2442 (2024)
- URL: [Nature Comms](https://www.nature.com/articles/s41467-024-46623-y)
- arXiv: [2308.02321](https://arxiv.org/abs/2308.02321)
- PubMed Central: [PMC10948820](https://pmc.ncbi.nlm.nih.gov/articles/PMC10948820/)

**Hardware**: Sycamore processor, N=68 frequency-tunable transmon qubits, 109 tunable couplings

**Configuration Space**:
- 68 idle frequencies + ~109 interaction frequencies = **~177 optimization variables**
- Problem is "non-convex, highly constrained, time-dynamic, and expands exponentially with processor size"

**Snake Optimizer**:
- Graph-based algorithm splitting the ~177D problem into lower-dimensional subproblems via scope parameter S
- S=1: 177 independent 1D problems (local limit)
- S=2: ~3N/S^2 problems of dimension ~S^2
- Optimal: S=2-4 (intermediate dimensions)
- S_max (full 177D): actually **underperforms** due to optimization landscape complexity

**Performance Results**:

| Configuration | Mean cycle error e_c | Notes |
|---|---|---|
| Random baseline | 16.7 x 10^-3 (wide distribution) | N=68 |
| Snake S=2 | **7.2 x 10^-3** | Approaches crossover standard |
| Snake S=4 | Best performance | Optimal scope |
| Snake S_max (177D) | 10.8 x 10^-3 | Underperforms |

**Error Source Mitigation (4 categories, ~40,000 error components, 16 trainable weights)**:
1. **Dephasing**: Bias toward maximum frequencies (flux-insensitive)
2. **Relaxation**: Avoid TLS defect hotspots and control/readout circuitry coupling
3. **Stray coupling**: Disperse frequencies to avoid parasitic coupling collisions
4. **Pulse distortion**: Constrain frequency excursions via checkerboard patterns

**Scalability**:
- Saturation model: e_c(N) = e_sat - e_scale * exp(-N/N_sat)
  - N_sat = 22 +/- 10 (saturation constant)
  - e_sat = 7.5 +/- 0.4 x 10^-3 (saturated error)
  - e_scale = 3.1 +/- 0.4 x 10^-3 (scaling penalty)
- Snake provides **3.7x improvement** in saturated error, **5.6x** in scaling penalty
- **Linear runtime scaling**: ~3.6 +/- 0.1 seconds per added qubit at S=2
- Stitching parallelization: processor split into R disjoint regions
  - N=1057 (d=23) simulated with R=4: e_c = 6.3 x 10^-3
  - Projected to N~10^4 with R=128 within 0.5-hour runtime budget

**Snake Healing**: Surgically re-optimizes outliers: ~48% outlier suppression, >10x faster than full re-optimization

**Key insight**: "Competition between error mechanisms" means individual mitigation strategies show minimal gain; combined activation essential.

### Neill et al. — "A blueprint for demonstrating quantum supremacy with superconducting qubits"

**Citation**: Science 360, 195-199 (2018)
- URL: [Science](https://www.science.org/doi/abs/10.1126/science.aao4309)

**Key contributions**:
- Explored scaling from 5 to 9 qubits, projecting to ~60 qubits
- **Scalable calibration approach**: Modeled Hamiltonian using only single-qubit calibrations, accurate even with all couplers active simultaneously
- Introduced cross-entropy benchmarking (XEB) as calibration benchmark
- Laid groundwork for 2019 quantum supremacy demonstration on Sycamore

### Google Patent on Calibration

**US11699088B2**: "Calibration of quantum processor operator parameters"
- URL: [Google Patents](https://patents.google.com/patent/US11699088B2/en)
- Inventor: Paul V. Klimov
- Graph traversal and local optimization for calibration

### Google Quantum AI Roadmap

Six milestones toward large-scale error-corrected quantum computing:
1. Beyond-classical computation (2019) ✓
2. QEC prototype (2023) ✓
3. Long-lived logical qubits
4. Logical gate operations
5. Engineering scale-up
6. Large error-corrected quantum computer (~1M qubits)

"Quantum transistor" concept: 1 logical qubit = ~1000 physical qubits as building block

**Reference**: [Google Quantum AI Roadmap](https://quantumai.google/roadmap); arXiv [2410.00917](https://arxiv.org/html/2410.00917v1)

---

## 15. QEC Threshold Calibration Requirements

### Surface Code Threshold
- Theoretical threshold: **~1% physical error rate** (estimates range widely)
- Practical requirement for below-threshold operation: physical errors significantly below 1%
- Google Willow demonstrated Lambda > 2 (error halves per distance increase)

### Calibration Speed Requirements
- Calibration cycles must operate at **kilohertz rates** (at least 10x faster than drift onset)
- Total closed-loop latency (measurement -> correction): **< few tens of microseconds**
- Real-time decoder latency: 63 +/- 17 us achieved (Google, distance-5)

### Stability Requirements
- Must maintain below-threshold performance for **hours-long algorithm execution**
- Active removal of correlated error sources (leakage, TLS)
- Recalibration between experimental runs to account for qubit frequency and readout signal drift

### Error Correction Hierarchy

| Physical Error Rate | QEC Capability | Calibration Requirement |
|---|---|---|
| > 1% | No useful QEC | Basic calibration sufficient |
| 0.1% - 1% | Below threshold, limited gain | Precise, frequent calibration |
| < 0.1% | Strong error suppression | Extreme stability + continuous calibration |
| < 0.01% | Efficient fault-tolerant | Beyond current capability |

### Beyond-Threshold Progress
- **Google Willow (2024)**: epsilon_7 = 1.43 x 10^-3 per cycle, Lambda = 2.14
- **Quantinuum (2025)**: Crossed key QEC threshold with trapped ions
- Both required extensive, system-specific calibration infrastructure

---

## 16. Synthesis: Known Gaps and Open Problems

### Gap 1: Model-Experiment Discrepancy (~20%)
Google's best noise models overpredict Lambda by ~20%. Suspected culprits include unmodeled long-range interactions, high-energy leakage, and correlated error mechanisms not captured by local noise models. **No group has fully closed this gap.**

### Gap 2: Scalable Calibration Beyond ~100 Qubits
At 100 qubits, 2-hour daily recalibration is already problematic. At 1000+ qubits, calibration time may exceed useful computation time. Solutions (ML, RL, FPGA-based) are promising but unproven at scale. The transition from "tractable" to "intractable" calibration lies somewhere in the 100-1000 qubit range.

### Gap 3: Fabrication Variability
Josephson junction resistance variations of 2-10% propagate to frequency variations of tens of MHz. ABAA achieves 7.7 MHz precision across hundreds of qubits, but "when selecting from 300+ qubits, it is impossible to avoid fabrication outliers." The fat-tail distribution (worst 10% of T1 drops 30-100x from Gaussian) remains a fundamental fabrication challenge.

### Gap 4: TLS Defect Dynamics
Two-level system defects are the primary source of T1 fluctuations and recalibration needs. Their stochastic fluctuation over sub-second to multi-hour timescales requires constant tracking. No method currently eliminates TLS effects; frequency forecasting (used by Google) mitigates but does not solve the problem.

### Gap 5: Measurement-Induced State Transitions
The fundamental tension between fast readout (requiring high photon numbers) and state preservation (requiring low photon numbers) imposes an unavoidable calibration tradeoff. The critical photon number for MISTs can be much lower (n~20) than the dispersive limit (n_crit~90), and current theory does not provide a complete predictive model for all qubit types.

### Gap 6: Correlated Errors at Scale
Correlated errors contribute ~17% of Google's QEC error budget. These arise from stray ZZ coupling, shared TLS environments, control crosstalk, and cosmic ray events. Naive models overestimate non-nearest-neighbor coupling by 5-10x, indicating that current crosstalk models are inadequate for large-scale calibration planning.

### Gap 7: Calibration DAG Completeness
Kelly et al.'s DAG framework provides the architectural blueprint, but no published work provides a **complete, concrete calibration DAG** with all nodes, edges, and parameters for a production-scale quantum processor. The framework is intentionally generic; actual implementations are proprietary and platform-specific.

### Gap 8: Coherent vs. Incoherent Error Separation
DRAG suffices for > 20 ns gates but fails below ~15 ns. Numerical optimization (GRAPE) achieves machine-precision coherent error but is 7x less robust to frequency drift. The optimal strategy depends on the instantaneous noise environment, which itself fluctuates. No general framework determines when to switch strategies.

### Gap 9: Real-Time Calibration for Fault Tolerance
QEC requires calibration cycles at kilohertz rates with < ~10 us latency. Current FPGA-based approaches achieve ~30 ms for basic primitives (T1, Rabi). There remains a ~3-order-of-magnitude gap between current calibration speeds and theoretical requirements for real-time fault-tolerant operation.

### Gap 10: Cross-Platform Reproducibility
Calibration procedures are tightly coupled to specific hardware, control electronics, and software stacks. Results from one lab are difficult to reproduce in another. Frameworks like Qibocal attempt hardware abstraction, but cross-platform benchmarking of calibration procedures themselves remains essentially nonexistent.

---

## Key References (Complete Bibliography)

### Hamiltonian Learning
1. Dutkiewicz et al., "Robustly learning the Hamiltonian dynamics of a superconducting quantum processor," Nature Communications (2024). [Link](https://www.nature.com/articles/s41467-024-52629-3) | [arXiv](https://arxiv.org/abs/2108.08319)

### Calibration DAG
2. Kelly et al., "Physical qubit calibration on a directed acyclic graph," arXiv:1803.03226 (2018). [arXiv](https://arxiv.org/abs/1803.03226) | [PDF](https://web.physics.ucsb.edu/~martinisgroup/papers/Kelly2018.pdf)

### Google Quantum AI
3. Klimov et al., "Optimizing quantum gates towards the scale of logical qubits," Nature Communications 15, 2442 (2024). [Link](https://www.nature.com/articles/s41467-024-46623-y) | [arXiv](https://arxiv.org/abs/2308.02321)
4. Neill et al., "A blueprint for demonstrating quantum supremacy with superconducting qubits," Science 360, 195 (2018). [Link](https://www.science.org/doi/abs/10.1126/science.aao4309)
5. Google Quantum AI, "Quantum error correction below the surface code threshold," Nature 638, 920 (2025). [Link](https://www.nature.com/articles/s41586-024-08449-y) | [arXiv](https://arxiv.org/abs/2408.13687)
6. Google Quantum AI, "Suppressing quantum errors by scaling a surface code logical qubit," arXiv:2207.06431. [arXiv](https://arxiv.org/abs/2207.06431)
7. Google Quantum AI, "Google Quantum AI's Quest for Error-Corrected Quantum Computers," arXiv:2410.00917. [arXiv](https://arxiv.org/html/2410.00917v1)

### ZZ Coupling
8. Xia et al., "Comprehensive explanation of ZZ coupling in superconducting qubits," arXiv:2408.15402 (2024). [arXiv](https://arxiv.org/abs/2408.15402)
9. Hua et al., "Crosstalk Dispersion and Spatial Scaling in Superconducting Qubit Arrays," arXiv:2512.18148 (2025). [arXiv](https://arxiv.org/html/2512.18148)

### Leakage
10. Werninghaus et al., "Leakage reduction in fast superconducting qubit gates via optimal control," npj Quantum Information (2020). [Link](https://www.nature.com/articles/s41534-020-00346-2)
11. "Active Leakage Cancellation in Single Qubit Gates," arXiv:2503.14731 (2025). [arXiv](https://arxiv.org/html/2503.14731v1)
12. "FAST DRAG / HD DRAG pulses," PRX Quantum 5, 030353 (2024). [Link](https://link.aps.org/doi/10.1103/PRXQuantum.5.030353) | [arXiv](https://arxiv.org/html/2402.17757v1)
13. "All-microwave leakage reduction units for QEC," arXiv:2302.09876 (2023). [arXiv](https://arxiv.org/html/2302.09876)
14. "Improved error correction with LRUs in measurement," arXiv:2511.17460 (2025). [arXiv](https://arxiv.org/html/2511.17460)

### Readout
15. "Enhancing Dispersive Readout via Dynamic Dispersive Shift," PRX Quantum 5, 040326 (2024). [Link](https://journals.aps.org/prxquantum/abstract/10.1103/PRXQuantum.5.040326)
16. "Measurement-induced state transitions in dispersive readout," Phys. Rev. Applied 22, 064038 (2024). [arXiv](https://arxiv.org/abs/2402.07360)

### Coherence
17. "Dynamics of superconducting qubit relaxation times," npj Quantum Information (2022). [Link](https://www.nature.com/articles/s41534-022-00643-y)
18. "Decoherence benchmarking of superconducting qubits," npj Quantum Information (2019). [Link](https://www.nature.com/articles/s41534-019-0168-5)
19. "Millisecond-Scale Calibration and Benchmarking," arXiv:2602.11912 (2026). [arXiv](https://arxiv.org/html/2602.11912v1)

### Gate Set Tomography
20. Nielsen et al., "Gate Set Tomography," Quantum 5, 557 (2021). [Link](https://quantum-journal.org/papers/q-2021-10-05-557/)

### Pulse Optimization
21. "When does numerical pulse optimization actually help?" arXiv:2511.12799 (2025). [arXiv](https://arxiv.org/html/2511.12799)

### Flux Tuning
22. "Precision frequency tuning via ABAA," arXiv:2407.06425 (2024). [arXiv](https://arxiv.org/html/2407.06425v1)
23. "Learning-Based Calibration of Flux Crosstalk," Phys. Rev. Applied 20, 024070 (2023). [Link](https://journals.aps.org/prapplied/abstract/10.1103/PhysRevApplied.20.024070)

### Automation Frameworks
24. "Qibocal: open-source calibration framework," arXiv:2410.00101 (2024). [arXiv](https://arxiv.org/html/2410.00101v1)
25. "Automated transmon qubit tune-up," Zurich Instruments (2025). [PDF](https://www.zhinst.com/sites/default/files/documents/2025-07/appnote_automated_transmon_2025.pdf)

### Scaling
26. "How to Build a Quantum Supercomputer," arXiv:2411.10406 (2024). [arXiv](https://arxiv.org/html/2411.10406v2)
27. "CaliQEC: In-situ calibration for surface code QEC," ISCA 2025. [ACM](https://dl.acm.org/doi/10.1145/3695053.3731042)
28. "Hardware-aware calibration protocol," ISCA 2025. [ACM](https://dl.acm.org/doi/10.1145/3695053.3731036)

### Fabrication
29. "Improving Josephson junction reproducibility," Scientific Reports (2023). [Link](https://www.nature.com/articles/s41598-023-34051-9)

### Benchmarking
30. "Benchmarking Quantum Gates and Circuits," Chemical Reviews (2024). [Link](https://pubs.acs.org/doi/10.1021/acs.chemrev.4c00870)
