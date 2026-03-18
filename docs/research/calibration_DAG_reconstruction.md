# Reconstructing the Full Optimus Calibration DAG for a 100+ Qubit Superconducting Transmon Processor

**Research compilation date: 2026-03-15**

---

## Table of Contents

1. [Background: The Optimus Framework](#1-background-the-optimus-framework)
2. [Open-Source Calibration DAGs](#2-open-source-calibration-dags)
3. [Qiskit Experiments Calibration Protocols](#3-qiskit-experiments-calibration-protocols)
4. [Academic Calibration Procedures](#4-academic-calibration-procedures)
5. [Google's Published Calibration Details](#5-googles-published-calibration-details)
6. [Tolerance Values from Literature](#6-tolerance-values-from-literature)
7. [Drift Timescales (Timeout Values)](#7-drift-timescales-timeout-values)
8. [Dependency Ordering](#8-dependency-ordering)
9. [Node Analysis Functions](#9-node-analysis-functions)
10. [Coupler Calibration Nodes](#10-coupler-calibration-nodes)
11. [Scaling Considerations](#11-scaling-considerations)
12. [Proposed Complete Calibration DAG](#12-proposed-complete-calibration-dag)
13. [Sources and Citations](#13-sources-and-citations)

---

## 1. Background: The Optimus Framework

### 1.1 Kelly et al. (arXiv:1803.03226)

The Optimus framework organizes all calibration as nodes in a directed acyclic graph (DAG). Each node represents a calibration procedure that updates one or more **registry parameters**. Directed edges encode dependencies: a node can only run after its upstream dependencies are in-spec.

**Core concepts from the paper:**

A calibration node ("cal") consists of:
- **Target parameters**: the registry values it updates
- **A scan**: an experiment that generates data
- **Analysis functions**: extract figures of merit and determine if parameters are in-spec
- **Tolerance**: acceptable range for the figure of merit
- **Timeout**: time period after which the cal must be re-verified

Each node supports three interaction modes:

1. **check_state** (no experiments): Classical check. Passes if and only if:
   - The cal had check_data or calibrate pass within the timeout period
   - The cal has not failed calibrate without resolution
   - No dependencies have been recalibrated since last verification
   - All dependencies pass check_state

2. **check_data** (minimal experiments): Quick experiment using few data points superimposed on expected curves. Classifies result as:
   - **In spec**: parameters acceptable
   - **Out of spec**: parameters drifted but scan is valid
   - **Bad data**: scan itself is corrupt, indicating a dependency failure

3. **calibrate** (full experiment): Full scan, analysis, and parameter update

**Two traversal algorithms:**

- **maintain**: Primary interface. Recursively walks from leaf to root finding the first failing check_state, then runs check_data/calibrate as needed. Goal: get a target node in-spec.
- **diagnose**: Called when check_data returns bad data. Investigates dependencies recursively to find the root cause of corruption.

**Cyclic dependencies**: Unwrapped into precision layers (coarse, mid, fine) so that A_coarse -> B_coarse -> A_fine -> B_fine forms an acyclic graph.

**Example tolerance**: "A pi pulse should be within 10^-4 radians of a pi rotation."

**Timeout**: Determined experimentally from system drift characteristics. No specific numerical values published.

### 1.2 Google Patent US9940212B2

Adds the following detail:
- Registry parameters include: readout pulse frequency/length/power, discrimination threshold, pi/pi/2 pulse frequencies, pi/pi/2 pulse lengths and amplitudes
- Tolerance example: "a pi pulse parameter may be determined to be in specification if the rotation angle is within the tolerance value of 1% of a 180 degree rotation"
- Three-tier calibration: calibration test (metadata check) -> first calibration experiment (low-cost verification) -> second calibration experiment (high-cost full calibration)

---

## 2. Open-Source Calibration DAGs

### 2.1 Qibocal (Qibo Framework)

**Source**: arXiv:2410.00101, https://qibo.science/qibocal/stable/

Qibocal provides the most complete open-source calibration protocol library. Protocols include:

**Signal & Readout:**
- Time of Flight
- Resonator punchout (2D power-frequency sweep)
- Resonator spectroscopy (1-tone, Lorentzian fit)
- Readout optimization
- Single-shot classification
- Readout mitigation matrix
- Dispersive shift measurement

**Single-Qubit Characterization:**
- Qubit spectroscopy (2-tone, Lorentzian fit)
- Rabi experiments (amplitude and duration)
- Ramsey experiments (T2*, frequency fine-tuning)
- T1 experiments (exponential decay)
- T2 echo (Hahn echo)
- CPMG sequence
- AllXY (gate calibration verification)
- Flipping (amplitude fine-tuning via error amplification)
- DRAG calibration (leakage reduction)
- Virtual Z gate calibration

**Flux-Dependent:**
- Frequency vs flux (qubit and resonator)
- Flux crosstalk experiments
- Cryoscope (flux pulse distortion characterization)

**Two-Qubit:**
- Chevron (2D amplitude-duration sweep for CZ/iSWAP)
- CHSH inequality

**Benchmarking:**
- Standard randomized benchmarking
- State tomography
- Process tomography

**Published dependency chain (from Qibocal paper):**

| Protocol | Dependencies |
|----------|-------------|
| Resonator spectroscopy (1-tone) | None |
| Resonator punchout | None |
| Qubit spectroscopy (2-tone) | Resonator spectroscopy |
| Rabi experiment | Qubit spectroscopy |
| Ramsey experiment | Rabi |
| T1 measurement | Rabi |
| T2* measurement | Ramsey |
| T2 echo | Rabi |
| Single-shot classification | Rabi |
| DRAG calibration | Rabi |
| Readout frequency optimization | Single-shot classification |
| Qubit flux spectroscopy | Single-qubit calibration complete |
| Avoided crossing detection | Flux spectroscopy |
| Chevron experiment | Avoided crossing |
| CZ/iSWAP gate calibration | Chevron |
| Coupler calibration | (tunable-coupler architectures) |
| Dynamical phase correction | CZ/iSWAP |
| Leakage characterization | CZ/iSWAP |

**Frequency vs flux fitting model:**
```
f_q(Phi) = (f_q_max + E_C/h) * (d^2 + (1-d^2)*cos^2(pi*Phi/Phi_0))^(1/4) - E_C/h
```

**Example workflow (coherence at different bias points):**
1. Qubit flux spectroscopy -> extract flux-frequency relationship
2. FOR each bias point:
   - Update qubit frequency from fit
   - Rabi -> recalibrate drive amplitude
   - Single-shot classification
   - Ramsey -> fine-tune drive frequency
   - Single-shot classification (refined)
   - Measure T1, T2*, readout fidelity

### 2.2 QUAlibrate (Quantum Machines)

**Source**: https://github.com/qua-platform/qualibrate, released May 2025

Key architectural features:
- `QualibrationNode`: reusable calibration scripts converted to DAG nodes
- `QualibrationGraph`: directed acyclic graph combining nodes
- Advanced features: looping, failure handling, nested subgraphs
- Built on QUA language and QUAM (Quantum Abstract Machine) hardware model
- Demonstrated full multi-qubit calibration in 140 seconds at the IQCC

**Calibration workbook sequence (learn.quantum-machines.co):**
1. Continuous signal verification
2. Analog input calibration
3. Qubit spectroscopy
4. Power-time Rabi
5. Chevron-Ramsey
6. Active reset
7. Randomized benchmarking

### 2.3 LabOne Q (Zurich Instruments)

**Source**: https://docs.zhinst.com/labone_q_user_manual/

DAG-based bring-up workflow including:
- Rabi amplitude and DRAG parameter extraction
- Readout discrimination and threshold calibration
- Coherence measurements (T1, T2, Ramsey, echo)
- Flux bias sweeps for sweet-spot detection
- Amplitude calibration with error amplification

Demonstrated characterization of 28 qubits in ~3 hours.

### 2.4 QubiC (LBNL)

**Source**: ACM Transactions on Quantum Computing, doi:10.1145/3529397

Automatic calibration protocols for transmon qubits:
- Multi-dimensional loss-based optimization for single-qubit characterization
- Stacking of consecutive identical gates for drive amplitude fine-tuning
- CR pulse amplitude sweep for CNOT calibration
- Full XY-plane measurement for CNOT parameter extraction
- Achieved: SQ Clifford infidelity 4.9(1.1) x 10^-4, TQ Clifford infidelity 1.4(3) x 10^-2

---

## 3. Qiskit Experiments Calibration Protocols

**Source**: https://qiskit-community.github.io/qiskit-experiments/

### Characterization Experiments:
| Class Name | Purpose |
|-----------|---------|
| T1 | Energy relaxation time |
| T2Hahn | Dephasing time (echo) |
| T2Ramsey | Ramsey frequency and T2* |
| Tphi | Pure dephasing rate |
| QubitSpectroscopy | Qubit frequency identification |
| ResonatorSpectroscopy | Resonator frequency identification |
| Rabi | Pi-pulse amplitude calibration |
| EFRabi | E-F transition Rabi (leakage characterization) |
| HalfAngle | SX/X gate parallelism |
| FineAmplitude | Amplitude fine-tuning via error amplification |
| FineXAmplitude | X gate amplitude fine-tuning |
| FineSXAmplitude | SX gate amplitude fine-tuning |
| FineZXAmplitude | ZX interaction amplitude |
| RamseyXY | Qubit frequency measurement |
| FineFrequency | Fine qubit frequency |
| ReadoutAngle | IQ cluster separation angle |
| RoughDrag | Coarse DRAG coefficient |
| FineDrag | Fine DRAG coefficient |
| FineXDrag | X gate DRAG fine-tuning |
| FineSXDrag | SX gate DRAG fine-tuning |
| MultiStateDiscrimination | n-state readout discrimination |
| ZZRamsey | Static ZZ interaction characterization |
| CrossResonanceHamiltonian | CR Hamiltonian tomography |
| EchoedCrossResonanceHamiltonian | Echoed CR Hamiltonian |
| LocalReadoutError | Single-qubit readout error |
| CorrelatedReadoutError | Multi-qubit correlated readout error |

### Verification Experiments:
| Class Name | Purpose |
|-----------|---------|
| StandardRB | Clifford randomized benchmarking |
| InterleavedRB | Gate-specific RB |
| LayerFidelity | Full-device layer benchmarking |
| QuantumVolume | Quantum volume measurement |
| StateTomography | Quantum state reconstruction |
| ProcessTomography | Quantum channel reconstruction |

---

## 4. Academic Calibration Procedures

### 4.1 Standard Bring-Up Sequence (Consensus from literature)

The following ordering emerges consistently across Qblox, Zurich Instruments, Qibocal, and academic papers:

**Phase 0: Hardware/Amplifier Setup**
1. TWPA pump frequency and bias point calibration
2. Mixer calibration (LO leakage, sideband suppression)
3. Time-of-flight calibration

**Phase 1: Resonator Characterization**
4. Resonator spectroscopy (1-tone, continuous wave)
5. Resonator punchout (power vs. frequency 2D sweep)
6. Optimal readout power/frequency selection

**Phase 2: Qubit Discovery**
7. Qubit spectroscopy (2-tone, continuous wave)
8. Pulsed qubit spectroscopy (improved precision)
9. Dispersive shift measurement (2*chi)

**Phase 3: Single-Qubit Gate Calibration**
10. Rabi oscillation (pi-pulse amplitude)
11. Ramsey experiment (frequency fine-tuning, T2*)
12. T1 measurement
13. DRAG calibration (leakage reduction)
14. AllXY verification
15. Amplitude fine-tuning (error amplification / flipping)

**Phase 4: Readout Optimization**
16. Single-shot readout classification
17. Readout frequency optimization
18. Readout power optimization
19. Integration weight optimization

**Phase 5: Flux Characterization (flux-tunable qubits)**
20. Frequency vs. flux mapping
21. Sweet-spot identification
22. Cryoscope / flux pulse distortion correction
23. Flux crosstalk matrix calibration

**Phase 6: Two-Qubit Gate Calibration**
24. Chevron experiment (amplitude-duration landscape)
25. CZ or iSWAP gate parameter extraction
26. Virtual-Z phase correction
27. Conditional phase calibration
28. Leakage characterization

**Phase 7: Benchmarking & Validation**
29. Single-qubit randomized benchmarking
30. Two-qubit randomized benchmarking
31. Cross-entropy benchmarking (XEB)
32. Quantum volume

### 4.2 Optimizing Superconducting Qubit Performance (arXiv:2501.17825)

Four-step theoretical framework:
1. Circuit design
2. Electromagnetic analysis (lumped oscillator model, capacitance matrix)
3. Spectral analysis (frequency spectrum, coherence optimization)
4. Pulse sequencing (pulse-width optimization, DRAG, randomized benchmarking)

### 4.3 Integrated Tool Set (Phys. Rev. Applied 15, 034080)

Emphasizes that each calibration step in the typical flow depends on results of the previous step, with single- and two-tone spectroscopic measurements preceding pulsed experiments.

---

## 5. Google's Published Calibration Details

### 5.1 Sycamore Supplementary (arXiv:1910.11333)

**Three hierarchical configurations:**

**Root Configuration** (post-cooldown):
- Parametric amplifier calibration (flux bias, pump frequency, pump power)
- Resonator spectroscopy for each qubit: estimate resonator and qubit frequency vs. bias
- Coupler response: place paired qubits at opposing frequency extremes, identify near-maximum coupler frequency where qubit-qubit coupling is minimal (few MHz)

**Single-Qubit Configuration** (qubits isolated by biasing neighbors to ~0 frequency):
- Microwave spectroscopy with qubit bias sweep -> identify resonant frequency
- Operating bias determination: on-resonance qubit-readout coupling using 10 us ground-state preparation
- Power Rabi oscillations -> pi-pulse drive parameters
- Fine-tune pi and pi/2 pulses (frequency, power, detuning)
- Timing synchronization calibration (microwave drive, qubit bias, coupler bias)
- Readout frequency and power optimization (maximize fidelity)
- T1 vs. frequency measurement (map TLS defect background)
- Qubit response to detuning pulses (frequency-control transfer function)
- Qubit spectroscopy across bias range (refine bias-frequency curves)

**Grid Configuration** (full processor):
- Frequency optimization via "Snake Optimizer"
- Single-qubit gate calibration (full grid)
- Two-qubit gate calibration (full grid)
- Readout calibration (full grid)
- XEB validation

**Timeline**: Initial bringup ~36 hours post-cooldown; daily maintenance ~4 hours.

**Device registry**: >100 parameters per qubit including operating frequencies (idle, interaction, readout), control biases, gate durations and amplitudes, circuit model parameterizations, calibrated transfer functions.

### 5.2 Snake Optimizer (arXiv:2006.04594)

Optimizes three frequency sets per qubit:
- N idle frequencies (single-qubit operation)
- N readout frequencies (measurement)
- ~2N interaction frequencies (two-qubit gates)

Error mechanisms in objective function:
- Parasitic coupling (nearest-neighbor and next-nearest-neighbor)
- TLS defects (spectrally diffusing)
- Spurious microwave modes
- Control-line and readout-resonator coupling
- Frequency-control electronics noise and pulse distortions
- Microwave-control pulse distortions and carrier bleedthrough

The Snake operates as one layer within the broader Optimus calibration stack.

### 5.3 Google Calibration Metrics (Cirq Documentation)

Published metrics collected during periodic processor calibrations:

**Single-qubit metrics:**
- `single_qubit_p00_error` (state prep + measurement error for |0>)
- `single_qubit_p11_error` (state prep + measurement error for |1>)
- `single_qubit_readout_separation_error` (IQ cloud overlap)
- `single_qubit_rb_average_error_per_gate`
- `single_qubit_rb_pauli_error_per_gate`
- `single_qubit_rb_incoherent_error_per_gate`
- `single_qubit_idle_t1_micros`

**Parallel readout metrics:**
- `parallel_p00_error`
- `parallel_p11_error`

**Two-qubit metrics (for each gate type: Sycamore, sqrt(iSWAP)):**
- `two_qubit_{gate}_xeb_average_error_per_cycle`
- `two_qubit_{gate}_xeb_pauli_error_per_cycle`
- `two_qubit_{gate}_xeb_incoherent_error_per_cycle`
- `two_qubit_parallel_{gate}_xeb_average_error_per_cycle`
- `two_qubit_parallel_{gate}_xeb_pauli_error_per_cycle`
- `two_qubit_parallel_{gate}_xeb_incoherent_error_per_cycle`

### 5.4 Willow (arXiv:2408.13687)

- 105-qubit processor
- Mean T1 = 68 us +/- 13 us; T2_CPMG = 89 us
- Single-qubit gate errors: 0.035% +/- 0.029%
- CZ gate errors: 0.33% +/- 0.18%
- Measurement errors: 0.77% +/- 0.21%
- Recalibration: between every 4 experimental runs during extended operation
- TLS forecasting: frequency optimization predicts and avoids TLS defect frequencies
- Drift between recalibrations: modest enough that "logical error rates of experiments right after drift recalibration are not appreciably lower than those just prior"

---

## 6. Tolerance Values from Literature

### 6.1 Gate Fidelity Thresholds

| Parameter | Threshold | Context | Source |
|-----------|-----------|---------|--------|
| Surface code threshold | ~1% error per gate | Fault-tolerance requirement | General |
| Practical fault-tolerance | ~0.1% error per gate | Operational target | Google Willow |
| Pi-pulse rotation error | <10^-4 radians | Optimus example | Kelly 2018 |
| Pi-pulse amplitude | within 1% of 180 deg | Patent example | US9940212B2 |
| Single-qubit RB error | <0.05% | State of art | Willow 2024 |
| Two-qubit gate error (CZ) | <0.5% | State of art | Willow 2024 |
| Readout error | <1% | State of art | Willow 2024 |
| Readout assignment fidelity | >99% | Practical target | Multiple |
| ZZ coupling suppression | <30 kHz residual | Tunable coupler idle | Literature 2024-2025 |
| Flux crosstalk error | <0.5 mΦ_0/Φ_0 RMS | After CISCIQ calibration | PRX Quantum 2, 040313 |
| Qubit frequency error (crosstalk) | <300 kHz median | Learning-based protocol | Phys. Rev. Applied 20, 024070 |
| Cryoscope residual error | sub-permille freq. error | Flux pulse correction | Appl. Phys. Lett. 116, 054001 |

### 6.2 Proposed Tolerance Values for DAG Nodes

| Node | Figure of Merit | Tolerance |
|------|----------------|-----------|
| Resonator spectroscopy | Frequency accuracy | +/- 100 kHz |
| Qubit spectroscopy | Frequency accuracy | +/- 500 kHz |
| Rabi | Pi-pulse amplitude | +/- 1% |
| Ramsey | Frequency detuning | +/- 50 kHz |
| T1 | Relaxation time | > 20 us (processor-dependent) |
| T2* | Dephasing time | > 10 us |
| DRAG | Leakage rate | < 0.1% per gate |
| Single-shot classification | Assignment fidelity | > 98% |
| Readout optimization | Assignment fidelity | > 99% |
| Flux sweetspot | Frequency accuracy | +/- 100 kHz |
| Flux crosstalk | Crosstalk coefficient | < 1 mΦ_0/Φ_0 |
| Cryoscope | Step response error | < 0.1% |
| Chevron / CZ | Conditional phase | +/- 0.01 rad |
| Virtual-Z correction | Phase error | +/- 0.005 rad |
| Single-qubit RB | Error per Clifford | < 0.1% |
| Two-qubit XEB | Error per cycle | < 0.5% |
| Parallel XEB | Error per cycle | < 1% |
| ZZ characterization | Residual ZZ | < 50 kHz |
| Active reset | Residual excitation | < 0.5% |

---

## 7. Drift Timescales (Timeout Values)

### 7.1 Measured Drift Rates

**Qubit frequency:**
- Symmetric drift from background charge motion: 0 to 1.76 MHz range (Decoherence benchmarking, npj Quantum Information 2019)
- Transmon charge dispersion: ~kHz level (by design)
- Flux noise induced: depends on distance from sweet spot
- Stability at sweet spot: first-order insensitive, residual drift ~10s of kHz over hours

**T1 relaxation time:**
- Can fluctuate by an order of magnitude on ~15 minute timescales (npj Quantum Information 2022)
- Fast TLS switching: rates up to ~10 Hz (sub-100 ms timescale)
- Slow TLS switching: 75 uHz to 1 mHz (hours to days)
- Heterogeneous: fast fluctuations coexist with slow drifts over minutes to hours

**Readout parameters:**
- Resonator frequency: stable to ~kHz over days (lithographic, not tunable)
- Readout discrimination: drifts with amplifier gain changes (hours timescale)
- IQ plane rotation: slow drift, hours to days

**Flux offset drift:**
- 2-day RMS: 1.3 mΦ_0
- 17-day RMS: 2.0 mΦ_0
(PRX Quantum 2, 040313)

**Gate parameters:**
- Log-normal distribution of drift times with mean ~14 hours (CaliScalpel, IBM Eagle data)
- Range: hours to days depending on individual gate/qubit

### 7.2 Proposed Timeout Values for DAG Nodes

| Node Category | Typical Timeout | Rationale |
|--------------|----------------|-----------|
| TWPA / amplifier calibration | 24-72 hours | Very stable unless thermal cycle |
| Resonator spectroscopy | 24-48 hours | Lithographic, very stable |
| Qubit spectroscopy | 4-8 hours | Frequency drift from TLS/charge |
| Rabi calibration | 4-8 hours | Amplitude drift modest |
| Ramsey / frequency | 1-4 hours | Frequency drift primary concern |
| T1 measurement | 2-4 hours | Order-of-magnitude fluctuations on 15-min scale; monitor frequently |
| T2 measurement | 2-4 hours | Correlated with T1 fluctuations |
| DRAG calibration | 8-24 hours | Depends on anharmonicity stability |
| Readout optimization | 4-12 hours | Amplifier gain drift |
| Single-shot classification | 4-8 hours | IQ plane drift |
| Flux sweetspot | 24-48 hours | Stable unless thermal cycle |
| Flux crosstalk matrix | 48-168 hours | Very stable; geometric property |
| Cryoscope | 24-48 hours | Transfer function stable |
| Chevron / 2Q gate | 2-8 hours | Sensitive to frequency drift |
| Virtual-Z phase | 2-8 hours | Tracks frequency drift |
| Single-qubit RB | 4-8 hours | Composite of SQ calibrations |
| Two-qubit XEB | 2-8 hours | Sensitive to all upstream drift |
| Frequency optimization (Snake) | 12-24 hours | Requires TLS landscape monitoring |
| Active reset | 8-24 hours | Depends on readout stability |

### 7.3 Google's Operational Cadence

- Initial bringup: ~36 hours
- Daily maintenance: ~4 hours (Sycamore)
- Willow recalibration: between every 4 experimental runs
- 100-qubit full calibration from scratch: up to 2 days
- Recalibration of already-calibrated system: ~1 hour

---

## 8. Dependency Ordering

### 8.1 Fundamental Bootstrap Chain

The following ordering is enforced by physics:

```
Amplifier/Mixer Setup
    |
    v
Resonator Spectroscopy (must know readout frequency to measure anything)
    |
    v
Qubit Spectroscopy (requires readout; must know qubit frequency to drive it)
    |
    v
Rabi (requires qubit frequency; calibrates pi-pulse)
    |
    v
Ramsey (requires pi/2 pulse from Rabi; fine-tunes frequency)
    |
    v
[T1, T2, DRAG, AllXY branch out from Rabi/Ramsey]
    |
    v
Single-Shot Classification (requires calibrated pi-pulse)
    |
    v
Readout Optimization (requires state discrimination)
    |
    v
[Two-qubit calibration requires all single-qubit calibration]
```

### 8.2 Two-Qubit Bootstrap Chain

```
Flux Spectroscopy (requires single-qubit calibration of both qubits)
    |
    v
Sweet Spot Identification
    |
    v
Cryoscope / Flux Pulse Correction
    |
    v
Flux Crosstalk Matrix
    |
    v
Frequency Optimization (Snake)
    |
    v
Chevron (requires flux control, both qubits calibrated)
    |
    v
CZ/iSWAP Parameter Extraction
    |
    v
Virtual-Z Phase Correction
    |
    v
[Two-qubit RB, XEB validation]
```

### 8.3 Coupler Bootstrap Chain

```
Coupler Bias Sweep (identify idle point)
    |
    v
Coupler Frequency vs Bias (map coupler response)
    |
    v
ZZ Interaction Measurement (verify suppression at idle)
    |
    v
CZ Gate Optimization (with coupler activated)
    |
    v
Leakage Characterization
```

---

## 9. Node Analysis Functions

### 9.1 Standard Fitting Functions

| Node | Analysis Function | Model |
|------|------------------|-------|
| Resonator spectroscopy | Complex Lorentzian fit | S21 = A / (1 + 2iQ(f-f0)/f0) |
| Resonator punchout | 2D peak tracking | Lorentzian vs power + transition detection |
| Qubit spectroscopy | Lorentzian fit | A / (1 + ((f-f0)/(gamma/2))^2) |
| Rabi amplitude | Sinusoidal fit | A * sin(pi * amp/amp_pi) + B |
| Rabi duration | Damped sinusoidal fit | A * sin(2*pi*f*t + phi) * exp(-t/T) + B |
| Ramsey | Damped sinusoidal fit | A * cos((w_d - w_q)*t + phi) * exp(-Gamma*t) + C |
| T1 | Exponential decay | A * exp(-t/T1) + B |
| T2* (Ramsey) | Damped oscillation | A * cos(delta*t) * exp(-t/T2*) + B |
| T2 (Hahn echo) | Exponential decay | A * exp(-(2*tau/T2)^n) + B (n=1 or stretched) |
| DRAG | Sinusoidal vs beta | Leakage = A * sin(B*beta + phi) + C |
| AllXY | Expected pattern match | 21-point gate sequence comparison |
| Flipping / fine amplitude | Error amplification | Linear trend in repeated gates |
| Single-shot classification | Gaussian mixture model | 2D Gaussian fit in IQ plane |
| Freq vs flux | Transmon tuning model | See Section 2.1 for formula |
| Cryoscope | Step response deconvolution | h(t) = IFT(H(f)), predistortion filter |
| Chevron | 2D oscillation pattern | p_e(t,Delta) = Delta^2/(Delta^2+4g^2) + ... |
| Randomized benchmarking | Exponential decay | F(m) = A*p^m + B; EPC = (1-p)(1-1/d) |
| XEB | Linear fidelity | F_XEB from cross-entropy of bitstring samples |
| ZZ Ramsey | Conditional frequency shift | Ramsey with/without neighbor in |1> |
| CR Hamiltonian | Hamiltonian tomography | Fit IX, IZ, ZI, ZX, ZZ rates |

### 9.2 Verification Functions (check_data)

For each node, check_data typically:
1. Takes 3-5 data points at characteristic positions on the expected curve
2. Compares against the stored fit from last calibration
3. Computes residuals
4. Classifies: in-spec (residuals < tolerance), out-of-spec (residuals > tolerance but pattern valid), bad data (pattern unrecognizable)

---

## 10. Coupler Calibration Nodes

### 10.1 Tunable Coupler Architecture

For tunable-coupler transmon processors (Google Sycamore/Willow style):

**Coupler Idle Point Calibration:**
- Sweep coupler DC flux bias
- Measure qubit-qubit swap rate vs coupler bias
- Identify bias point where coupling is minimal (few MHz or zero)
- Analysis: fit coupling strength vs bias, find zero crossing
- Tolerance: ZZ < 30 kHz at idle

**Coupler Frequency Mapping:**
- Measure coupler frequency vs bias (spectroscopy or avoided crossing)
- Map the full coupler tuning curve
- Analysis: fit to transmon/fluxonium tuning model

**ZZ Interaction Calibration:**
- Ramsey on qubit A with qubit B in |0> and |1>
- Extract conditional frequency shift = ZZ coupling
- Analysis: frequency difference from two Ramsey fits
- Tolerance: < 50 kHz at idle point

**CZ Gate via Coupler:**
- Flux pulse on coupler to activate coupling
- Optimize pulse amplitude and duration for conditional phase = pi
- May use Slepian-shaped flux pulses to reduce non-adiabatic transitions
- Analysis: conditional phase from interleaved Ramsey
- Tolerance: conditional phase within +/- 0.01 rad of pi

**Leakage Characterization:**
- Population in |2> state after CZ gate
- Analysis: leakage randomized benchmarking
- Tolerance: < 0.1% leakage per gate

### 10.2 Flux Crosstalk for Couplers

The CISCIQ procedure (PRX Quantum 2, 040313) handles crosstalk in systems with qubits AND couplers:

**Stages:**
1. Measure direct coupling: resonator frequency periodicity vs bias voltage
2. Determine crosstalk coefficients from non-direct bias line shifts
3. Characterize 3x3 coupling matrix within each unit cell (qubit z-loop, x-loop, resonator)
4. Measure remaining inter-unit crosstalk

**Requires 3 iterations** for convergence:
- Iteration 1: corrections ~10 mΦ_0/Φ_0
- Iteration 2: corrections ~2 mΦ_0/Φ_0
- Iteration 3: corrections < 1 mΦ_0/Φ_0

**Final accuracy:** RMS crosstalk error < 0.5 mΦ_0/Φ_0

---

## 11. Scaling Considerations

### 11.1 Parallelization Strategies

**Key insight**: Many calibration nodes can be parallelized across qubits that don't interact:

- Resonator spectroscopy: parallelize across frequency-multiplexed groups (e.g., 6 qubits per feedline on Sycamore)
- Single-qubit calibrations: all non-neighboring qubits can be calibrated simultaneously
- Two-qubit calibrations: non-overlapping pairs can run in parallel
- Google uses 4 discrete patterns for parallel two-qubit XEB

**CaliQEC approach**: Code deformation separates qubits under calibration from logical patches, enabling concurrent calibration and computation with only 12-15% additional physical qubits.

**CaliScalpel approach**: Topology-aware scheduling using Sequence-Dependent TSP achieves linear complexity in qubit count. Reduces space-time overhead by 2.89x vs sequential and 3.8x vs bulk calibration.

### 11.2 Time Estimates for 100+ Qubits

| Operation | Time Estimate | Basis |
|-----------|--------------|-------|
| Full bringup from scratch | 1-2 days | Industry reports |
| Daily recalibration | 1-4 hours | Google Sycamore |
| QUAlibrate full recalibration | ~10 minutes | Quantum Machines demo |
| Single-qubit calibration (1 qubit) | ~5 minutes | Typical |
| Single-qubit calibration (100 qubits, parallel) | ~30-60 minutes | Parallelized |
| Two-qubit calibration (100 pairs) | ~1-2 hours | 4 parallel layers |
| Flux crosstalk matrix (27 loops) | ~80 hours | CISCIQ, first iteration |
| Frequency optimization (53 qubits) | ~minutes | Snake optimizer |

### 11.3 Scaling Bottlenecks

1. **Flux crosstalk matrix**: Scales as O(N^2) in measurement count for naive approach; can be reduced to O(N) with improved current routing
2. **Frequency optimization**: Exponentially large search space mitigated by Snake optimizer's decomposition into local problems
3. **Two-qubit gate calibration**: Scales linearly with parallelization, but interaction graph limits parallelism
4. **TLS monitoring**: Requires continuous background tracking; more qubits = more TLS encounters

---

## 12. Proposed Complete Calibration DAG

### 12.1 Overview

The proposed DAG contains **82 nodes** organized into 9 tiers. Nodes are specified with: name, tier, dependencies, analysis function, tolerance, and timeout.

### Tier 0: Hardware Infrastructure (4 nodes)

| ID | Node Name | Dependencies | Analysis Function | Tolerance | Timeout |
|----|-----------|-------------|-------------------|-----------|---------|
| H1 | TWPA_pump_calibration | None | Gain vs frequency/power map; peak gain identification | Gain > 15 dB over 500 MHz BW | 72 h |
| H2 | Mixer_LO_leakage_cal | None | Power spectrum; minimize LO leakage | LO suppression > 40 dB | 168 h |
| H3 | Mixer_sideband_cal | H2 | Power spectrum; minimize unwanted sideband | Sideband suppression > 35 dB | 168 h |
| H4 | Time_of_flight_cal | H1 | Cross-correlation of TX/RX pulses | Timing accuracy +/- 1 ns | 168 h |

### Tier 1: Resonator Characterization (4 nodes)

| ID | Node Name | Dependencies | Analysis Function | Tolerance | Timeout |
|----|-----------|-------------|-------------------|-----------|---------|
| R1 | Resonator_spectroscopy_CW | H1, H4 | Complex Lorentzian fit of S21 | f_r +/- 100 kHz | 48 h |
| R2 | Resonator_punchout | R1 | 2D (power x freq) Lorentzian tracking; identify dispersive/linear regimes | Optimal readout power identified | 48 h |
| R3 | Resonator_flux_dependence | R1, F1 | Dispersive transmon model fit of f_r vs flux | f_r(flux) model chi^2 < threshold | 48 h |
| R4 | Dispersive_shift_measurement | R1, Q3 | Spectroscopy with qubit in |0> and |1>; extract 2*chi | chi +/- 50 kHz | 24 h |

### Tier 2: Qubit Discovery (5 nodes)

| ID | Node Name | Dependencies | Analysis Function | Tolerance | Timeout |
|----|-----------|-------------|-------------------|-----------|---------|
| Q1 | Qubit_spectroscopy_CW | R1, R2 | Lorentzian fit of qubit absorption | f_q +/- 500 kHz | 8 h |
| Q2 | Qubit_spectroscopy_pulsed | R2, Q1 | Lorentzian fit with improved SNR | f_q +/- 200 kHz | 8 h |
| Q3 | Qubit_freq_vs_flux | Q2 | Transmon tuning formula fit (see Sec 2.1) | f_q_max, d, E_C extracted | 48 h |
| Q4 | Qubit_sweetspot_identification | Q3 | Maximum frequency in tuning curve | Sweetspot bias +/- 1 mV | 48 h |
| Q5 | Qubit_anharmonicity | Q2 | Two-tone EF spectroscopy; extract alpha = f_12 - f_01 | alpha +/- 1 MHz | 168 h |

### Tier 3: Single-Qubit Gate Calibration (12 nodes)

| ID | Node Name | Dependencies | Analysis Function | Tolerance | Timeout |
|----|-----------|-------------|-------------------|-----------|---------|
| G1 | Rabi_amplitude | Q2, R2 | Sinusoidal fit of P(|1>) vs amplitude | pi_amp +/- 1% | 8 h |
| G2 | Rabi_duration | Q2, R2 | Damped sinusoidal fit of P(|1>) vs time | pi_duration +/- 2 ns | 8 h |
| G3 | Ramsey_frequency | G1 | Damped cosine fit; extract detuning | detuning < 50 kHz | 4 h |
| G4 | Ramsey_T2star | G1 | Damped cosine fit; extract decay constant | T2* measurement | 4 h |
| G5 | T1_measurement | G1 | Exponential decay fit | T1 measurement | 4 h |
| G6 | T2_echo | G1 | Exponential/stretched exp decay fit | T2_echo measurement | 4 h |
| G7 | DRAG_coarse | G1, G3 | Sinusoidal fit of leakage vs beta | beta +/- 0.05 | 24 h |
| G8 | DRAG_fine | G7 | Error amplification vs beta | beta +/- 0.01 | 24 h |
| G9 | Amplitude_fine_X | G1, G3 | Error amplification (repeated X gates) | amp_X +/- 0.1% | 8 h |
| G10 | Amplitude_fine_SX | G1, G3 | Error amplification (repeated SX gates) | amp_SX +/- 0.1% | 8 h |
| G11 | AllXY_verification | G9, G10, G8 | 21-point pattern match | Max deviation < 0.02 | 8 h |
| G12 | Virtual_Z_calibration | G3 | Phase error extraction from Ramsey | phase_offset +/- 0.005 rad | 8 h |

### Tier 4: Readout Optimization (6 nodes)

| ID | Node Name | Dependencies | Analysis Function | Tolerance | Timeout |
|----|-----------|-------------|-------------------|-----------|---------|
| RO1 | Single_shot_classification | G1, R2 | 2D Gaussian mixture fit in IQ plane | Assignment fidelity > 95% | 8 h |
| RO2 | Readout_frequency_opt | RO1 | Sweep f_r, maximize IQ separation | f_r_opt +/- 50 kHz | 12 h |
| RO3 | Readout_amplitude_opt | RO1 | Sweep amplitude, maximize SNR below transition | amp_opt identified | 12 h |
| RO4 | Readout_duration_opt | RO1 | Sweep integration time, maximize fidelity | duration_opt +/- 20 ns | 12 h |
| RO5 | Integration_weight_opt | RO1 | Matched filter design from IQ trajectories | Fidelity > 99% | 12 h |
| RO6 | Readout_mitigation_matrix | RO5 | Measure full confusion matrix | Matrix elements +/- 0.5% | 8 h |

### Tier 5: Flux Control Calibration (7 nodes)

| ID | Node Name | Dependencies | Analysis Function | Tolerance | Timeout |
|----|-----------|-------------|-------------------|-----------|---------|
| F1 | Flux_bias_sweep | Q2 | Frequency vs DC bias; transmon model fit | Tuning curve parameters | 48 h |
| F2 | Flux_sweetspot_operating | Q4, G3 | Ramsey at sweetspot; verify minimal dephasing | T2* > threshold | 48 h |
| F3 | Cryoscope_step_response | G1, G3, F1 | Ramsey interferometry; deconvolve step response | Residual freq error < 0.1% | 48 h |
| F4 | Cryoscope_predistortion | F3 | Inverse filter computation | Predistortion filter coefficients | 48 h |
| F5 | Flux_crosstalk_matrix | F1 (all qubits) | CISCIQ iterative procedure; image processing | RMS error < 1 mPhi0/Phi0 | 168 h |
| F6 | Flux_crosstalk_compensation | F5 | Apply compensation matrix; verify with spectroscopy | Residual crosstalk < 0.5 mPhi0/Phi0 | 168 h |
| F7 | Frequency_optimization_Snake | F6, G3 (all), RO5 (all) | Snake optimizer: minimize multi-qubit error model | All frequency constraints satisfied | 24 h |

### Tier 6: Coupler Calibration (5 nodes)

| ID | Node Name | Dependencies | Analysis Function | Tolerance | Timeout |
|----|-----------|-------------|-------------------|-----------|---------|
| C1 | Coupler_bias_sweep | F1, R1 | Qubit swap rate vs coupler DC bias | Idle point identified | 48 h |
| C2 | Coupler_frequency_mapping | C1 | Spectroscopy or avoided crossing fit | Coupler tuning curve | 48 h |
| C3 | ZZ_interaction_idle | C1, G1, G3 | Conditional Ramsey (ZZ Ramsey) | ZZ < 50 kHz at idle | 8 h |
| C4 | Coupler_crosstalk | C1, F5 | Extend flux crosstalk matrix to coupler lines | Coupler crosstalk < 1 mPhi0/Phi0 | 168 h |
| C5 | Coupler_activation_response | C1, F3 | Cryoscope on coupler line | Response time < threshold | 48 h |

### Tier 7: Two-Qubit Gate Calibration (14 nodes)

| ID | Node Name | Dependencies | Analysis Function | Tolerance | Timeout |
|----|-----------|-------------|-------------------|-----------|---------|
| TQ1 | Chevron_iSWAP | G1(both), G3(both), F4, C1 | 2D oscillation pattern fit | Optimal (amp, duration) identified | 8 h |
| TQ2 | Chevron_CZ | G1(both), G3(both), F4, C1 | 2D oscillation pattern fit | Optimal (amp, duration) identified | 8 h |
| TQ3 | iSWAP_gate_cal | TQ1 | Conditional phase + swap angle extraction | Swap angle +/- 0.01 rad | 4 h |
| TQ4 | CZ_gate_cal | TQ2 | Conditional phase extraction | Cond. phase +/- 0.01 rad of pi | 4 h |
| TQ5 | Virtual_Z_correction_TQ | TQ3 or TQ4 | Single-qubit phase after 2Q gate | Phase +/- 0.005 rad | 4 h |
| TQ6 | Leakage_characterization | TQ3 or TQ4 | Population in |2> after gate; LRB | Leakage < 0.1% | 8 h |
| TQ7 | TQ_gate_fine_amplitude | TQ3 or TQ4 | Error amplification (repeated 2Q gates) | Amplitude +/- 0.1% | 4 h |
| TQ8 | TQ_gate_fine_duration | TQ3 or TQ4 | Error amplification vs duration | Duration +/- 1 ns | 4 h |
| TQ9 | Parasitic_phase_cal | TQ5 | Measure phases on spectator qubits | Spectator phase < 0.01 rad | 8 h |
| TQ10 | Simultaneous_TQ_gate_cal | TQ4 (multiple pairs) | Parallel 2Q gates; measure crosstalk | XEB error < threshold | 8 h |
| TQ11 | CR_Hamiltonian_cal | G1(both), G3(both) | Hamiltonian tomography: IX, IZ, ZI, ZX, ZZ | ZX rate +/- 1% | 4 h |
| TQ12 | CR_echo_cal | TQ11 | Echoed CR; cancel IX and IZ terms | Residual IX, IZ < 1% of ZX | 4 h |
| TQ13 | CNOT_gate_cal | TQ12 | Phase and amplitude fine-tuning | Gate fidelity > 99% | 4 h |
| TQ14 | Gate_set_selection | F7 | Choose iSWAP/CZ/sqrt(iSWAP)/Sycamore per pair | Optimal gate assigned | 24 h |

### Tier 8: Benchmarking & Validation (10 nodes)

| ID | Node Name | Dependencies | Analysis Function | Tolerance | Timeout |
|----|-----------|-------------|-------------------|-----------|---------|
| B1 | SQ_RB_isolated | G9, G10, G8, G12 | Exponential decay: F=Ap^m+B; EPC | EPC < 0.1% | 8 h |
| B2 | SQ_RB_simultaneous | B1 (all qubits) | Parallel RB; detect crosstalk degradation | EPC < 0.15% | 8 h |
| B3 | TQ_RB_isolated | TQ3 or TQ4, TQ5 | Exponential decay for 2Q Cliffords | EPC < 1% | 8 h |
| B4 | TQ_XEB_isolated | TQ3 or TQ4, TQ5 | Cross-entropy from random circuits | XEB error < 0.5% | 8 h |
| B5 | TQ_XEB_parallel | TQ10, B4 | Per-layer parallel XEB; 4 patterns | XEB error < 1% per cycle | 8 h |
| B6 | Readout_error_isolated | RO5 | P00 and P11 error measurement | Total error < 1% | 8 h |
| B7 | Readout_error_parallel | B6 (all qubits) | Simultaneous readout; measure crosstalk | Total error < 2% | 8 h |
| B8 | T1_monitoring | G1 | Repeated T1 measurements; trend analysis | T1 > minimum threshold | 2 h |
| B9 | Quantum_volume | B2, B5, B7 | Heavy output probability | QV >= target | 24 h |
| B10 | Full_system_XEB | B5, B7 | Full circuit fidelity estimation | System fidelity > target | 24 h |

### Tier 9: Active Reset & Runtime (5 nodes)

| ID | Node Name | Dependencies | Analysis Function | Tolerance | Timeout |
|----|-----------|-------------|-------------------|-----------|---------|
| AR1 | Active_reset_cal | RO5, G1 | Measure residual excitation after reset | < 0.5% residual | 24 h |
| AR2 | Reset_duration_opt | AR1 | Sweep reset duration; find minimum | Duration +/- 20 ns | 24 h |
| AR3 | Mid_circuit_measurement | RO5, G1 | Measure back-action on unmeasured qubits | Phase error < 0.01 rad | 8 h |
| AR4 | Leakage_reset_cal | AR1, G1 | Measure |2> population after active reset | |2> pop < 0.1% | 24 h |
| AR5 | Heralded_state_prep | AR1, RO5 | Prepare |0> with measurement + conditional pi | Prep fidelity > 99.9% | 24 h |

### Tier M: Monitoring & Maintenance (10 nodes, continuous)

| ID | Node Name | Dependencies | Analysis Function | Tolerance | Timeout |
|----|-----------|-------------|-------------------|-----------|---------|
| M1 | T1_drift_monitor | G1 | Repeated T1; detect TLS collision | T1 > floor | 30 min |
| M2 | Frequency_drift_monitor | G1 | Repeated Ramsey; track f_q | Drift < 100 kHz | 30 min |
| M3 | Readout_drift_monitor | RO5 | Check IQ cloud separation | Fidelity > threshold | 1 h |
| M4 | TLS_landscape_scan | Q3, G5 | T1 vs frequency; map TLS locations | Updated TLS map | 4 h |
| M5 | Gate_fidelity_monitor | B1, B4 | Quick RB or XEB check | Fidelity > threshold | 2 h |
| M6 | Crosstalk_monitor | B2, B5 | Compare isolated vs simultaneous metrics | Degradation < 50% | 4 h |
| M7 | System_health_dashboard | M1-M6 | Aggregate all monitoring metrics | All systems nominal | continuous |
| M8 | Recalibration_trigger | M7 | Detect out-of-spec conditions; trigger maintain | Auto-trigger when needed | continuous |
| M9 | Calibration_database_update | All | Log all calibration results with timestamps | Database consistent | continuous |
| M10 | TLS_forecast_update | M4, F7 | Update TLS frequency predictions | Forecast accuracy > 80% | 12 h |

### 12.2 Total Node Count Summary

| Tier | Category | Nodes |
|------|----------|-------|
| 0 | Hardware Infrastructure | 4 |
| 1 | Resonator Characterization | 4 |
| 2 | Qubit Discovery | 5 |
| 3 | Single-Qubit Gate Calibration | 12 |
| 4 | Readout Optimization | 6 |
| 5 | Flux Control Calibration | 7 |
| 6 | Coupler Calibration | 5 |
| 7 | Two-Qubit Gate Calibration | 14 |
| 8 | Benchmarking & Validation | 10 |
| 9 | Active Reset & Runtime | 5 |
| M | Monitoring & Maintenance | 10 |
| **Total** | | **82** |

### 12.3 DAG Visualization (Text Format)

```
TIER 0: HARDWARE
  H1(TWPA) ──┐
  H2(Mixer LO)─┤
  H3(Mixer SB)─┤ (H3 depends on H2)
  H4(TOF) ─────┘ (H4 depends on H1)
       |
       v
TIER 1: RESONATOR
  R1(Res Spec) ──> R2(Punchout) ──> R3(Res vs Flux)
       |                                    |
       └──> R4(Dispersive Shift) <──────────┘
       |
       v
TIER 2: QUBIT DISCOVERY
  Q1(Qubit Spec CW) ──> Q2(Pulsed) ──> Q3(Freq vs Flux)
       |                                       |
       |                                Q4(Sweetspot)
       |                                       |
       └──> Q5(Anharmonicity)                  |
       |                                       |
       v                                       v
TIER 3: SINGLE-QUBIT GATES
  G1(Rabi Amp) ──> G3(Ramsey Freq) ──> G7(DRAG Coarse) ──> G8(DRAG Fine)
       |                 |
  G2(Rabi Dur)    G4(T2*), G5(T1), G6(T2 Echo)
       |                 |
       |           G9(Fine X) ──> G11(AllXY)
       |           G10(Fine SX)──> G11
       |                 |
       |           G12(Virtual Z)
       |
       v
TIER 4: READOUT OPTIMIZATION
  RO1(Single Shot) ──> RO2(Freq Opt)
       |              RO3(Amp Opt)
       |              RO4(Dur Opt)
       └──> RO5(Integration Wt) ──> RO6(Mitigation Matrix)
       |
       v
TIER 5: FLUX CONTROL
  F1(Flux Bias Sweep)
  F2(Sweetspot Operating)
  F3(Cryoscope Step) ──> F4(Predistortion)
  F5(Crosstalk Matrix) ──> F6(Compensation)
  F7(Snake Optimizer) <── [F6, G3(all), RO5(all)]
       |
       v
TIER 6: COUPLER
  C1(Coupler Bias) ──> C2(Coupler Freq)
       |              C3(ZZ at Idle)
       |              C4(Coupler Crosstalk)
       └──> C5(Activation Response)
       |
       v
TIER 7: TWO-QUBIT GATES
  TQ1(Chevron iSWAP) ──> TQ3(iSWAP Cal) ──> TQ5(VZ Correction)
  TQ2(Chevron CZ) ──> TQ4(CZ Cal) ──> TQ5
                            |
                   TQ6(Leakage), TQ7(Fine Amp), TQ8(Fine Dur)
                            |
                   TQ9(Parasitic Phase)
                   TQ10(Simultaneous 2Q)
  TQ11(CR Ham) ──> TQ12(CR Echo) ──> TQ13(CNOT)
  TQ14(Gate Set Selection)
       |
       v
TIER 8: BENCHMARKING
  B1(SQ RB Iso) ──> B2(SQ RB Sim)
  B3(TQ RB Iso)
  B4(TQ XEB Iso) ──> B5(TQ XEB Par)
  B6(RO Error Iso) ──> B7(RO Error Par)
  B8(T1 Monitor)
  B9(QV) <── [B2, B5, B7]
  B10(Full XEB) <── [B5, B7]
       |
       v
TIER 9: ACTIVE RESET
  AR1(Reset Cal) ──> AR2(Duration Opt)
  AR3(Mid-Circuit Meas)
  AR4(Leakage Reset)
  AR5(Heralded Prep)

TIER M: MONITORING (continuous, parallel)
  M1(T1 Drift) ──┐
  M2(Freq Drift) ─┤
  M3(RO Drift) ───┤──> M7(Dashboard) ──> M8(Recal Trigger)
  M4(TLS Scan) ───┤
  M5(Gate Mon) ────┤
  M6(XT Mon) ──────┘
  M9(DB Update)
  M10(TLS Forecast)
```

### 12.4 Critical Path Analysis

The longest dependency chain (critical path for initial bringup):

```
H1 -> H4 -> R1 -> R2 -> Q1 -> Q2 -> Q3 -> Q4 -> F1 -> F3 -> F4 -> F5 -> F6 -> F7
 -> G1 -> G3 -> G7 -> G8 -> G9 -> G11 -> RO1 -> RO5 -> C1 -> C3 -> TQ2 -> TQ4
 -> TQ5 -> TQ7 -> TQ10 -> B5 -> B10
```

This chain has **~30 sequential steps**, each taking minutes to tens of minutes, consistent with the reported 36-hour initial bringup time when accounting for parallelizable branches.

### 12.5 Maintenance Mode (Daily Recalibration)

For daily maintenance (~4 hours), the maintain algorithm traverses only nodes whose check_state fails:

**Most frequently recalibrated** (short timeout):
1. M1, M2 (T1 and frequency drift monitoring, every 30 min)
2. G3 (Ramsey frequency, every 1-4 hours)
3. G5, G4 (T1/T2*, every 2-4 hours)
4. TQ4/TQ3 (2Q gate parameters, every 2-8 hours)
5. B4 (XEB verification, every 2-8 hours)

**Rarely recalibrated** (long timeout):
1. F5, F6 (flux crosstalk matrix, every 1-4 weeks)
2. H2, H3 (mixer calibration, weekly)
3. Q5 (anharmonicity, weekly)
4. Q3 (freq vs flux, every 2 days)

---

## 13. Sources and Citations

### Primary Framework References
- [Kelly et al., "Physical qubit calibration on a directed acyclic graph," arXiv:1803.03226 (2018)](https://arxiv.org/abs/1803.03226)
- [Google Patent US9940212B2, "Automatic qubit calibration"](https://patents.google.com/patent/US9940212B2/en)

### Open-Source Frameworks
- [Qibocal: arXiv:2410.00101](https://arxiv.org/abs/2410.00101)
- [Qibocal documentation](https://qibo.science/qibocal/stable/)
- [QUAlibrate GitHub](https://github.com/qua-platform/qualibrate)
- [QUAlibrate documentation](https://qua-platform.github.io/qualibrate/)
- [Qiskit Experiments library](https://qiskit-community.github.io/qiskit-experiments/apidocs/library.html)
- [QubiC: ACM Trans. Quantum Computing, doi:10.1145/3529397](https://dl.acm.org/doi/full/10.1145/3529397)
- [LabOne Q documentation](https://docs.zhinst.com/labone_q_user_manual/)
- [Quantum Machines calibration workbook](https://learn.quantum-machines.co/latest/introduction/)

### Google Quantum AI
- [Sycamore supplementary, arXiv:1910.11333](https://arxiv.org/abs/1910.11333)
- [Snake Optimizer, arXiv:2006.04594](https://arxiv.org/abs/2006.04594)
- [Google Cirq calibration metrics](https://quantumai.google/cirq/google/calibration)
- [Google calibration metrics visualization](https://quantumai.google/cirq/tutorials/google/visualizing_calibration_metrics)
- [Willow: arXiv:2408.13687](https://arxiv.org/abs/2408.13687)
- [Willow spec sheet](https://quantumai.google/static/site-assets/downloads/willow-spec-sheet.pdf)
- [Optimizing quantum gates towards the scale of logical qubits, Nature Communications (2024)](https://www.nature.com/articles/s41467-024-46623-y)

### Drift and Fluctuation Timescales
- [Dynamics of superconducting qubit relaxation times, npj Quantum Information (2022)](https://www.nature.com/articles/s41534-022-00643-y)
- [Decoherence benchmarking of superconducting qubits, npj Quantum Information (2019)](https://www.nature.com/articles/s41534-019-0168-5)
- [Fluctuations of energy-relaxation times in superconducting qubits, Klimov et al. (2018)](https://web.physics.ucsb.edu/~martinisgroup/papers/Klimov2018.pdf)
- [Improving qubit coherence using closed-loop feedback, Nature Communications (2022)](https://pmc.ncbi.nlm.nih.gov/articles/PMC9001732/)
- [Millisecond-scale calibration and benchmarking, arXiv:2602.11912](https://arxiv.org/abs/2602.11912)
- [Real-time adaptive tracking of fluctuating relaxation rates, Phys. Rev. X](https://journals.aps.org/prx/abstract/10.1103/gk1b-stl3)

### Calibration Scheduling and Scaling
- [CaliQEC: ISCA 2025, doi:10.1145/3695053.3731042](https://dl.acm.org/doi/10.1145/3695053.3731042)
- [CaliScalpel: arXiv:2412.02036](https://arxiv.org/abs/2412.02036)
- [Hardware-aware calibration protocol, ISCA 2025](https://dl.acm.org/doi/10.1145/3695053.3731036)

### Flux Crosstalk Calibration
- [CISCIQ: PRX Quantum 2, 040313](https://journals.aps.org/prxquantum/abstract/10.1103/PRXQuantum.2.040313)
- [Learning-based calibration of flux crosstalk, Phys. Rev. Applied 20, 024070](https://journals.aps.org/prapplied/abstract/10.1103/PhysRevApplied.20.024070)
- [Characterizing and mitigating flux crosstalk, arXiv:2508.03434](https://arxiv.org/abs/2508.03434)

### Cryoscope and Flux Pulse Correction
- [Time-domain characterization and correction, Appl. Phys. Lett. 116, 054001 (2020)](https://pubs.aip.org/aip/apl/article/116/5/054001/38884/)
- [Calibrating magnetic flux control, arXiv:2503.04610](https://arxiv.org/abs/2503.04610)

### Two-Qubit Gate Calibration
- [High-fidelity CZ and iSWAP gates with tunable coupler, Phys. Rev. X 11, 021058](https://link.aps.org/doi/10.1103/PhysRevX.11.021058)
- [Chevron protocol, Qibocal](https://qibo.science/qibocal/stable/protocols/chevron.html)
- [High-precision pulse calibration of tunable couplers, arXiv:2410.15041](https://arxiv.org/abs/2410.15041)

### DRAG Calibration
- [Reducing leakage in single-qubit gates, arXiv:2402.17757](https://arxiv.org/abs/2402.17757)
- [Pulse optimization error budgets, arXiv:2511.12799](https://arxiv.org/abs/2511.12799)

### Cross-Resonance Gate (IBM)
- [Procedure for systematically tuning up crosstalk in the CR gate, Phys. Rev. A 93, 060302](https://arxiv.org/abs/1603.04821)
- [Cross-cross resonance gate, PRX Quantum 2, 040336](https://journals.aps.org/prxquantum/abstract/10.1103/PRXQuantum.2.040336)

### Randomized Benchmarking
- [Randomized benchmarking Wikipedia](https://en.wikipedia.org/wiki/Randomized_benchmarking)
- [Standard RB: single-qubit Clifford RB, QuantumBenchmarkZoo](https://quantumbenchmarkzoo.org/content/system-level-benchmark/randomized-benchmarking/single-qubit-CRB)
- [Error per single-qubit gate below 10^-4, npj Quantum Information (2023)](https://www.nature.com/articles/s41534-023-00781-x)

### XEB / Cross-Entropy Benchmarking
- [XEB theory, Cirq documentation](https://quantumai.google/cirq/noise/qcvv/xeb_theory)

### Readout
- [Transmon readout at QEC threshold without quantum-limited amplifier, npj Quantum Information (2023)](https://www.nature.com/articles/s41534-023-00689-6)
- [Measurement-induced state transitions, arXiv:2402.07360](https://arxiv.org/abs/2402.07360)

### General Calibration Theory
- [Optimizing superconducting qubit performance, arXiv:2501.17825](https://arxiv.org/abs/2501.17825)
- [Tailored quantum device calibration with statistical model checking, arXiv:2507.12323](https://arxiv.org/abs/2507.12323)
- [Benchmarking optimization algorithms for automated calibration, arXiv:2509.08555](https://arxiv.org/abs/2509.08555)
