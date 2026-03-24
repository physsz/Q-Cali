"""DRAG pulse calibration node."""

from __future__ import annotations

import numpy as np

from ..dag import CalibrationNode


class DRAGNode(CalibrationNode):
    """Calibrate the DRAG beta parameter to suppress leakage.

    In the simulation we sweep ``d_beta`` and maximise ``gate_fidelity_1q``.
    """

    def __init__(self, name: str, qubit: int, dependencies: list[str] | None = None,
                 tolerance: dict | None = None, timeout_hours: float | None = None):
        super().__init__(
            name=name,
            node_type="drag",
            qubit=qubit,
            tolerance=tolerance,
            timeout_hours=timeout_hours,
            dependencies=dependencies,
        )

    def _run_check(self, backend, param_store: dict) -> dict | None:
        stored = param_store.get(f"{self.name}_d_beta")
        if stored is None:
            return None
        # Re-check: the stored beta should still be optimal
        return {"d_beta": stored}

    def _run_calibration(self, backend, param_store: dict) -> dict:
        # Get best d_theta from rabi
        rabi_key = f"rabi_q{self.qubit}_d_theta"
        d_theta = param_store.get(rabi_key, 0.0)

        best_beta = 0.0
        best_fid = -1.0
        for d_beta in np.linspace(-0.5, 0.5, 21):
            fid = backend.gate_fidelity_1q(
                self.qubit,
                calib_params={"d_theta": d_theta, "d_beta": d_beta},
            )
            if fid > best_fid:
                best_fid = fid
                best_beta = d_beta
        return {"d_beta": best_beta}
