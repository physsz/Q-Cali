# Numerical Simulation Plan: Gap-Filling Implementation

This plan maps each critical gap to concrete implementation tasks, anchored to the simulation tests defined in `testbed.typ`.

---

## Gap 1: Calibration DAG Engine

### Objective
Implement the 52-node DAG framework with `maintain()`, `diagnose()`, `check_state()`, `check_data()`, `calibrate()` methods. Pass all 5 simulation tests from testbed Section III.

### Implementation Tasks

1. **`src/calibration/dag.py`** — Core DAG engine
   - `CalibrationNode` base class with: parameters, tolerance, timeout, dependencies, analysis function
   - Three methods per node: `check_state()`, `check_data()`, `calibrate()`
   - Three outcomes for `check_data`: `IN_SPEC`, `OUT_OF_SPEC`, `BAD_DATA`
   - `maintain(node)`: recursive descent to root, escalating as needed
   - `diagnose(node)`: triggered on BAD_DATA, investigates ancestors
   - Parameter store: dict mapping node → calibrated values + timestamps

2. **`src/calibration/nodes/`** — Implement 10 core nodes (sufficient for 5-qubit tests)
   - `spectroscopy.py`: ResonatorSpectroscopy, QubitSpectroscopy
   - `rabi.py`: RabiAmplitude
   - `ramsey.py`: RamseyCalibration (fine frequency + T2*)
   - `drag.py`: DRAGCalibration
   - `readout.py`: ReadoutOptimization, SingleShotClassification
   - `cz.py`: ChevronScan, CZPhaseCalibration
   - `benchmarking.py`: RandomizedBenchmarking

3. **`src/calibration/tolerances.py`** — Default tolerance/timeout table from gap_solutions

### Simulation Tests to Pass

| Test | Description | Pass Criterion |
|------|------------|----------------|
| Cold Start | Full DAG from scratch on 10Q sim | All nodes pass, < 30 min sim-time |
| Maintenance | 24h drift with periodic `maintain()` | Fidelity σ < 0.05%, overhead < 10% |
| Diagnosis | Inject T₁ drop, verify root-cause detection | Correct diagnosis > 90% |
| Tolerance Sweep | Vary tolerances, measure recal frequency | Pareto frontier plotted |
| Timeout Sweep | Vary timeouts, measure FP/FN rates | FP < 5%, FN < 10% |

### Files to Create
- `src/calibration/dag.py`
- `src/calibration/nodes/spectroscopy.py`
- `src/calibration/nodes/rabi.py`
- `src/calibration/nodes/ramsey.py`
- `src/calibration/nodes/drag.py`
- `src/calibration/nodes/readout.py`
- `src/calibration/nodes/cz.py`
- `src/calibration/nodes/benchmarking.py`
- `src/calibration/tolerances.py`
- `tests/test_dag.py`

---

## Gap 3: Snake Frequency Optimizer

### Objective
Implement the Snake optimizer with the 4-component error model, 16-weight training, and 3 inner-loop optimizers. Pass all 5 simulation tests from testbed Section IV.

### Implementation Tasks

1. **`src/optimizer/error_model.py`** — 4-component error estimator
   - `dephasing_error(freq, flux_sensitivity_spectrum)`
   - `relaxation_error(freq, T1_spectrum)`
   - `stray_coupling_error(freq_config, coupling_map, anharmonicities)`
   - `pulse_distortion_error(idle_freq, interaction_freq)`
   - `ErrorModel` class: combines 4 components with 16 trainable weights
   - `train_weights(configs, measured_errors)`: least-squares on CZXEB data

2. **`src/optimizer/collision.py`** — Frequency collision rules
   - 5 collision conditions for tunable transmons
   - `check_collisions(freq_config, coupling_map)` → list of violations
   - Minimum separation thresholds

3. **`src/optimizer/inner_loop.py`** — Three optimizer backends
   - `grid_search(objective, bounds, n_points=100)`
   - `nelder_mead_optimize(objective, x0, constraints)`
   - `cmaes_optimize(objective, x0, sigma0)`
   - `select_optimizer(scope_S)` → returns appropriate backend

4. **`src/optimizer/snake.py`** — Snake outer loop
   - `snake_optimize(processor, scope_S, char_data, weights)` → frequency config
   - Graph traversal with constraint propagation
   - `heal(processor, freq_config, outlier_qubits)` → patched config

### Simulation Tests to Pass

