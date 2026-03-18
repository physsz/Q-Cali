# Q-Cali Research Journal

Running log of research decisions, findings, and next steps for the superconducting qubit calibration project.

---

## 2026-03-14 — Project Inception & SOTA Survey

### What was done
- Initiated the Q-Cali project: a systematic effort to reproduce and extend Google Quantum AI's superconducting qubit calibration stack.
- Conducted a comprehensive SOTA survey spanning 2014–2026, resulting in `survey.pdf` (21 pages, 38 references in APS style).
- Covered the full calibration hierarchy: spectroscopy, single-qubit gate tune-up (DRAG), two-qubit gate calibration (CZ, CR, iSWAP), readout optimization, frequency-collision management (Snake optimizer), leakage removal (DQLR), benchmarking (XEB, RB, GST), drift tracking, and automation/ML.

### Key findings
- Google's calibration stack is built on two pillars: **Optimus** (DAG-based calibration framework, Kelly et al. 2018) and **Snake** (frequency optimizer, Klimov et al. 2020/2024).
- Processor evolution: Sycamore (53Q, 2019) → 3rd Gen (72Q, 2023) → Willow (105Q, 2024). Fidelities improved from 99.85%/99.64% (1Q/2Q) to 99.97%/99.88%.
- Willow achieved below-threshold QEC with Λ = 2.14 ± 0.02, meaning logical qubits outlive physical ones by 2.4×.

### Ten reproduction gaps identified
Categorized as Critical (4), High (4), or Medium (2):
1. **[Critical]** Full Optimus DAG (node names, tolerances, timeouts) — proprietary
2. [High] Exact single-qubit pulse envelopes & DRAG coefficients
3. **[Critical]** Snake optimizer inner-loop algorithm & weight training
4. [High] Readout model internals
5. **[Critical]** TLS forecasting algorithm — completely undisclosed
6. [High] Leakage iSWAP calibration procedure
7. [Medium] Error-budget decomposition methodology (20% model gap)
8. [Medium] Recalibration cadence details
9. [High] Cirq API is read-only; calibration procedures inaccessible
10. **[Critical]** Custom electronics specifications

### Decision
Focus subsequent work on the four Critical gaps (1, 3, 5, 10) since they are the highest-impact blockers for reproduction.

---

## 2026-03-15 — Gap Solutions Research

### What was done
Launched parallel research agents to investigate solutions for each critical gap. After some agent reliability issues (three agents got stuck and had to be relaunched), all four investigations completed successfully. Results compiled into `gap_solutions.pdf` (19 pages).

### Gap 1: Optimus DAG Reconstruction
- **Sources synthesized**: Qibocal (37 protocols), QUAlibrate (Quantum Machines), Qiskit Experiments (IBM), LabOne Q (Zurich Instruments), Google Patent US9940212B2.
- **Result**: Complete 52-node DAG across 12 layers, with concrete tolerances and timeout values for every node.
- **Key insight**: The tolerance for π-pulse rotation is 10⁻⁴ radians (from the patent). Drift timescales range from sub-second (T₁ telegraphic switching) to days (DRAG coefficient).
- **Architecture**: `check_state` → `check_data` → `calibrate` escalation; `diagnose` for bad-data root-cause analysis.

### Gap 3: Snake Optimizer Internals
- **Error model fully reconstructed**: 4 components (dephasing, relaxation, stray coupling, pulse distortion) with explicit formulas.
- **16-weight structure decoded**: 4 gate contexts × 4 mechanisms. Weights trained by least-squares on ~6,500 CZXEB measurements.
- **Inner-loop candidates**: Grid search (S=1, ~6s), Nelder-Mead (S=2–3, ~130s), CMA-ES (S≥4, ~6500s). These match published runtimes.
- **Collision rules cataloged**: 5 collision types for tunable transmons; 9 constraint families for fixed-frequency (IBM architecture).
- **Pseudocode provided** for both outer loop (graph traversal) and inner loop (optimizer selection).

### Gap 5: TLS Forecasting
- **Central parameter discovered**: Spectral diffusion constant D = 2.2 ± 0.1 MHz/h^(1/2) — this governs all TLS frequency prediction.
- **TLS switching rates span 5 orders of magnitude**: 0.07 mHz to 10 Hz (the 10 Hz rate was newly discovered in Feb 2026 via FPGA Bayesian tracking).
- **Six algorithms proposed**:
  1. Bayesian particle filter (physics-motivated, tracks individual TLS)
  2. Hidden Markov Model (good for activation/deactivation)
  3. LSTM/Transformer neural network (best short-term accuracy)
  4. Gaussian Process regression (natural uncertainty quantification)
  5. **Change-point detection + linear extrapolation** — assessed as most likely what Google actually uses
  6. FPGA-based real-time Bayesian tracker (state-of-art 2026, resolves 10 Hz dynamics)
