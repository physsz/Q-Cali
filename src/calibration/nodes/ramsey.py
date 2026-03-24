"""Ramsey frequency-offset calibration node."""

from __future__ import annotations

from ..dag import CalibrationNode


class RamseyNode(CalibrationNode):
    """Measure and correct residual frequency offset via Ramsey experiment.

    In the simulation this boils down to re-measuring the qubit frequency and
    computing the offset from the last stored spectroscopy value.
    """

    def __init__(self, name: str, qubit: int, dependencies: list[str] | None = None,
                 tolerance: dict | None = None, timeout_hours: float | None = None):
        super().__init__(
            name=name,
            node_type="ramsey",
            qubit=qubit,
            tolerance=tolerance,
            timeout_hours=timeout_hours,
            dependencies=dependencies,
        )

    def _run_check(self, backend, param_store: dict) -> dict | None:
        stored = param_store.get(f"{self.name}_frequency_offset_ghz")
        if stored is None:
            return None
        # Re-measure offset
        current_freq = backend.measure_frequency(self.qubit, n_shots=1000)
        spec_key = f"qubit_spec_q{self.qubit}_frequency_ghz"
        ref_freq = param_store.get(spec_key, current_freq)
        offset = current_freq - ref_freq
        return {"frequency_offset_ghz": offset}

    def _run_calibration(self, backend, param_store: dict) -> dict:
        current_freq = backend.measure_frequency(self.qubit, n_shots=2000)
        spec_key = f"qubit_spec_q{self.qubit}_frequency_ghz"
        ref_freq = param_store.get(spec_key, current_freq)
        offset = current_freq - ref_freq
        return {"frequency_offset_ghz": offset}
