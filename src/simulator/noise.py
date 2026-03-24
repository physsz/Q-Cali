"""Electronics noise budget model for superconducting qubit control systems.

Computes gate-error contributions from DAC quantization, amplitude noise,
phase noise, timing jitter, and thermal photons for various commercial
electronics platforms.
"""

from __future__ import annotations

import math
from dataclasses import dataclass


# ---------------------------------------------------------------------------
# Electronics profile dataclass
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class ElectronicsProfile:
    """Specification of a qubit-control electronics platform."""

    name: str
    dac_bits: int
    dac_sample_rate_gsps: float
    phase_noise_dBcHz_10kHz: float   # dBc/Hz at 10 kHz offset
    output_noise_dBmHz: float        # dBm/Hz noise floor
    timing_jitter_ps: float          # RMS jitter in picoseconds
    feedback_latency_ns: float       # round-trip feedback latency
    cost_usd: str                    # approximate price range


# ---------------------------------------------------------------------------
# Pre-configured profiles
# ---------------------------------------------------------------------------

ZURICH_SHFQC_PLUS = ElectronicsProfile(
    name="Zurich SHFQC+",
    dac_bits=14,
    dac_sample_rate_gsps=2.0,
    phase_noise_dBcHz_10kHz=-110.0,
    output_noise_dBmHz=-143.0,
    timing_jitter_ps=1.0,
    feedback_latency_ns=350.0,
    cost_usd="$150-300k",
)

QM_OPX1000 = ElectronicsProfile(
    name="QM OPX1000",
    dac_bits=16,
    dac_sample_rate_gsps=2.0,
    phase_noise_dBcHz_10kHz=-125.0,
    output_noise_dBmHz=-140.0,
    timing_jitter_ps=0.15,
    feedback_latency_ns=160.0,
    cost_usd="$200-500k",
)

QBLOX_CLUSTER = ElectronicsProfile(
    name="Qblox Cluster",
    dac_bits=16,
    dac_sample_rate_gsps=1.0,
    phase_noise_dBcHz_10kHz=-115.0,
    output_noise_dBmHz=-135.0,
    timing_jitter_ps=1.0,
    feedback_latency_ns=364.0,
    cost_usd="$100-250k",
)

KEYSIGHT_QCS = ElectronicsProfile(
    name="Keysight QCS",
    dac_bits=12,
    dac_sample_rate_gsps=11.0,
    phase_noise_dBcHz_10kHz=-110.0,
    output_noise_dBmHz=-135.0,
    timing_jitter_ps=1.0,
    feedback_latency_ns=500.0,
    cost_usd="$100-200k",
)

QICK_ZCU216 = ElectronicsProfile(
    name="QICK ZCU216",
    dac_bits=14,
    dac_sample_rate_gsps=9.85,
    phase_noise_dBcHz_10kHz=-70.0,
    output_noise_dBmHz=-120.0,
    timing_jitter_ps=5.0,
    feedback_latency_ns=1000.0,
    cost_usd="$30-50k",
)

ALL_PROFILES: list[ElectronicsProfile] = [
    ZURICH_SHFQC_PLUS,
    QM_OPX1000,
    QBLOX_CLUSTER,
    KEYSIGHT_QCS,
    QICK_ZCU216,
]


# ---------------------------------------------------------------------------
# Noise model
# ---------------------------------------------------------------------------