- **Fundamental limits**: Telegraphic switching (>1 Hz) and cosmic ray scrambling (~1 event/10 min) are inherently unpredictable.

### Gap 10: Custom Electronics
- **Key finding**: At Willow fidelity levels (99.97% 1Q), qubit coherence (T₁/T₂) dominates over electronics noise. All major commercial platforms are sufficient.
- **Five commercial + one open-source platform benchmarked**: ZI SHFQC+ (14-bit, 8.5 GHz), QM OPX1000 (16-bit, 10.5 GHz), Qblox (16-bit, 18.5 GHz), Keysight (12-bit, 16 GHz), QICK (14-bit, 10 GHz, open-source, ~$30-50k).
- **Complete wiring scheme documented**: XY lines (60 dB total attenuation), Z flux lines (RC/copper-powder filters), readout chain (TWPA → HEMT → room-temp).
- **Scaling bottleneck**: At 1000+ qubits, room-temperature electronics face wiring and thermal limits. Cryogenic CMOS is the path forward.

### Decisions
- Algorithm 5 (change-point + extrapolation) is the primary TLS forecasting candidate.
- Nelder-Mead is the default inner-loop optimizer for the Snake (matches Google's known usage).
- QICK is the recommended open-source electronics platform for cost-effective reproduction.

---

## 2026-03-16 — Testbed Design & Repo Setup

### What was done
- Designed a two-track testbed (simulation + experiment) for validating all four gap-filling methods, documented in `testbed.pdf` (16 pages).
- Built the Python simulator: `TransmonQubit`, `TLSLandscape` (spectral diffusion, telegraphic switching, cosmic ray injection), `ProcessorModel` (frequency-dependent T₁, flux noise, readout noise, gate errors, parameter drift).
- Created `ProcessorBackend` ABC so calibration algorithms run unchanged on sim or hardware.
- All 13 unit tests passing.
- Set up repo structure, pushed to GitHub: https://github.com/physsz/Q-Cali

### Simulation model details
- **TLS landscape**: N_TLS per qubit, each with Lorentzian coupling profile, spectral diffusion (D = 2.2 MHz/√h), telegraphic switching (LogUniform 10⁻⁴–1 Hz), cosmic ray scrambling.
- **Drift**: Qubit frequency follows OU process (σ=25 kHz, τ=6 h). Amplitude drifts with Allan deviation feature at ~1000 s.
- **Gate fidelity model**: Coherence-limited + calibration error + electronics noise. Supports both 1Q and 2Q (CZ with ZZ stray coupling).
- **XEB simulation**: Combines 1Q and 2Q gate fidelities with shot noise.

### Benchmark metrics defined (per gap)
- **Gap 1 (DAG)**: Bring-up time (<30 min for 10Q), success rate (>95%), maintenance overhead (<10%), drift detection latency, false positive rate (<5%).
- **Gap 3 (Snake)**: Cycle error reduction (>2×), error model R² (>0.8), outlier fraction (<5%), runtime scaling.
- **Gap 5 (TLS)**: MAE at 4h horizon (<5 MHz), coverage probability (>90%), miss rate (<10%), detection latency (<30 min).
- **Gap 10 (Electronics)**: Noise-to-fidelity mapping, platform comparison validation.

### Repo structure
```
q-cali/
├── src/simulator/       ← Digital twin (DONE)
├── src/calibration/     ← DAG framework (TODO)
├── src/optimizer/       ← Snake optimizer (TODO)
├── src/tls_forecast/    ← TLS algorithms (TODO)
├── src/backend/         ← Hardware abstraction (DONE)
├── tests/               ← 13 passing tests
├── docs/                ← 3 PDFs (survey, gaps, testbed)
└── pyproject.toml
```

---

## Next Steps

### Immediate (next session)
1. Implement the DAG engine (`src/calibration/dag.py`) with `maintain()`, `diagnose()`, `check_state()`.
2. Implement 5–10 core calibration nodes (spectroscopy, Rabi, Ramsey, DRAG, readout).
3. Run DAG cold-start test on 5-qubit simulated processor.

### Short-term (1–2 weeks)
4. Implement the Snake optimizer outer loop + Nelder-Mead inner loop.
5. Implement Algorithm 5 (change-point TLS forecaster) as baseline.
6. Run integration test: DAG + Snake + TLS forecaster on 20-qubit sim for 48 simulated hours.

### Medium-term (1–2 months)
7. Implement remaining TLS algorithms (particle filter, GP) and benchmark against Algorithm 5.
8. Train the 16-weight error model on synthetic CZXEB data.
9. Begin experimental track (if hardware available): deploy DAG on real chip.

### Open questions
- What is the exact inner-loop optimizer Google uses? Nelder-Mead is our best guess but CMA-ES is plausible for higher scope.
- How does the TLS forecasting algorithm interact with the Snake optimizer in real-time? The integration API is undocumented.
- What is the source of the persistent 20% gap between Google's error model prediction and measured Λ?
