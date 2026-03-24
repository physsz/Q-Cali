"""Tests for electronics noise budget (Gap 10)."""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest

from src.simulator.noise import (
    ALL_PROFILES,
    ElectronicsNoiseModel,
    ElectronicsProfile,
    QM_OPX1000,
    QICK_ZCU216,
)
from src.simulator.processor import ProcessorModel
from benchmarks.noise_budget import compare_platforms


# ---- 1. Basic construction ------------------------------------------------

def test_noise_model_creates():
    """ElectronicsNoiseModel(QM_OPX1000) works and gives sane error."""
    model = ElectronicsNoiseModel(QM_OPX1000)
    err = model.total_1q_gate_error()
    assert err > 0, "Error must be positive"
    assert err < 0.01, f"Error unreasonably large: {err}"


# ---- 2. All profiles produce valid errors ---------------------------------

def test_all_profiles():
    """Every pre-configured profile gives a 1Q error in (0, 0.1)."""
    for profile in ALL_PROFILES:
        model = ElectronicsNoiseModel(profile)
        err = model.total_1q_gate_error()
        assert 0 < err < 0.1, (
            f"{profile.name}: 1Q error {err} outside (0, 0.1)"
        )


# ---- 3. Higher noise -> higher error --------------------------------------

def test_higher_noise_higher_error():
    """An 8-bit / -70 dBc profile must have higher error than 16-bit / -130 dBc."""
    noisy = ElectronicsProfile(
        name="Noisy",
        dac_bits=8,
        dac_sample_rate_gsps=1.0,
        phase_noise_dBcHz_10kHz=-70.0,
        output_noise_dBmHz=-100.0,
        timing_jitter_ps=10.0,
        feedback_latency_ns=2000.0,
        cost_usd="$5k",
    )
    quiet = ElectronicsProfile(
        name="Quiet",
        dac_bits=16,
        dac_sample_rate_gsps=1.0,
        phase_noise_dBcHz_10kHz=-130.0,
        output_noise_dBmHz=-150.0,
        timing_jitter_ps=0.1,
        feedback_latency_ns=100.0,
        cost_usd="$500k",
    )
    err_noisy = ElectronicsNoiseModel(noisy).total_1q_gate_error()
    err_quiet = ElectronicsNoiseModel(quiet).total_1q_gate_error()
    assert err_noisy > err_quiet, (
        f"Noisy ({err_noisy:.2e}) should exceed quiet ({err_quiet:.2e})"
    )


# ---- 4. Decoherence dominates over best electronics ----------------------

def test_decoherence_dominates():
    """Coherence-limited error must exceed OPX1000 electronics error."""
    proc = ProcessorModel(n_qubits=1, seed=42)
    q = proc.qubits[0]
    t_gate_us = 25e-3  # 25 ns in us
    coherence_error = t_gate_us / (2.0 * q.T1) + t_gate_us / (2.0 * q.T2)

    elec_error = ElectronicsNoiseModel(QM_OPX1000).total_1q_gate_error()
    assert coherence_error > elec_error, (
        f"Coherence ({coherence_error:.2e}) should dominate "
        f"electronics ({elec_error:.2e})"
    )


# ---- 5. Platform ranking --------------------------------------------------

def test_platform_ranking():
    """OPX1000 must have lower total 1Q error than QICK ZCU216."""
    opx_err = ElectronicsNoiseModel(QM_OPX1000).total_1q_gate_error()
    qick_err = ElectronicsNoiseModel(QICK_ZCU216).total_1q_gate_error()
    assert opx_err < qick_err, (
        f"OPX1000 ({opx_err:.2e}) should be lower than QICK ({qick_err:.2e})"
    )


# ---- 6. Benchmark runner --------------------------------------------------

def test_benchmark_runs():
    """compare_platforms() returns 5 entries, each with a '1q_error' key."""
    results = compare_platforms()
    assert len(results) == 5, f"Expected 5 entries, got {len(results)}"
    for name, bd in results.items():
        assert "1q_error" in bd, f"Missing '1q_error' key for {name}"
