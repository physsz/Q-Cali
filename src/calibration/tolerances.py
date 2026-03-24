"""Default tolerance and timeout configurations for calibration nodes."""

# Default tolerances: maps node type to a dict of parameter tolerances.
# Each value is the maximum allowed deviation from the stored calibration value.
DEFAULT_TOLERANCES = {
    "resonator_spectroscopy": {
        "frequency_ghz": 0.001,   # 1 MHz tolerance
    },
    "qubit_spectroscopy": {
        "frequency_ghz": 0.0005,  # 500 kHz tolerance
    },
    "rabi_amplitude": {
        "d_theta": 0.02,          # ~1 degree rotation error
    },
    "ramsey": {
        "frequency_offset_ghz": 0.0002,  # 200 kHz tolerance
    },
    "drag": {
        "d_beta": 0.05,           # DRAG beta tolerance
    },
    "readout": {
        "readout_fidelity": 0.01,  # 1% readout fidelity tolerance
    },
    "rb": {
        "gate_error": 0.002,       # 0.2% gate error tolerance
    },
}

# Default timeouts in hours: how long a calibration result is trusted.
DEFAULT_TIMEOUTS = {
    "resonator_spectroscopy": 4.0,
    "qubit_spectroscopy": 2.0,
    "rabi_amplitude": 1.5,
    "ramsey": 1.0,
    "drag": 2.0,
    "readout": 3.0,
    "rb": 1.0,
}


def get_tolerance(node_type: str, overrides: dict | None = None) -> dict:
    """Return tolerance dict for a node type, with optional overrides."""
    tol = dict(DEFAULT_TOLERANCES.get(node_type, {}))
    if overrides:
        tol.update(overrides)
    return tol


def get_timeout(node_type: str, override: float | None = None) -> float:
    """Return timeout for a node type, with optional override."""
    if override is not None:
        return override
    return DEFAULT_TIMEOUTS.get(node_type, 2.0)
