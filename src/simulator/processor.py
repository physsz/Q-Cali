"""Multi-qubit processor model with noise and drift."""

import numpy as np
from .transmon import TransmonQubit
from .tls import TLSLandscape


class ProcessorModel:
    """Simulated transmon processor with realistic noise and drift.

    Exposes the same measurement API as a real hardware backend,
    enabling calibration algorithms to run unchanged on either.
    """

    def __init__(self, n_qubits: int, n_levels: int = 3,
                 topology: str = "linear", seed: int | None = None):
        self.n_qubits = n_qubits
        self.n_levels = n_levels
        self.rng = np.random.default_rng(seed)

        # Qubits
        self.qubits = [TransmonQubit(i) for i in range(n_qubits)]

        # Coupling map
        self.coupling_map = self._build_coupling_map(topology)
        self.couplings = {pair: 0.005 + 0.003 * self.rng.uniform()
                          for pair in self.coupling_map}  # GHz

        # TLS landscape
        self.tls = TLSLandscape(n_qubits, n_tls_per_qubit=5, seed=seed)

        # Clock
        self.sim_time_hours = 0.0

        # Readout confusion matrix per qubit
        self.readout_error_0 = 0.005 + 0.01 * self.rng.uniform(size=n_qubits)
        self.readout_error_1 = 0.01 + 0.03 * self.rng.uniform(size=n_qubits)

        # Electronics noise (configurable)
        self.dac_snr_db = 65.0
        self.phase_noise_dbcHz = -120.0

    def _build_coupling_map(self, topology: str) -> list[tuple[int, int]]:
        n = self.n_qubits
        if topology == "linear":
            return [(i, i + 1) for i in range(n - 1)]
        elif topology == "grid":
            side = int(np.ceil(np.sqrt(n)))
            pairs = []
            for i in range(n):
                r, c = divmod(i, side)
                if c + 1 < side and i + 1 < n:
                    pairs.append((i, i + 1))
                if r + 1 < side and i + side < n:
                    pairs.append((i, i + side))
            return pairs
        raise ValueError(f"Unknown topology: {topology}")

    def step_time(self, dt_hours: float):
        """Advance simulation clock and all drift processes."""
        self.sim_time_hours += dt_hours
        self.tls.step(dt_hours)
        for q in self.qubits:
            q.drift(dt_hours, self.rng)
            # Update T1 from TLS landscape
            tls_gamma = self.tls.total_gamma1(q.qubit_id, q.frequency())
            base_gamma = 1.0 / q._T1_base
            q.T1 = 1.0 / (base_gamma + tls_gamma)
            q.T2 = min(2 * q.T1, q.T1 * 0.9)

    def measure_T1(self, qubit_idx: int, frequency: float | None = None,
                   n_shots: int = 1000) -> float:
        """Simulate a T1 measurement with shot noise."""
        q = self.qubits[qubit_idx]
        f = frequency or q.frequency()
        tls_gamma = self.tls.total_gamma1(qubit_idx, f)
        true_T1 = 1.0 / (1.0 / q._T1_base + tls_gamma)
        # Add measurement noise (shot noise limited)
        noise_sigma = true_T1 / np.sqrt(n_shots)
        return max(0.1, true_T1 + self.rng.normal(0, noise_sigma))

    def measure_frequency(self, qubit_idx: int, n_shots: int = 1000) -> float:
        """Simulate a spectroscopy measurement."""
        true_f = self.qubits[qubit_idx].frequency()
        noise_sigma = 0.0005 / np.sqrt(n_shots / 100)  # ~500 kHz at 100 shots
        return true_f + self.rng.normal(0, noise_sigma)

    def gate_fidelity_1q(self, qubit_idx: int, calib_params: dict | None = None) -> float:
        """Compute single-qubit gate fidelity given current calibration."""
        q = self.qubits[qubit_idx]
        t_gate = 25e-3  # us (25 ns)

        # Coherence-limited error
        e_coh = t_gate / (2 * q.T1) + t_gate / (2 * q.T2)

        # Calibration error (if params provided)
        e_cal = 0.0
        if calib_params:
            # Rotation angle error
            d_theta = calib_params.get("d_theta", 0.0)
            e_cal += d_theta**2 / 2
            # DRAG error
            d_beta = calib_params.get("d_beta", 0.0)
            e_cal += d_beta**2 * 0.01  # simplified

        # Electronics noise contribution
        dac_snr = 10 ** (self.dac_snr_db / 20)
        e_elec = 1.0 / dac_snr**2

        return 1.0 - e_coh - e_cal - e_elec

    def gate_fidelity_2q(self, q1: int, q2: int,
                         calib_params: dict | None = None) -> float:
        """Compute two-qubit CZ gate fidelity."""
        qA, qB = self.qubits[q1], self.qubits[q2]
        t_gate = 42e-3  # us (42 ns)

        # Coherence-limited
        e_coh = t_gate * (1 / qA.T1 + 1 / qB.T1 + 1 / qA.T2 + 1 / qB.T2) / 4

        # Stray ZZ
        pair = (min(q1, q2), max(q1, q2))
        J = self.couplings.get(pair, 0.0)
        delta = qA.frequency() - qB.frequency()
        alpha = qA.alpha
        if abs(delta) > 0.01:
            zz = abs(2 * (alpha + qB.alpha) * J**2
                     / ((delta + alpha) * (delta - qB.alpha)))
        else:
            zz = abs(J)
        e_zz = zz * t_gate * 1e3  # rough estimate

        # Calibration error
        e_cal = 0.0
        if calib_params:
            d_phi = calib_params.get("d_phi", 0.0)
            e_cal += d_phi**2 / 2

        return max(0.0, 1.0 - e_coh - e_zz - e_cal)

    def run_xeb(self, qubit_pair: tuple[int, int], n_cycles: int = 20,
                n_circuits: int = 50) -> float:
        """Simulate XEB cycle error for a qubit pair."""
        f_2q = self.gate_fidelity_2q(*qubit_pair)
        f_1q_a = self.gate_fidelity_1q(qubit_pair[0])
        f_1q_b = self.gate_fidelity_1q(qubit_pair[1])
        cycle_fidelity = f_2q * f_1q_a * f_1q_b
        cycle_error = 1.0 - cycle_fidelity
        # Add shot noise
        noise = self.rng.normal(0, cycle_error * 0.1 / np.sqrt(n_circuits))
        return max(0.0, cycle_error + noise)
