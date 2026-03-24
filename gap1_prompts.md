You are implementing Gap 1 (Calibration DAG Engine) for the Q-Cali project. Working directory: E:\Projects\Q-Cali

## YOUR FILES (only touch these)
- src/calibration/dag.py (CREATE)
- src/calibration/tolerances.py (CREATE)
- src/calibration/nodes/spectroscopy.py (CREATE)
- src/calibration/nodes/rabi.py (CREATE)
- src/calibration/nodes/ramsey.py (CREATE)
- src/calibration/nodes/drag.py (CREATE)
- src/calibration/nodes/readout.py (CREATE)
- src/calibration/nodes/benchmarking.py (CREATE)
- tests/test_dag.py (CREATE)
- gap1_journal.md (CREATE)
- gap1_prompts.md (CREATE)

DO NOT modify any existing files. Only create the files listed above.

## Existing API you use (DO NOT MODIFY these files)

`src/simulator/backend.py` — SimulatedBackend:
- .n_qubits, .coupling_map
- .measure_T1(qubit, frequency=None, n_shots=1000) -> float (T1 in us)
- .measure_frequency(qubit, n_shots=1000) -> float (freq in GHz)
- .gate_fidelity_1q(qubit, calib_params=None) -> float
- .gate_fidelity_2q(q1, q2, calib_params=None) -> float
- .run_xeb(pair, n_cycles=20, n_circuits=50) -> float (cycle error)
- .advance_time(dt_hours)
- .processor.qubits[i].frequency() -> float (GHz)
- .processor.qubits[i].alpha -> float (GHz, negative ~-0.2)
- .processor.qubits[i].T1 -> float (us)
- .processor.qubits[i]._T1_base -> float (us, can be modified to inject failures)

## Implementation Requirements

### dag.py
- NodeStatus enum: IN_SPEC, OUT_OF_SPEC, BAD_DATA, UNCALIBRATED
- CalibrationNode base class: name, tolerance dict, timeout_hours, dependencies list, last_result, last_check_time
  - check_state(param_store, current_time) -> bool: metadata check (within timeout, deps not recalibrated since)
  - check_data(backend, param_store) -> NodeStatus: calls _run_check() (subclass)
  - calibrate(backend, param_store) -> dict: calls _run_calibration() (subclass), updates param_store
  - Abstract methods: _run_check(backend, param_store), _run_calibration(backend, param_store)
- CalibrationDAG class:
  - nodes dict, param_store dict, sim_time float, calibration_log list
  - add_node(node), get_dependencies(node_name) -> list
  - maintain(target, backend) -> {n_checks, n_calibrations, n_diagnoses}: recursive, depth-first on deps
  - diagnose(node_name, backend) -> str: check_data on ancestors, calibrate if out_of_spec
  - cold_start(backend) -> {n_calibrated, n_failed, success_rate}: topological order
  - build_default_dag(n_qubits, coupling_map) -> CalibrationDAG: factory function

### Calibration nodes (each subclasses CalibrationNode)
- ResonatorSpectroscopyNode: uses backend.measure_frequency(). check: re-measure, compare to stored. calibrate: measure and store.
- QubitSpectroscopyNode: same pattern. Depends on resonator_spec.
- RabiAmplitudeNode: "calibrate" sweeps a parameter range to find optimal. In sim, use gate_fidelity_1q with different d_theta values. Depends on qubit_spec.
- RamseyNode: measures frequency offset. Depends on rabi.
- DRAGNode: sweeps beta param. Depends on ramsey.
- ReadoutNode: measures readout fidelity. Depends on qubit_spec.
- RBNode: measures gate error via gate_fidelity_1q. Depends on drag, readout.

### tests/test_dag.py — Must pass these:
1. test_cold_start: 10Q backend, cold_start(), assert success_rate > 0.95
2. test_maintenance_under_drift: 5Q, cold_start, then 96 steps of advance_time(0.25h) + maintain(), assert fidelity std < 0.005
3. test_diagnosis: 5Q, cold_start, inject T1 drop (set _T1_base=5), maintain(), assert recalibration triggered
4. test_tolerance_sweep: run with tight vs loose tolerances, tight should recalibrate more
5. test_timeout_sweep: run with short vs long timeouts, short should recalibrate more

### gap1_journal.md: document your implementation decisions
### gap1_prompts.md: copy this prompt verbatim

Run `pytest tests/test_dag.py -v` at the end and make sure all tests pass.
