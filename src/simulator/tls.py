"""Two-Level System (TLS) defect landscape simulation."""

import numpy as np
from dataclasses import dataclass, field


@dataclass
class TLSDefect:
    """A single TLS defect with frequency diffusion and telegraphic switching."""

    frequency: float  # GHz
    coupling: float  # MHz (g / 2pi)
    linewidth: float  # MHz (gamma)
    switching_rate: float  # Hz
    active: bool = True
    diffusion_constant: float = 2.2  # MHz / sqrt(hour)

    def diffuse(self, dt_hours: float, rng: np.random.Generator):
        """Advance TLS frequency by spectral diffusion."""
        sigma = self.diffusion_constant * np.sqrt(dt_hours) * 1e-3  # convert MHz to GHz
        self.frequency += rng.normal(0, sigma)

    def maybe_switch(self, dt_seconds: float, rng: np.random.Generator):
        """Telegraphic switching."""
        if rng.random() < self.switching_rate * dt_seconds:
            self.active = not self.active

    def relaxation_contribution(self, qubit_freq_ghz: float) -> float:
        """Lorentzian contribution to Gamma_1 (1/us) at a given qubit frequency."""
        if not self.active:
            return 0.0
        delta = (qubit_freq_ghz - self.frequency) * 1e3  # MHz
        g = self.coupling  # MHz
        gamma = self.linewidth  # MHz
        return g**2 * gamma / (gamma**2 + delta**2)  # MHz ~ 1/us


class TLSLandscape:
    """Collection of TLS defects for one or more qubits."""

    def __init__(self, n_qubits: int, n_tls_per_qubit: int = 5,
                 freq_range: tuple[float, float] = (4.0, 7.0),
                 seed: int | None = None):
        self.rng = np.random.default_rng(seed)
        self.defects: dict[int, list[TLSDefect]] = {}

        for q in range(n_qubits):
            self.defects[q] = []
            for _ in range(n_tls_per_qubit):
                self.defects[q].append(TLSDefect(
                    frequency=self.rng.uniform(*freq_range),
                    coupling=np.exp(self.rng.normal(np.log(1.0), 0.5)),  # LogNormal ~1 MHz
                    linewidth=np.exp(self.rng.normal(np.log(0.3), 0.5)),  # LogNormal ~0.3 MHz
                    switching_rate=10 ** self.rng.uniform(-4, 0),  # LogUniform 1e-4 to 1 Hz
                    active=self.rng.random() > 0.3,  # 70% initially active
                    diffusion_constant=2.2 * (1 + 0.3 * self.rng.normal()),
                ))

    def step(self, dt_hours: float):
        """Advance all TLS by dt_hours."""
        dt_seconds = dt_hours * 3600
        for defect_list in self.defects.values():
            for d in defect_list:
                d.diffuse(dt_hours, self.rng)
                d.maybe_switch(dt_seconds, self.rng)

    def total_gamma1(self, qubit_idx: int, qubit_freq_ghz: float) -> float:
        """Total TLS-induced relaxation rate (1/us) for a qubit at given frequency."""
        return sum(d.relaxation_contribution(qubit_freq_ghz)
                   for d in self.defects.get(qubit_idx, []))

    def inject_cosmic_ray(self, n_scramble: int = 5):
        """Scramble n_scramble random TLS frequencies (cosmic ray event)."""
        all_defects = [d for dlist in self.defects.values() for d in dlist]
        if not all_defects:
            return
        targets = self.rng.choice(all_defects, size=min(n_scramble, len(all_defects)),
                                  replace=False)
        for d in targets:
            d.frequency += self.rng.uniform(-0.1, 0.1)  # +/- 100 MHz jump
