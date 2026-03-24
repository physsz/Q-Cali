"""Change-point detection TLS forecaster (Algorithm 5)."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Tuple

import numpy as np
from scipy.signal import find_peaks

from .base import TLSForecaster


@dataclass
class TrackedTLS:
    """State of a single tracked TLS defect."""

    frequency: float  # GHz – current best estimate
    coupling: float  # MHz
    linewidth: float  # MHz
    drift_velocity: float = 0.0  # GHz / hour
    active_prob: float = 1.0
    last_seen: float = 0.0  # hours
    history: list = field(default_factory=list)  # [(time, frequency)]


class ChangePointForecaster(TLSForecaster):
    """TLS forecaster based on change-point (CUSUM) detection.

    Parameters
    ----------
    diffusion_constant : float
        Expected spectral diffusion constant in MHz / sqrt(hour).
    cusum_threshold : float
        Number of standard deviations for the CUSUM alarm.
    """

    def __init__(self, diffusion_constant: float = 2.2, cusum_threshold: float = 3.0):
        self.diffusion_constant = diffusion_constant
        self.cusum_threshold = cusum_threshold
        self.catalog: list[TrackedTLS] = []
        self.t1_history: list[tuple[float, float, float]] = []  # (time, freq, T1)
        self.current_time: float = 0.0

    # ------------------------------------------------------------------
    # Catalog initialisation from a frequency scan
    # ------------------------------------------------------------------

    def catalog_from_scan(
        self,
        frequencies: np.ndarray,
        t1_values: np.ndarray,
        background_T1: float,
    ):
        """Populate the TLS catalog by detecting Lorentzian dips in a T1-vs-freq scan.

        Parameters
        ----------
        frequencies : 1-D array (GHz)
        t1_values : 1-D array (us)
        background_T1 : float (us) – T1 far from any TLS
        """
        gamma1 = 1.0 / np.clip(t1_values, 0.1, None)  # relaxation rate
        background_gamma = 1.0 / background_T1

        excess = gamma1 - background_gamma
        excess = np.clip(excess, 0.0, None)

        # Detect peaks in the excess relaxation rate
        if excess.max() == 0:
            return

        # Use a height threshold and a minimum prominence
        height_thr = 0.1 * excess.max()
        peaks, props = find_peaks(excess, height=height_thr, prominence=height_thr * 0.5)

        df = np.abs(frequencies[1] - frequencies[0]) if len(frequencies) > 1 else 0.01

        for pk in peaks:
            f_center = frequencies[pk]
            peak_excess = excess[pk]

            # Estimate linewidth from half-max width
            half_max = peak_excess / 2.0
            left = pk
            while left > 0 and excess[left] > half_max:
                left -= 1
            right = pk
            while right < len(excess) - 1 and excess[right] > half_max:
                right += 1
            fwhm_ghz = (right - left) * df  # GHz
            linewidth = max(fwhm_ghz * 1e3 / 2.0, 0.05)  # MHz (half-width)

            # coupling^2 * linewidth / linewidth^2 = peak_excess  =>  coupling = sqrt(peak * lw)
            coupling = np.sqrt(max(peak_excess * linewidth, 0.01))

            tls = TrackedTLS(
                frequency=f_center,
                coupling=coupling,
                linewidth=linewidth,
                last_seen=self.current_time,
                history=[(self.current_time, f_center)],
            )
            self.catalog.append(tls)

    # ------------------------------------------------------------------
    # Single-point update (CUSUM on T1 time series)
    # ------------------------------------------------------------------

    def update(self, t_hours: float, qubit_freq: float, measured_T1: float):
        self.current_time = t_hours
        self.t1_history.append((t_hours, qubit_freq, measured_T1))
        self._run_cusum()

    def _run_cusum(self, window: int = 20):
        """Run CUSUM on the most recent *window* T1 values."""
        if len(self.t1_history) < 5:
            return
        recent = self.t1_history[-window:]
        vals = np.array([v for _, _, v in recent])
        mean = vals.mean()
        std = vals.std()
        if std < 1e-12:
            return
        cusum_pos = 0.0
        cusum_neg = 0.0
        for v in vals:
            cusum_pos = max(0.0, cusum_pos + (v - mean) / std)
            cusum_neg = max(0.0, cusum_neg - (v - mean) / std)
            if cusum_pos > self.cusum_threshold or cusum_neg > self.cusum_threshold:
                # Change-point detected – mark all tracked TLS as potentially changed
                for tls in self.catalog:
                    tls.active_prob = min(1.0, tls.active_prob + 0.1)
                break

    # ------------------------------------------------------------------
    # Bulk scan update
    # ------------------------------------------------------------------

    def update_from_scan(
        self,
        t_hours: float,
        frequencies: np.ndarray,
        t1_values: np.ndarray,
    ):
        """Re-detect TLS from a new scan and update the catalog."""
        self.current_time = t_hours
        # Detect fresh TLS
        background_T1 = float(np.percentile(t1_values, 90))
        new_catalog: list[TrackedTLS] = []
        temp_forecaster = ChangePointForecaster(self.diffusion_constant, self.cusum_threshold)
        temp_forecaster.current_time = t_hours
        temp_forecaster.catalog_from_scan(frequencies, t1_values, background_T1)
        new_detections = temp_forecaster.catalog

        # Match new detections to existing catalog by nearest frequency
        used_old = set()
        for nd in new_detections:
            best_idx = -1
            best_dist = float("inf")
            for i, old in enumerate(self.catalog):
                if i in used_old:
                    continue
                dist = abs(nd.frequency - old.frequency)
                if dist < best_dist:
                    best_dist = dist
                    best_idx = i
            if best_idx >= 0 and best_dist < 0.05:  # within 50 MHz
                old = self.catalog[best_idx]
                used_old.add(best_idx)
                old.history.append((t_hours, nd.frequency))
                # Update drift velocity from history
                if len(old.history) >= 2:
                    t0, f0 = old.history[-2]
                    t1_h, f1 = old.history[-1]
                    dt = t1_h - t0
                    if dt > 0:
                        old.drift_velocity = (f1 - f0) / dt
                old.frequency = nd.frequency
                old.coupling = nd.coupling
                old.linewidth = nd.linewidth
                old.last_seen = t_hours
                old.active_prob = 1.0
                new_catalog.append(old)
            else:
                nd.history = [(t_hours, nd.frequency)]
                new_catalog.append(nd)

        # Keep un-matched old TLS with decayed active_prob
        for i, old in enumerate(self.catalog):
            if i not in used_old:
                old.active_prob *= 0.5
                if old.active_prob > 0.05:
                    new_catalog.append(old)

        self.catalog = new_catalog

    # ------------------------------------------------------------------
    # Prediction
    # ------------------------------------------------------------------

    def predict(self, t_horizon_hours: float) -> list[dict]:
        results = []
        for tls in self.catalog:
            f_pred = tls.frequency + tls.drift_velocity * t_horizon_hours
            f_std = self.diffusion_constant * np.sqrt(t_horizon_hours) * 1e-3  # MHz -> GHz
            results.append(
                {
                    "freq": f_pred,
                    "freq_std": f_std,
                    "coupling": tls.coupling,
                    "active_prob": tls.active_prob,
                }
            )
        return results

    # ------------------------------------------------------------------
    # Exclusion zones
    # ------------------------------------------------------------------

    def get_exclusion_zones(
        self, t_horizon_hours: float, safety_margin: float = 0.005
    ) -> list[tuple[float, float]]:
        predictions = self.predict(t_horizon_hours)
        zones: list[tuple[float, float]] = []
        for p in predictions:
            if p["active_prob"] < 0.1:
                continue
            half_width = max(2.0 * p["freq_std"], safety_margin)
            zones.append((p["freq"] - half_width, p["freq"] + half_width))
        return self._merge_zones(zones)

    @staticmethod
    def _merge_zones(zones: list[tuple[float, float]]) -> list[tuple[float, float]]:
        if not zones:
            return []
        zones = sorted(zones, key=lambda z: z[0])
        merged = [zones[0]]
        for lo, hi in zones[1:]:
            if lo <= merged[-1][1]:
                merged[-1] = (merged[-1][0], max(merged[-1][1], hi))
            else:
                merged.append((lo, hi))
        return merged
