"""Single transmon qubit model."""

import numpy as np


class TransmonQubit:
    """Model of a single frequency-tunable transmon qubit.

    Parameters are drawn from realistic distributions and drift over time.
    """

    def __init__(self, qubit_id: int, f_max: float | None = None, alpha: float | None = None):
        self.qubit_id = qubit_id
        self.f_max = f_max or (5.0 + 0.5 * np.random.uniform(-1, 1))  # GHz
        self.alpha = alpha or (-0.20 + 0.01 * np.random.uniform(-1, 1))  # GHz
        self.f_current = self.f_max  # start at sweet spot
        self.flux_bias = 0.0  # Phi / Phi_0

        # Coherence (will be modulated by TLS landscape)
        self._T1_base = 50 + 30 * np.random.uniform()  # us
        self._T2_base = None  # derived from T1 + T_phi
        self.T1 = self._T1_base
        self.T2 = self._T1_base * 0.8

        # Drift state
        self._freq_drift = 0.0  # kHz accumulated drift
        self._amp_drift = 0.0

    def frequency(self, flux: float | None = None) -> float:
        """Qubit frequency at a given flux bias (GHz)."""
        phi = flux if flux is not None else self.flux_bias
        return self.f_max * np.sqrt(np.abs(np.cos(np.pi * phi))) + self._freq_drift * 1e-6

    def flux_sensitivity(self, flux: float | None = None) -> float:
        """d(omega)/d(Phi) in GHz / Phi_0."""
        phi = flux if flux is not None else self.flux_bias
        eps = 1e-6
        return (self.frequency(phi + eps) - self.frequency(phi - eps)) / (2 * eps)

    def drift(self, dt_hours: float, rng: np.random.Generator | None = None):
        """Apply parameter drift over dt_hours."""
        rng = rng or np.random.default_rng()
        # Frequency: OU process, sigma=25 kHz, tau=6 h
        sigma_f = 25.0  # kHz
        tau_f = 6.0  # hours
        self._freq_drift += (-self._freq_drift / tau_f * dt_hours
                             + sigma_f * np.sqrt(2 * dt_hours / tau_f) * rng.normal())
