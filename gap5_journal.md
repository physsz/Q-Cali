# Gap 5: TLS Forecasting — Design Journal

## 2026-03-24

### Architecture Decisions

1. **ABC in `base.py`**: Defined `TLSForecaster` with four methods (`update`, `predict`,
   `get_exclusion_zones`, `is_frequency_safe`). The `is_frequency_safe` convenience method
   is implemented on the base class since it only delegates to `get_exclusion_zones`.

2. **`ChangePointForecaster` (Algorithm 5)**:
   - Detects TLS dips by running `scipy.signal.find_peaks` on the *excess* relaxation rate
     (`1/T1 - 1/T1_background`). This avoids false positives from the baseline.
   - Estimates coupling from the Lorentzian peak height: `g = sqrt(peak * linewidth)`.
   - CUSUM change-point detection operates on a sliding window of the most recent T1 values.
     When the cumulative sum exceeds `threshold * std`, all tracked TLS get a small bump to
     `active_prob`, signalling that the landscape has shifted.
   - Drift velocity is estimated from consecutive scan-based position updates.
   - Prediction extrapolates linearly (velocity) and adds diffusion uncertainty
     (`D * sqrt(t) * 1e-3` GHz).

3. **`ParticleFilterForecaster` (Algorithm 1)**:
   - Each detected TLS gets its own `SingleTLSTracker` with `n_particles` particles.
   - Propagation adds Gaussian noise scaled by `D * sqrt(dt)`.
   - Weighting uses a Gaussian likelihood on the *total* predicted relaxation rate vs measured.
   - Systematic resampling triggers when ESS < N/2.
   - Prediction combines current particle spread with projected diffusion.

4. **Exclusion zones**: Both forecasters use the same logic — zone half-width is
   `max(2 * freq_std, safety_margin)`. Overlapping zones are merged greedily after sorting.

### Parameter choices

- `noise_sigma = 0.05` (1/us) in the particle filter likelihood. This is a reasonable
  measurement noise level for T1 ~ 20-50 us with ~1000 shots.
- `cusum_threshold = 3.0` standard deviations — standard in process control literature.
- FWHM-to-linewidth conversion: `linewidth = FWHM_GHz * 1e3 / 2` (half-width at half-max
  in MHz), with a floor of 0.05 MHz.

### Test design

- Tests use `TLSLandscape` directly (no `ProcessorModel` needed) to keep dependencies minimal.
- The `_make_scan` helper sweeps 200 frequency points across 4-7 GHz and computes T1 from
  the landscape's `total_gamma1` plus a baseline gamma of 0.02 (T1_bg ~ 50 us).
- Prediction accuracy test uses MAE < 20 MHz, which is relaxed enough to accommodate
  stochastic diffusion over 4 hours.
- Particle filter tracking test uses 100 measurements over 1 hour; expects < 50 MHz error.
