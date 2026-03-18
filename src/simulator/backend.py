"""Simulated processor backend implementing the common API."""

from .processor import ProcessorModel


class SimulatedBackend:
    """Backend adapter for the simulated processor.

    Implements the same interface as RealBackend, so calibration
    algorithms can run unchanged on either.
    """

    def __init__(self, n_qubits: int = 5, topology: str = "linear", seed: int | None = 42):
        self.processor = ProcessorModel(n_qubits, topology=topology, seed=seed)

    @property
    def n_qubits(self) -> int:
        return self.processor.n_qubits

    @property
    def coupling_map(self) -> list[tuple[int, int]]:
        return self.processor.coupling_map

    def measure_T1(self, qubit: int, **kwargs) -> float:
        return self.processor.measure_T1(qubit, **kwargs)

    def measure_frequency(self, qubit: int, **kwargs) -> float:
        return self.processor.measure_frequency(qubit, **kwargs)

    def gate_fidelity_1q(self, qubit: int, **kwargs) -> float:
        return self.processor.gate_fidelity_1q(qubit, **kwargs)

    def gate_fidelity_2q(self, q1: int, q2: int, **kwargs) -> float:
        return self.processor.gate_fidelity_2q(q1, q2, **kwargs)

    def run_xeb(self, pair: tuple[int, int], **kwargs) -> float:
        return self.processor.run_xeb(pair, **kwargs)

    def advance_time(self, dt_hours: float):
        self.processor.step_time(dt_hours)
