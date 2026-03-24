"""Particle-filter TLS tracker (Algorithm 1)."""

from __future__ import annotations

import numpy as np
from scipy.signal import find_peaks

from .base import TLSForecaster


class SingleTLSTracker:
    """Particle filter for tracking a single TLS defect frequency.

    Parameters
    ----------
    n_particles : int
        Number of particles.
    init_freq : float
        Initial frequency estimate (GHz).
    coupling : float
        Estimated coupling strength (MHz).
    linewidth : float
        Estimated linewidth (MHz).
    diffusion_constant : float
        Spectral diffusion constant in MHz / sqrt(hour).
    """

    def __init__(
        self,
        n_particles: int,
        init_freq: float,
        coupling: float,
        linewidth: float,
        diffusion_constant: float = 2.2,
    ):
        self.particles = np.full(n_particles, init_freq)
        # Add small initial spread so particles are not degenerate
        self.particles += np.random.default_rng().normal(0, 1e-3, n_particles)
        self.weights = np.ones(n_particles) / n_particles
        self.coupling = coupling
        self.linewidth = linewidth
        self.diffusion_constant = diffusion_constant

    # ------------------------------------------------------------------
    # Propagation
    # ------------------------------------------------------------------

    def propagate(self, dt_hours: float, rng: np.random.Generator):
        sigma = self.diffusion_constant * np.sqrt(dt_hours) * 1e-3  # MHz -> GHz
        self.particles += rng.normal(0, sigma, size=len(self.particles))

    # ------------------------------------------------------------------
    # Weight update
    # ------------------------------------------------------------------

    def weight(
        self,
        qubit_freq: float,
        measured_T1: float,
        background_gamma: float = 0.02,
    ):
        """Update weights given a T1 measurement at *qubit_freq*.

        Parameters
        ----------
        qubit_freq : float  (GHz)
        measured_T1 : float  (us)
        background_gamma : float  (1/us)
        """
        measured_gamma = 1.0 / max(measured_T1, 0.1)

        delta = (qubit_freq - self.particles) * 1e3  # MHz
        g = self.coupling
        lw = self.linewidth
        tls_gamma = g**2 * lw / (lw**2 + delta**2)
        predicted_gamma = background_gamma + tls_gamma

        # Gaussian likelihood
        noise_sigma = 0.05  # measurement noise in gamma (1/us)
        log_lik = -0.5 * ((predicted_gamma - measured_gamma) / noise_sigma) ** 2
        log_lik -= log_lik.max()  # numerical stability
        self.weights *= np.exp(log_lik)

        w_sum = self.weights.sum()
        if w_sum > 0:
            self.weights /= w_sum
        else:
            self.weights[:] = 1.0 / len(self.weights)

    # ------------------------------------------------------------------
    # Resampling
    # ------------------------------------------------------------------

    def resample_if_needed(self, rng: np.random.Generator):
        n = len(self.weights)
        ess = 1.0 / np.sum(self.weights**2)
        if ess < n / 2:
            self._systematic_resample(rng)

    def _systematic_resample(self, rng: np.random.Generator):
        n = len(self.weights)
        positions = (rng.random() + np.arange(n)) / n
        cumsum = np.cumsum(self.weights)
        indices = np.searchsorted(cumsum, positions)
        indices = np.clip(indices, 0, n - 1)
        self.particles = self.particles[indices].copy()
        self.weights = np.ones(n) / n

    # ------------------------------------------------------------------
    # Statistics
    # ------------------------------------------------------------------

    @property
    def mean_freq(self) -> float:
        return float(np.average(self.particles, weights=self.weights))

    @property
    def std_freq(self) -> float:
        mean = self.mean_freq
        var = float(np.average((self.particles - mean) ** 2, weights=self.weights))
        return np.sqrt(max(var, 0.0))


class ParticleFilterForecaster(TLSForecaster):
    """TLS forecaster using particle filters.

    Parameters
    ----------
    n_particles : int
        Number of particles per TLS tracker.
    diffusion_constant : float
        Spectral diffusion constant in MHz / sqrt(hour).
    """

    def __init__(self, n_particles: int = 500, diffusion_constant: float = 2.2):
        self.n_particles = n_particles
        self.diffusion_constant = diffusion_constant
        self.tls_trackers: list[SingleTLSTracker] = []
        self.rng = np.random.default_rng()
        self.current_time: float = 0.0
        self._last_update_time: float = 0.0
        self._background_gamma: float = 0.02

    # ------------------------------------------------------------------
    # Initialization from frequency scan
    # ------------------------------------------------------------------

    def initialize_from_scan(
        self,
        frequencies: np.ndarray,
        t1_values: np.ndarray,
        background_T1: float,
    ):
        """Detect TLS dips and create particle trackers."""
        self._background_gamma = 1.0 / background_T1
        gamma1 = 1.0 / np.clip(t1_values, 0.1, None)
        excess = np.clip(gamma1 - self._background_gamma, 0.0, None)

        if excess.max() == 0:
            return

        height_thr = 0.1 * excess.max()
        peaks, _ = find_peaks(excess, height=height_thr, prominence=height_thr * 0.5)

        df = np.abs(frequencies[1] - frequencies[0]) if len(frequencies) > 1 else 0.01

        for pk in peaks:
            f_center = float(frequencies[pk])
            peak_val = excess[pk]

            # FWHM estimation
            half_max = peak_val / 2.0
            left = pk
            while left > 0 and excess[left] > half_max:
                left -= 1
            right = pk
            while right < len(excess) - 1 and excess[right] > half_max:
                right += 1
            fwhm_ghz = (right - left) * df
            linewidth = max(fwhm_ghz * 1e3 / 2.0, 0.05)
            coupling = float(np.sqrt(max(peak_val * linewidth, 0.01)))

            tracker = SingleTLSTracker(
                n_particles=self.n_particles,
                init_freq=f_center,
                coupling=coupling,
                linewidth=linewidth,
                diffusion_constant=self.diffusion_constant,
            )
            self.tls_trackers.append(tracker)

    # ------------------------------------------------------------------
    # Update
    # ------------------------------------------------------------------

    def update(self, t_hours: float, qubit_freq: float, measured_T1: float):
        dt = t_hours - self._last_update_time
        if dt < 0:
            dt = 0.0
        self.current_time = t_hours
        self._last_update_time = t_hours

        for tracker in self.tls_trackers:
            if dt > 0:
                tracker.propagate(dt, self.rng)
            tracker.weight(qubit_freq, measured_T1, self._background_gamma)
            tracker.resample_if_needed(self.rng)

    # ------------------------------------------------------------------
    # Prediction
    # ------------------------------------------------------------------

    def predict(self, t_horizon_hours: float) -> list[dict]:
        results = []
        for tracker in self.tls_trackers:
            f_std_diffusion = self.diffusion_constant * np.sqrt(t_horizon_hours) * 1e-3
            f_std = np.sqrt(tracker.std_freq**2 + f_std_diffusion**2)
            results.append(
                {
                    "freq": tracker.mean_freq,
                    "freq_std": f_std,
                    "coupling": tracker.coupling,
                    "active_prob": 1.0,
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
