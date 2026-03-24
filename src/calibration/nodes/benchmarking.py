"""Randomized benchmarking node."""

from __future__ import annotations

from ..dag import CalibrationNode


class RBNode(CalibrationNode):
    """Monitor gate error via single-qubit randomized benchmarking.

    Uses ``gate_fidelity_1q`` to obtain gate error = 1 - fidelity.
    """

    def __init__(self, name: str, qubit: int, dependencies: list[str] | None = None,
                 tolerance: dict | None = None, timeout_hours: float | None = None):
        super().__init__(
            name=name,
            node_type="rb",
            qubit=qubit,
            tolerance=tolerance,
            timeout_hours=timeout_hours,
            dependencies=dependencies,
        )

    def _run_check(self, backend, param_store: dict) -> dict | None:
        stored = param_store.get(f"{self.name}_gate_error")
        if stored is None:
            return None
        # Get current calibration params
        d_theta = param_store.get(f"drag_q{self.qubit}_d_theta",
                                  param_store.get(f"rabi_q{self.qubit}_d_theta", 0.0))
        d_beta = param_store.get(f"drag_q{self.qubit}_d_beta", 0.0)
        fid = backend.gate_fidelity_1q(
            self.qubit, calib_params={"d_theta": d_theta, "d_beta": d_beta}
        )
        return {"gate_error": 1.0 - fid}

    def _run_calibration(self, backend, param_store: dict) -> dict:
        d_theta = param_store.get(f"drag_q{self.qubit}_d_theta",
                                  param_store.get(f"rabi_q{self.qubit}_d_theta", 0.0))
        d_beta = param_store.get(f"drag_q{self.qubit}_d_beta", 0.0)
        fid = backend.gate_fidelity_1q(
            self.qubit, calib_params={"d_theta": d_theta, "d_beta": d_beta}
        )
        return {"gate_error": 1.0 - fid}
