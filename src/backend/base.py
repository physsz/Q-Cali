"""Abstract base class for processor backends."""

from abc import ABC, abstractmethod


class ProcessorBackend(ABC):
    """Common interface for simulated and real processor backends.

    Calibration algorithms program against this interface,
    enabling seamless switching between simulation and hardware.
    """

    @property
    @abstractmethod
    def n_qubits(self) -> int: ...

    @property
    @abstractmethod
    def coupling_map(self) -> list[tuple[int, int]]: ...

    @abstractmethod
    def measure_T1(self, qubit: int, **kwargs) -> float: ...

    @abstractmethod
    def measure_frequency(self, qubit: int, **kwargs) -> float: ...

    @abstractmethod
    def gate_fidelity_1q(self, qubit: int, **kwargs) -> float: ...

    @abstractmethod
    def gate_fidelity_2q(self, q1: int, q2: int, **kwargs) -> float: ...

    @abstractmethod
    def run_xeb(self, pair: tuple[int, int], **kwargs) -> float: ...
