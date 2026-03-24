"""Spectroscopy calibration nodes: resonator and qubit."""

from __future__ import annotations

from ..dag import CalibrationNode


class ResonatorSpectroscopyNode(CalibrationNode):
    """Calibrate resonator / readout frequency for a qubit.

    In the simulator the resonator frequency is tightly correlated with
    qubit frequency, so we use ``backend.measure_frequency`` as a proxy.
    """

    def __init__(self, name: str, qubit: int, dependencies: list[str] | None = None,
                 tolerance: dict | None = None, timeout_hours: float | None = None):
        super().__init__(
            name=name,
            node_type="resonator_spectroscopy",
            qubit=qubit,
            tolerance=tolerance,
            timeout_hours=timeout_hours,
            dependencies=dependencies,
        )

    def _run_check(self, backend, param_store: dict) -> dict | None:
        stored = param_store.get(f"{self.name}_frequency_ghz")
        if stored is None:
            return None
        measured = backend.measure_frequency(self.qubit, n_shots=500)
        return {"frequency_ghz": measured}

    def _run_calibration(self, backend, param_store: dict) -> dict:
        freq = backend.measure_frequency(self.qubit, n_shots=2000)
        return {"frequency_ghz": freq}


class QubitSpectroscopyNode(CalibrationNode):
    """Calibrate qubit transition frequency via spectroscopy."""

    def __init__(self, name: str, qubit: int, dependencies: list[str] | None = None,
                 tolerance: dict | None = None, timeout_hours: float | None = None):
        super().__init__(
            name=name,
            node_type="qubit_spectroscopy",
            qubit=qubit,
            tolerance=tolerance,
            timeout_hours=timeout_hours,
            dependencies=dependencies,
        )

    def _run_check(self, backend, param_store: dict) -> dict | None:
        stored = param_store.get(f"{self.name}_frequency_ghz")
        if stored is None:
            return None
        measured = backend.measure_frequency(self.qubit, n_shots=500)
        return {"frequency_ghz": measured}

    def _run_calibration(self, backend, param_store: dict) -> dict:
        freq = backend.measure_frequency(self.qubit, n_shots=2000)
        return {"frequency_ghz": freq}
