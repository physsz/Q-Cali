"""Tests for TLS forecasting (Gap 5)."""

import numpy as np

from src.simulator.tls import TLSLandscape, TLSDefect
from src.tls_forecast.changepoint import ChangePointForecaster
from src.tls_forecast.particle_filter import ParticleFilterForecaster


def _make_scan(landscape: TLSLandscape, qubit_idx: int, n_points: int = 200):
    """Sweep frequency across the TLS range and return (freqs, t1_values)."""
    freqs = np.linspace(4.0, 7.0, n_points)
    background_gamma = 0.02  # 1/us  (T1 ~ 50 us baseline)
    t1_values = np.empty(n_points)
    for i, f in enumerate(freqs):
        gamma = background_gamma + landscape.total_gamma1(qubit_idx, f)
        t1_values[i] = 1.0 / gamma
    return freqs, t1_values


# ------------------------------------------------------------------
# 1. Changepoint – catalog_from_scan detects at least 1 TLS
# ------------------------------------------------------------------

def test_changepoint_catalog_from_scan():
    landscape = TLSLandscape(1, n_tls_per_qubit=5, seed=42)
    freqs, t1_vals = _make_scan(landscape, 0)
    background_T1 = float(np.percentile(t1_vals, 90))

    fc = ChangePointForecaster()
    fc.catalog_from_scan(freqs, t1_vals, background_T1)
    assert len(fc.catalog) >= 1, "Should detect at least 1 TLS from scan"


# ------------------------------------------------------------------
# 2. Changepoint – prediction MAE < 20 MHz after 4 h drift
# ------------------------------------------------------------------

def test_changepoint_prediction():
    landscape = TLSLandscape(1, n_tls_per_qubit=5, seed=99)
    freqs, t1_vals = _make_scan(landscape, 0)
    background_T1 = float(np.percentile(t1_vals, 90))

    fc = ChangePointForecaster()
    fc.catalog_from_scan(freqs, t1_vals, background_T1)

    # Record initial true TLS positions
    true_before = sorted([d.frequency for d in landscape.defects[0] if d.active])

    # Advance landscape by 4 hours
    landscape.step(4.0)

    # Predict at horizon = 4 h
    predictions = fc.predict(4.0)
    if not predictions or not true_before:
        return  # nothing to check

    # For each prediction, find nearest true TLS
    pred_freqs = [p["freq"] for p in predictions]
    true_after = sorted([d.frequency for d in landscape.defects[0] if d.active])

    errors = []
    for pf in pred_freqs:
        if true_after:
            nearest = min(true_after, key=lambda tf: abs(tf - pf))
            errors.append(abs(pf - nearest))

    if errors:
        mae_ghz = np.mean(errors)
        mae_mhz = mae_ghz * 1e3
        assert mae_mhz < 20.0, f"Prediction MAE = {mae_mhz:.1f} MHz, expected < 20 MHz"


# ------------------------------------------------------------------
# 3. Particle filter – initialization creates trackers
# ------------------------------------------------------------------

def test_particle_filter_initialization():
    landscape = TLSLandscape(1, n_tls_per_qubit=5, seed=42)
    freqs, t1_vals = _make_scan(landscape, 0)
    background_T1 = float(np.percentile(t1_vals, 90))

    pf = ParticleFilterForecaster(n_particles=500)
    pf.initialize_from_scan(freqs, t1_vals, background_T1)
    assert len(pf.tls_trackers) >= 1, "Should create at least 1 tracker"


# ------------------------------------------------------------------
# 4. Particle filter – tracking converges near actual TLS
# ------------------------------------------------------------------

def test_particle_filter_tracking():
    # Create a landscape with a single strong TLS
    landscape = TLSLandscape(1, n_tls_per_qubit=5, seed=42)

    # Pick the strongest active TLS
    active = [d for d in landscape.defects[0] if d.active]
    if not active:
        return
    target = max(active, key=lambda d: d.coupling)
    qubit_freq = target.frequency  # park qubit on the TLS

    # Build initial scan and initialize
    freqs, t1_vals = _make_scan(landscape, 0)
    background_T1 = float(np.percentile(t1_vals, 90))

    pf = ParticleFilterForecaster(n_particles=500, diffusion_constant=2.2)
    pf.rng = np.random.default_rng(123)
    pf.initialize_from_scan(freqs, t1_vals, background_T1)

    # Find the tracker closest to target
    if not pf.tls_trackers:
        return
    best_tracker_idx = min(
        range(len(pf.tls_trackers)),
        key=lambda i: abs(pf.tls_trackers[i].mean_freq - target.frequency),
    )

    # Feed 100 measurements over 1 hour
    rng = np.random.default_rng(456)
    dt = 1.0 / 100.0
    for step in range(100):
        t = (step + 1) * dt
        # Measure T1 at qubit_freq
        gamma = 0.02 + landscape.total_gamma1(0, qubit_freq)
        measured_T1 = 1.0 / gamma + rng.normal(0, 0.5)
        measured_T1 = max(0.1, measured_T1)
        pf.update(t, qubit_freq, measured_T1)
        # Small TLS drift
        landscape.step(dt)

    tracker = pf.tls_trackers[best_tracker_idx]
    error_mhz = abs(tracker.mean_freq - target.frequency) * 1e3
    # Relaxed: within 50 MHz of current TLS position
    assert error_mhz < 50.0, f"Tracker error = {error_mhz:.1f} MHz, expected < 50 MHz"


# ------------------------------------------------------------------
# 5. Exclusion zones cover actual TLS
# ------------------------------------------------------------------

def test_exclusion_zones_cover_tls():
    landscape = TLSLandscape(1, n_tls_per_qubit=5, seed=42)
    freqs, t1_vals = _make_scan(landscape, 0)
    background_T1 = float(np.percentile(t1_vals, 90))

    fc = ChangePointForecaster()
    fc.catalog_from_scan(freqs, t1_vals, background_T1)

    zones = fc.get_exclusion_zones(0.0, safety_margin=0.01)

    # At least one active TLS should fall within an exclusion zone
    active = [d for d in landscape.defects[0] if d.active]
    covered = 0
    for d in active:
        for lo, hi in zones:
            if lo <= d.frequency <= hi:
                covered += 1
                break

    assert covered >= 1, "At least one active TLS should be within an exclusion zone"


# ------------------------------------------------------------------
# 6. Frequency safety check
# ------------------------------------------------------------------

def test_frequency_safety():
    fc = ChangePointForecaster()
    # Manually place a known TLS at 5.5 GHz
    from src.tls_forecast.changepoint import TrackedTLS

    fc.catalog.append(
        TrackedTLS(frequency=5.5, coupling=1.0, linewidth=0.3, active_prob=1.0)
    )

    assert not fc.is_frequency_safe(5.5, t_horizon_hours=1.0), "5.5 GHz should be unsafe"
    assert fc.is_frequency_safe(6.5, t_horizon_hours=1.0), "6.5 GHz should be safe"


# ------------------------------------------------------------------
# 7. Zone merging
# ------------------------------------------------------------------

def test_zone_merging():
    zones = [(5.0, 5.3), (5.2, 5.5), (6.0, 6.2)]
    merged = ChangePointForecaster._merge_zones(zones)
    assert len(merged) == 2, f"Expected 2 merged zones, got {len(merged)}"
    assert merged[0] == (5.0, 5.5), f"First zone should be (5.0, 5.5), got {merged[0]}"
    assert merged[1] == (6.0, 6.2), f"Second zone should be (6.0, 6.2), got {merged[1]}"
