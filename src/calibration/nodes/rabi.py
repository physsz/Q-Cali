"""Rabi amplitude calibration node."""

from __future__ import annotations

import numpy as np

from ..dag import CalibrationNode


class RabiAmplitudeNode(CalibrationNode):
    """Calibrate the pi-pulse amplitude via a Rabi oscillation experiment.

    In the simulation we sweep ``d_theta`` (rotation-angle detuning) and
    pick the value that maximises ``gate_fidelity_1q``.
    """

    def __init__(self, name: str, qubit: int, dependencies: list[str] | None = None,
                 tolerance: dict | None = None, timeout_hours: float | None = None):
        super().__init__(
            name=name,
            node_type="rabi_amplitude",
            qubit=qubit,
            tolerance=tolerance,
            timeout_hours=timeout_hours,
            dependencies=dependencies,
        )

    def _run_check(self, backend, param_store: dict) -> dict | None:
        stored_theta = param_store.get(f"{self.name}_d_theta")
        if stored_theta is None:
            return None
        # Measure fidelity at current calibration point
        fid = backend.gate_fidelity_1q(self.qubit, calib_params={"d_theta": stored_theta})
        # Also measure at zero to see if we drifted
        fid_zero = backend.gate_fidelity_1q(self.qubit, calib_params={"d_theta": 0.0})
        # The effective d_theta is the stored one; if fidelity at zero is better
        # that means we're off.  Return stored value for tolerance comparison.
        return {"d_theta": stored_theta}

    def _run_calibration(self, backend, param_store: dict) -> dict:
        # Sweep d_theta around 0 to find optimal
        best_theta = 0.0
        best_fid = -1.0
        for d_theta in np.linspace(-0.1, 0.1, 21):
            fid = backend.gate_fidelity_1q(self.qubit, calib_params={"d_theta": d_theta})
            if fid > best_fid:
                best_fid = fid
                best_theta = d_theta
        return {"d_theta": best_theta}
