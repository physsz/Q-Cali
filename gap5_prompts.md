# Gap 5: TLS Forecasting — Prompt

You are implementing Gap 5 (TLS Forecasting) for the Q-Cali project. Working directory: E:\Projects\Q-Cali

## YOUR FILES (only touch these)
- src/tls_forecast/base.py (CREATE)
- src/tls_forecast/changepoint.py (CREATE)
- src/tls_forecast/particle_filter.py (CREATE)
- tests/test_tls_forecast.py (CREATE)
- gap5_journal.md (CREATE)
- gap5_prompts.md (CREATE)

DO NOT modify any existing files.

## Existing API (DO NOT MODIFY)

`src/simulator/tls.py`:
- TLSDefect(frequency, coupling, linewidth, switching_rate, active, diffusion_constant=2.2)
  - .diffuse(dt_hours, rng), .maybe_switch(dt_seconds, rng)
  - .relaxation_contribution(qubit_freq_ghz) -> float (Lorentzian)
- TLSLandscape(n_qubits, n_tls_per_qubit=5, freq_range=(4,7), seed=None)
  - .defects: dict[int, list[TLSDefect]]
  - .step(dt_hours), .total_gamma1(qubit_idx, freq) -> float
  - .inject_cosmic_ray(n_scramble=5)

`src/simulator/processor.py`:
- ProcessorModel.measure_T1(qubit_idx, frequency=None, n_shots=1000) -> float (us)
- ProcessorModel.tls -> TLSLandscape
- ProcessorModel.step_time(dt_hours)

## Implementation

### base.py (~40 lines)
TLSForecaster ABC:
- update(t_hours, qubit_freq, measured_T1): incorporate measurement
- predict(t_horizon_hours) -> list[dict]: {freq, freq_std, coupling, active_prob}
- get_exclusion_zones(t_horizon_hours, safety_margin=0.005) -> list[(f_lo, f_hi)]
- is_frequency_safe(freq, t_horizon_hours) -> bool

### changepoint.py (~250 lines) — Algorithm 5

TrackedTLS dataclass: frequency, coupling, linewidth, drift_velocity, active_prob, last_seen, history list

ChangePointForecaster(TLSForecaster):
- __init__(diffusion_constant=2.2, cusum_threshold=3.0)
- catalog: list[TrackedTLS], t1_history: list[(time, freq, T1)], current_time
- catalog_from_scan(frequencies: ndarray, t1_values: ndarray, background_T1: float):
  - Find Lorentzian dips using scipy.signal.find_peaks on 1/T1
  - For each dip: estimate f_center, coupling (from dip depth), linewidth (from width)
- update(t_hours, qubit_freq, measured_T1):
  - Append to history, run CUSUM on recent values
  - CUSUM: track cumulative sum of (T1 - mean); trigger if |S| > threshold * std
- update_from_scan(t_hours, frequencies, t1_values):
  - Re-detect TLS, match to catalog by nearest frequency, update positions
  - Compute drift_velocity from position history
- predict(t_horizon_hours):
  - For each TLS: f_pred = freq + velocity * t_horizon
  - f_std = D * sqrt(t_horizon) * 1e-3 (MHz->GHz)
- get_exclusion_zones(t_horizon, margin=0.005):
  - For active TLS: zone = (f_pred - max(2*f_std, margin), f_pred + max(2*f_std, margin))
  - Merge overlapping zones
- _merge_zones(zones): sort and merge overlapping intervals

### particle_filter.py (~200 lines) — Algorithm 1

SingleTLSTracker: particles array, weights array, coupling, linewidth
- propagate(dt_hours, rng): particles += N(0, D*sqrt(dt)*1e-3)
- weight(qubit_freq, measured_T1, background_gamma=0.02):
  - For each particle: compute Lorentzian gamma at qubit_freq
  - Likelihood: exp(-0.5*(predicted_total_gamma - measured_gamma)²/noise²)
  - Normalize weights
- resample_if_needed(rng): if ESS < N/2, systematic resample
- mean_freq, std_freq: weighted statistics

ParticleFilterForecaster(TLSForecaster):
- __init__(n_particles=500, diffusion_constant=2.2)
- tls_trackers: list[SingleTLSTracker]
- initialize_from_scan(frequencies, t1_values, background_T1): detect dips, create trackers
- update(t_hours, qubit_freq, measured_T1): propagate + weight + resample all trackers
- predict(t_horizon): mean + propagated std for each tracker

### tests/test_tls_forecast.py — Must pass:

1. test_changepoint_catalog_from_scan:
   - Create TLSLandscape, compute T1 at 100 freq points
   - catalog_from_scan should detect at least 1 TLS

2. test_changepoint_prediction:
   - Initialize forecaster from scan
   - Advance landscape by 4h, predict, check MAE < 20 MHz (relaxed)

3. test_particle_filter_initialization:
   - initialize_from_scan should create trackers

4. test_particle_filter_tracking:
   - Feed 100 T1 measurements over 1 hour
   - Mean particle position should be near actual TLS freq

5. test_exclusion_zones_cover_tls:
   - Get exclusion zones, verify actual TLS falls within a zone

6. test_frequency_safety:
   - Known TLS at 5.5 GHz -> freq 5.5 should be unsafe, 6.5 should be safe

7. test_zone_merging:
   - Two overlapping zones merge correctly

### gap5_journal.md: document decisions
### gap5_prompts.md: copy this prompt

Run `pytest tests/test_tls_forecast.py -v` at the end.
