"""Abstract base class for TLS forecasters."""

from abc import ABC, abstractmethod


class TLSForecaster(ABC):
    """ABC for TLS frequency forecasting algorithms."""

    @abstractmethod
    def update(self, t_hours: float, qubit_freq: float, measured_T1: float):
        """Incorporate a new T1 measurement."""
        ...

    @abstractmethod
    def predict(self, t_horizon_hours: float) -> list[dict]:
        """Predict TLS states at a future time horizon.

        Returns list of dicts with keys:
            freq, freq_std, coupling, active_prob
        """
        ...

    @abstractmethod
    def get_exclusion_zones(
        self, t_horizon_hours: float, safety_margin: float = 0.005
    ) -> list[tuple[float, float]]:
        """Return frequency exclusion zones as (f_lo, f_hi) pairs."""
        ...

    def is_frequency_safe(self, freq: float, t_horizon_hours: float) -> bool:
        """Check whether *freq* (GHz) is outside all exclusion zones."""
        for f_lo, f_hi in self.get_exclusion_zones(t_horizon_hours):
            if f_lo <= freq <= f_hi:
                return False
        return True
