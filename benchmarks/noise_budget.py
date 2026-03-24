"""Electronics noise budget benchmark.

Compares gate-error contributions from different commercial electronics
platforms and shows that decoherence (T1/T2) dominates over electronics
noise for state-of-the-art hardware.
"""

from __future__ import annotations

import sys
import os

# Ensure the project root is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.simulator.noise import (
    ALL_PROFILES,
    ElectronicsNoiseModel,
)
from src.simulator.processor import ProcessorModel


def compare_platforms(qubit_freq_ghz: float = 5.0,
                      gate_time_ns: float = 25.0) -> dict[str, dict]:
    """Compute error budgets for every pre-configured electronics profile.

    Returns
    -------
    dict mapping profile name -> error breakdown dict (includes '1q_error').
    """
    results: dict[str, dict] = {}
    for profile in ALL_PROFILES:
        model = ElectronicsNoiseModel(profile)
        bd = model.breakdown(qubit_freq_ghz, gate_time_ns)
        bd["feedback_latency_ns"] = profile.feedback_latency_ns
        bd["cost"] = profile.cost_usd
        results[profile.name] = bd
    return results


def _coherence_limited_error(gate_time_ns: float = 25.0) -> float:
    """Compute coherence-limited 1Q gate error from the ProcessorModel."""
    proc = ProcessorModel(n_qubits=1, seed=42)
    q = proc.qubits[0]
    t_gate_us = gate_time_ns * 1e-3  # ns -> us
    return t_gate_us / (2.0 * q.T1) + t_gate_us / (2.0 * q.T2)


def main() -> None:
    results = compare_platforms()

    # Header
    print("=" * 90)
    print("  Electronics Noise Budget  --  Platform Comparison")
    print("=" * 90)

    header = (
        f"{'Platform':<20s} {'DAC quant':>10s} {'Amp noise':>10s} "
        f"{'Phase':>10s} {'Jitter':>10s} {'Thermal':>10s} "
        f"{'1Q total':>10s}"
    )
    print(header)
    print("-" * 90)

    for name, bd in results.items():
        row = (
            f"{name:<20s} "
            f"{bd['dac_quantization']:10.2e} "
            f"{bd['dac_amplitude_noise']:10.2e} "
            f"{bd['phase_noise']:10.2e} "
            f"{bd['timing_jitter']:10.2e} "
            f"{bd['thermal_photon']:10.2e} "
            f"{bd['1q_error']:10.2e}"
        )
        print(row)

    # Coherence-limited comparison
    coh_err = _coherence_limited_error()
    print("-" * 90)
    print(f"{'Coherence limit':<20s} {'':>10s} {'':>10s} {'':>10s} "
          f"{'':>10s} {'':>10s} {coh_err:10.2e}")
    print("=" * 90)

    # Conclusion
    max_elec = max(bd["1q_error"] for bd in results.values())
    if coh_err > max_elec:
        print("\nConclusion: decoherence dominates -- coherence-limited error "
              f"({coh_err:.2e}) exceeds the worst electronics error ({max_elec:.2e}).")
    else:
        print("\nConclusion: electronics noise is competitive with decoherence "
              f"(coherence={coh_err:.2e}, worst electronics={max_elec:.2e}).")

    print()


if __name__ == "__main__":
    main()
