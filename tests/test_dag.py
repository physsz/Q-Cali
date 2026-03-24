"""Tests for Gap 1 — Calibration DAG Engine."""

import numpy as np
import pytest

from src.simulator.backend import SimulatedBackend
from src.calibration.dag import (
    CalibrationDAG,
    NodeStatus,
    build_default_dag,
)


# ------------------------------------------------------------------ #
# 1. Cold start: 10-qubit backend, all nodes calibrate successfully
# ------------------------------------------------------------------ #

def test_cold_start():
    backend = SimulatedBackend(n_qubits=10, topology="linear", seed=42)
    dag = build_default_dag(backend.n_qubits, backend.coupling_map)
    result = dag.cold_start(backend)

    assert result["success_rate"] > 0.95, (
        f"Cold-start success rate {result['success_rate']:.2f} < 0.95"
    )
    assert result["n_calibrated"] > 0
    print(f"Cold start: {result}")


# ------------------------------------------------------------------ #
# 2. Maintenance under drift: fidelity should stay stable
# ------------------------------------------------------------------ #

def test_maintenance_under_drift():
    backend = SimulatedBackend(n_qubits=5, topology="linear", seed=123)
    dag = build_default_dag(backend.n_qubits, backend.coupling_map)
    dag.cold_start(backend)

    fidelities = []
    for step in range(96):
        backend.advance_time(0.25)
        dag.sim_time += 0.25
        # Maintain all RB nodes (top of each per-qubit chain)
        for q in range(backend.n_qubits):
            dag.maintain(f"rb_q{q}", backend)
        # Measure average fidelity across qubits
        fids = []
        for q in range(backend.n_qubits):
            d_theta = dag.param_store.get(f"rabi_q{q}_d_theta", 0.0)
            d_beta = dag.param_store.get(f"drag_q{q}_d_beta", 0.0)
            fid = backend.gate_fidelity_1q(q, calib_params={"d_theta": d_theta, "d_beta": d_beta})
            fids.append(fid)
        fidelities.append(np.mean(fids))

    fid_std = np.std(fidelities)
    print(f"Fidelity std over 96 steps: {fid_std:.6f}")
    assert fid_std < 0.005, f"Fidelity std {fid_std:.6f} >= 0.005"


# ------------------------------------------------------------------ #
# 3. Diagnosis after T1 drop: recalibration must be triggered
# ------------------------------------------------------------------ #

def test_diagnosis():
    backend = SimulatedBackend(n_qubits=5, topology="linear", seed=99)
    dag = build_default_dag(backend.n_qubits, backend.coupling_map)
    dag.cold_start(backend)

    cal_count_before = len(dag.calibration_log)

    # Inject severe T1 drop on qubit 0
    backend.processor.qubits[0]._T1_base = 5.0
    # Update T1 immediately so measurements reflect the change
    backend.processor.qubits[0].T1 = 5.0
    backend.processor.qubits[0].T2 = 4.5

    # Advance time past the longest timeout so data checks happen
    backend.advance_time(25.0)
    dag.sim_time += 25.0

    # Maintain RB node for qubit 0 — should trigger recalibration
    result = dag.maintain(f"rb_q0", backend)

    cal_count_after = len(dag.calibration_log)
    new_cals = cal_count_after - cal_count_before

    print(f"Diagnosis: {result}, new calibrations logged: {new_cals}")
    assert new_cals > 0, "T1 drop should trigger at least one recalibration"


# ------------------------------------------------------------------ #
# 4. Tolerance sweep: tight tolerances -> more recalibrations
# ------------------------------------------------------------------ #

def test_tolerance_sweep():
    results = {}
    for label, tol_scale in [("tight", 0.2), ("loose", 5.0)]:
        backend = SimulatedBackend(n_qubits=5, topology="linear", seed=77)
        dag = build_default_dag(
            backend.n_qubits, backend.coupling_map,
            tolerance_scale=tol_scale,
        )
        dag.cold_start(backend)

        for _ in range(40):
            backend.advance_time(0.5)
            dag.sim_time += 0.5
            for q in range(backend.n_qubits):
                dag.maintain(f"rb_q{q}", backend)

        # Count calibrations after the cold start
        cold_start_cals = backend.n_qubits * 7  # 7 nodes per qubit
        post_cals = len(dag.calibration_log) - cold_start_cals
        results[label] = post_cals
        print(f"Tolerance {label} (scale={tol_scale}): {post_cals} post-cold-start calibrations")

    assert results["tight"] > results["loose"], (
        f"Tight ({results['tight']}) should recalibrate more than loose ({results['loose']})"
    )


# ------------------------------------------------------------------ #
# 5. Timeout sweep: short timeouts -> more recalibrations
# ------------------------------------------------------------------ #

def test_timeout_sweep():
    results = {}
    for label, timeout_scale in [("short", 0.2), ("long", 5.0)]:
        backend = SimulatedBackend(n_qubits=5, topology="linear", seed=55)
        dag = build_default_dag(
            backend.n_qubits, backend.coupling_map,
            timeout_scale=timeout_scale,
        )
        dag.cold_start(backend)

        for _ in range(40):
            backend.advance_time(0.5)
            dag.sim_time += 0.5
            for q in range(backend.n_qubits):
                dag.maintain(f"rb_q{q}", backend)

        cold_start_cals = backend.n_qubits * 7
        post_cals = len(dag.calibration_log) - cold_start_cals
        results[label] = post_cals
        print(f"Timeout {label} (scale={timeout_scale}): {post_cals} post-cold-start calibrations")

    assert results["short"] > results["long"], (
        f"Short ({results['short']}) should recalibrate more than long ({results['long']})"
    )
