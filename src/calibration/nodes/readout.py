"""Readout calibration node."""

from __future__ import annotations

from ..dag import CalibrationNode


class ReadoutNode(CalibrationNode):
    """Calibrate and monitor readout fidelity.

    Uses ``gate_fidelity_1q`` as a proxy for assignment fidelity in the
    simulation (readout errors are baked into coherence-limited fidelity).
    """

    def __init__(self, name: str, qubit: int, dependencies: list[str] | None = None,
                 tolerance: dict | None = None, timeout_hours: float | None = None):
        super().__init__(
            name=name,
            node_type="readout",
            qubit=qubit,
            tolerance=tolerance,
            timeout_hours=timeout_hours,
            dependencies=dependencies,
        )

    def _run_check(self, backend, param_store: dict) -> dict | None:
        stored = param_store.get(f"{self.name}_readout_fidelity")
        if stored is None:
            return None
        fid = backend.gate_fidelity_1q(self.qubit)
        return {"readout_fidelity": fid}

    def _run_calibration(self, backend, param_store: dict) -> dict:
        fid = backend.gate_fidelity_1q(self.qubit)
        return {"readout_fidelity": fid}