class ElectronicsNoiseModel:
    """Compute gate-error contributions from a given electronics profile.

    Each method returns an *error probability* contribution.  The total
    single-qubit gate error is the incoherent sum (simple addition) of all
    independent noise channels.  Two-qubit gates are roughly 2x the
    single-qubit contribution because both qubits are driven.
    """

    def __init__(self, profile: ElectronicsProfile):
        self.profile = profile

    # -- individual error channels ------------------------------------------

    def dac_quantization_error(self, gate_time_ns: float = 25.0) -> float:
        """Error from finite DAC resolution (quantization noise).

        Signal-to-quantization-noise ratio (SQNR) in dB:
            SQNR = 6.02 * bits + 1.76
        The resulting gate error scales as 1 / snr**2.
        """
        sqnr_db = 6.02 * self.profile.dac_bits + 1.76
        snr_linear = 10.0 ** (sqnr_db / 20.0)
        return 1.0 / (snr_linear ** 2)

    def dac_amplitude_noise_error(self) -> float:
        """Error from broadband output noise floor of the DAC.

        Models noise_power * bandwidth / signal_power.  We assume the
        signal power is 0 dBm and the bandwidth is the DAC Nyquist
        bandwidth (sample_rate / 2).
        """
        noise_power_per_hz = 10.0 ** (self.profile.output_noise_dBmHz / 10.0)  # mW/Hz
        bandwidth_hz = self.profile.dac_sample_rate_gsps * 1e9 / 2.0
        signal_power_mw = 1.0  # 0 dBm = 1 mW reference
        return noise_power_per_hz * bandwidth_hz / signal_power_mw

    def phase_noise_error(self, qubit_freq_ghz: float = 5.0,
                          gate_time_ns: float = 25.0) -> float:
        """Error from oscillator phase noise.

        Phase-noise spectral density integrated over the gate produces a
        dephasing error proportional to:
            L(f_offset) [linear] * integration bandwidth * gate_time
        Simplified: 10^(PN/10) * 1e6 * gate_time_s
        where PN is the phase noise in dBc/Hz at 10 kHz offset and the
        factor 1e6 accounts for effective integration bandwidth scaling.
        """
        pn_linear = 10.0 ** (self.profile.phase_noise_dBcHz_10kHz / 10.0)
        gate_time_s = gate_time_ns * 1e-9
        return pn_linear * 1e6 * gate_time_s

    def timing_jitter_error(self, qubit_freq_ghz: float = 5.0) -> float:
        """Error from clock timing jitter.

        A timing jitter sigma_t on a carrier at frequency f causes a
        random phase error (2*pi*f*sigma_t), giving an error:
            e = (2*pi*f*sigma_t)^2 / 2
        """
        f_hz = qubit_freq_ghz * 1e9
        jitter_s = self.profile.timing_jitter_ps * 1e-12
        return (2.0 * math.pi * f_hz * jitter_s) ** 2 / 2.0

    def thermal_photon_error(self, n_bar: float = 1e-3) -> float:
        """Error from residual thermal photons in the readout resonator.

        Each thermal photon causes a dephasing event with probability ~0.1.
        """
        return n_bar * 0.1

    # -- aggregate errors ---------------------------------------------------

    def total_1q_gate_error(self, qubit_freq_ghz: float = 5.0,
                            gate_time_ns: float = 25.0,
                            n_bar: float = 1e-3) -> float:
        """Total single-qubit gate error from all electronics channels."""
        return (
            self.dac_quantization_error(gate_time_ns)
            + self.dac_amplitude_noise_error()
            + self.phase_noise_error(qubit_freq_ghz, gate_time_ns)
            + self.timing_jitter_error(qubit_freq_ghz)
            + self.thermal_photon_error(n_bar)
        )

    def total_2q_gate_error(self, qubit_freq_ghz: float = 5.0,
                            gate_time_ns: float = 25.0,
                            n_bar: float = 1e-3) -> float:
        """Total two-qubit gate error (approximately 2x single-qubit)."""
        return 2.0 * self.total_1q_gate_error(qubit_freq_ghz, gate_time_ns, n_bar)

    # -- convenience --------------------------------------------------------

    def breakdown(self, qubit_freq_ghz: float = 5.0,
                  gate_time_ns: float = 25.0,
                  n_bar: float = 1e-3) -> dict[str, float]:
        """Return a dict of all individual error components plus totals."""
        return {
            "dac_quantization": self.dac_quantization_error(gate_time_ns),
            "dac_amplitude_noise": self.dac_amplitude_noise_error(),
            "phase_noise": self.phase_noise_error(qubit_freq_ghz, gate_time_ns),
            "timing_jitter": self.timing_jitter_error(qubit_freq_ghz),
            "thermal_photon": self.thermal_photon_error(n_bar),
            "1q_error": self.total_1q_gate_error(qubit_freq_ghz, gate_time_ns, n_bar),
            "2q_error": self.total_2q_gate_error(qubit_freq_ghz, gate_time_ns, n_bar),
        }