| Test | Description | Pass Criterion |
|------|------------|----------------|
| Error Model Accuracy | Predicted vs ground-truth errors | R² > 0.8 |
| Weight Training | Train on synthetic CZXEB, test on held-out | Prediction within 2× |
| Inner-Loop Comparison | Grid/NM/CMA-ES at S=1,2,4 | Matches published runtime ratios |
| Scaling | N=9 to N=105 on grid | β < 2 in runtime ∝ N^β |
| Healing | Fix 5-10 outliers post-optimization | > 48% outlier suppression |

### Files to Create
- `src/optimizer/error_model.py`
- `src/optimizer/collision.py`
- `src/optimizer/inner_loop.py`
- `src/optimizer/snake.py`
- `tests/test_snake.py`

---

## Gap 5: TLS Forecasting

### Objective
Implement Algorithm 5 (change-point + extrapolation) and Algorithm 1 (particle filter). Pass all 5 simulation tests from testbed Section V.

### Implementation Tasks

1. **`src/tls_forecast/changepoint.py`** — Algorithm 5 (baseline, most likely Google approach)
   - `TLSCatalog`: stores known defects {freq, coupling, linewidth}
   - `ChangePointDetector`: CUSUM-based detection on T₁ time series
   - `LinearExtrapolator`: per-TLS frequency prediction with diffusion uncertainty
   - `ExclusionZoneManager`: maintains frequency bands to avoid
   - `forecast(t_horizon)` → predicted TLS positions with confidence intervals

2. **`src/tls_forecast/particle_filter.py`** — Algorithm 1 (physics-motivated)
   - `TLSParticle`: state = {freq, coupling, linewidth, active}
   - `ParticleFilterTracker`: N particles per TLS, diffusion dynamics
   - `update(T1_measurement)`: weight particles by Lorentzian likelihood
   - `resample()`: when ESS < N/2
   - `predict(t_horizon)` → ensemble-based prediction

3. **`src/tls_forecast/base.py`** — Common interface
   - `TLSForecaster` ABC with `update()`, `predict()`, `get_exclusion_zones()`

### Simulation Tests to Pass

| Test | Description | Pass Criterion |
|------|------------|----------------|
| Algorithm Accuracy | MAE of predicted TLS freq at 1,4,12,24h | MAE < 5 MHz at 4h |
| Frequency Allocation | Time with T₁ < 20 μs over 100h | < 2% |
| Model Mismatch | Vary true D by ±50% | Graceful degradation |
| Cosmic Ray Injection | Scramble every ~600s | Detection < 30 min |
| Scaling | N_TLS = 5 to 500 per qubit | Sublinear compute |

### Files to Create
- `src/tls_forecast/base.py`
- `src/tls_forecast/changepoint.py`
- `src/tls_forecast/particle_filter.py`
- `tests/test_tls_forecast.py`

---

## Gap 10: Electronics Noise Budget

### Objective
Add configurable electronics noise injection to the simulator. Validate that decoherence dominates at Willow specs. Pass all 3 simulation tests from testbed Section VI.

### Implementation Tasks

1. **`src/simulator/noise.py`** — Electronics noise models
   - `dac_amplitude_noise(snr_db)` → gate error contribution
   - `phase_noise_error(dbcHz_at_10kHz, gate_time)` → dephasing contribution
   - `timing_jitter_error(sigma_ps, freq_ghz)` → phase error
   - `thermal_photon_error(n_bar)` → readout degradation
   - `ElectronicsNoiseModel`: combines all sources, configurable per-platform

2. **Update `src/simulator/processor.py`** — Integrate noise model into gate fidelity calculations

3. **`benchmarks/noise_budget.py`** — Sweep script
   - Sweep each noise parameter, plot fidelity vs noise
   - Pre-configured profiles for ZI, QM, Qblox, Keysight, QICK

### Simulation Tests to Pass

| Test | Description | Pass Criterion |
|------|------------|----------------|
| Noise-to-Fidelity Map | Per-parameter sweep | Crossover point identified |
| Combined Budget | Platform-specific configs | Ranking matches expectations |
| Calibration Sensitivity | 2× and 5× noise increase | Quantified degradation |

### Files to Create
- `src/simulator/noise.py`
- `benchmarks/noise_budget.py`
- `tests/test_noise.py`

---

## Execution Order

All 4 gaps can be implemented in parallel since they depend on the existing simulator but not on each other. Each gap gets its own git worktree branch.

| Gap | Branch | Estimated Complexity |
|-----|--------|---------------------|
| 1 | `gap1-dag` | High (10 files, ~800 LOC) |
| 3 | `gap3-snake` | High (5 files, ~600 LOC) |
| 5 | `gap5-tls` | Medium (4 files, ~500 LOC) |
| 10 | `gap10-noise` | Low (3 files, ~300 LOC) |
