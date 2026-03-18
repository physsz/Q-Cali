"""Basic tests for the transmon processor simulator."""

import numpy as np
from src.simulator.transmon import TransmonQubit
from src.simulator.tls import TLSLandscape, TLSDefect
from src.simulator.processor import ProcessorModel
from src.simulator.backend import SimulatedBackend


def test_transmon_frequency_at_sweet_spot():
    q = TransmonQubit(0, f_max=5.5)
    assert abs(q.frequency(0.0) - 5.5) < 0.01


def test_transmon_frequency_flux_dependence():
    q = TransmonQubit(0, f_max=6.0)
    f_sweet = q.frequency(0.0)
    f_away = q.frequency(0.25)
    assert f_away < f_sweet  # frequency decreases away from sweet spot


def test_transmon_drift():
    q = TransmonQubit(0, f_max=5.5)
    f_before = q.frequency()
    rng = np.random.default_rng(42)
    for _ in range(100):
        q.drift(0.1, rng)
    f_after = q.frequency()
    # Should have drifted but not wildly
    assert abs(f_after - f_before) < 0.01  # < 10 MHz


def test_tls_defect_lorentzian():
    d = TLSDefect(frequency=5.5, coupling=1.0, linewidth=0.1,
                  switching_rate=0.0, active=True)
    # On resonance: should be large
    gamma_on = d.relaxation_contribution(5.5)
    # Far off resonance: should be small
    gamma_off = d.relaxation_contribution(6.0)
    assert gamma_on > 10 * gamma_off


def test_tls_landscape_step():
    landscape = TLSLandscape(2, n_tls_per_qubit=3, seed=42)
    freqs_before = [d.frequency for d in landscape.defects[0]]
    landscape.step(1.0)  # 1 hour
    freqs_after = [d.frequency for d in landscape.defects[0]]
    # At least one should have moved
    assert any(abs(a - b) > 1e-6 for a, b in zip(freqs_before, freqs_after))


def test_tls_cosmic_ray():
    landscape = TLSLandscape(2, n_tls_per_qubit=5, seed=42)
    freqs_before = {id(d): d.frequency for dlist in landscape.defects.values() for d in dlist}
    landscape.inject_cosmic_ray(3)
    n_changed = sum(1 for d in (d for dlist in landscape.defects.values() for d in dlist)
                    if abs(d.frequency - freqs_before[id(d)]) > 1e-6)
    assert n_changed >= 1


def test_processor_model_basic():
    proc = ProcessorModel(5, topology="linear", seed=42)
    assert proc.n_qubits == 5
    assert len(proc.coupling_map) == 4


def test_processor_T1_measurement():
    proc = ProcessorModel(3, seed=42)
    t1 = proc.measure_T1(0)
    assert 1.0 < t1 < 200.0  # reasonable range in us


def test_processor_frequency_measurement():
    proc = ProcessorModel(3, seed=42)
    f = proc.measure_frequency(0)
    assert 3.0 < f < 8.0  # GHz range


def test_processor_gate_fidelity():
    proc = ProcessorModel(3, seed=42)
    f1q = proc.gate_fidelity_1q(0)
    assert 0.99 < f1q < 1.0  # should be high fidelity


def test_processor_xeb():
    proc = ProcessorModel(3, topology="linear", seed=42)
    err = proc.run_xeb((0, 1))
    assert 0.0 < err < 0.1  # cycle error should be small but nonzero


def test_processor_time_evolution():
    proc = ProcessorModel(3, seed=42)
    t1_before = proc.measure_T1(0)
    proc.step_time(10.0)  # 10 hours
    t1_after = proc.measure_T1(0)
    # T1 may have changed due to TLS drift (not guaranteed, but test doesn't crash)
    assert 0.1 < t1_after < 500.0


def test_simulated_backend():
    backend = SimulatedBackend(n_qubits=5, seed=42)
    assert backend.n_qubits == 5
    assert len(backend.coupling_map) == 4
    t1 = backend.measure_T1(0)
    assert t1 > 0
    backend.advance_time(1.0)
