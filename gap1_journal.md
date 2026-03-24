# Gap 1 — Calibration DAG Engine: Implementation Journal

## Design Decisions

### Node Architecture

Each calibration node subclasses `CalibrationNode`, which provides:
- **Metadata check** (`check_state`): fast path that avoids re-measuring by checking timeout expiry and whether dependencies have been recalibrated since the last calibration.
- **Data check** (`check_data`): calls the subclass `_run_check()` to actually re-measure and compare against stored tolerances.
- **Calibrate** (`calibrate`): calls the subclass `_run_calibration()`, stores results in `param_store`, and updates timestamps.

This two-tier check system (metadata then data) minimises unnecessary backend calls during maintenance loops.

### DAG Traversal

`maintain(target)` resolves all transitive dependencies via DFS (leaf-first order), then processes each node:
1. Fast `check_state` — if the node is within timeout and no deps changed, skip it.
2. `check_data` — re-measure and compare to tolerances.
3. If out-of-spec or uncalibrated, run `calibrate`.

`cold_start()` uses Kahn's algorithm for topological sort to ensure every dependency is calibrated before its dependents.

### Tolerance and Timeout Scaling

The `build_default_dag` factory accepts `tolerance_scale` and `timeout_scale` multipliers. These are applied at `add_node` time to every node's tolerance dict values and timeout_hours. This enables the sweep tests:
- `tolerance_scale < 1` = tighter tolerances = more recalibrations
- `timeout_scale < 1` = shorter timeouts = more recalibrations

### Node Dependency Graph (per qubit)

```
resonator_spec_q{i}
  └─ qubit_spec_q{i}
       ├─ rabi_q{i}
       │    └─ ramsey_q{i}
       │         └─ drag_q{i}
       └─ readout_q{i}
            (both drag + readout)
              └─ rb_q{i}
```

### Simulation-Specific Choices

- **ResonatorSpectroscopyNode** and **QubitSpectroscopyNode** both use `backend.measure_frequency()`. In real hardware these would be distinct experiments (resonator vs qubit spectroscopy), but the simulator provides a single frequency probe.
- **RabiAmplitudeNode** sweeps `d_theta` in `gate_fidelity_1q` to find the rotation-angle offset that maximises fidelity. The sweep range [-0.1, 0.1] with 21 points is fine-grained enough to find the optimum reliably.
- **DRAGNode** sweeps `d_beta` similarly, incorporating the already-calibrated `d_theta` from Rabi.
- **RamseyNode** measures frequency offset relative to the last qubit spectroscopy result.
- **ReadoutNode** uses `gate_fidelity_1q` as a proxy for readout assignment fidelity.
- **RBNode** computes gate error as `1 - gate_fidelity_1q(calib_params)`.

### Test Design

1. **test_cold_start**: 10Q linear topology; asserts > 95% success rate (all 70 nodes should calibrate).
2. **test_maintenance_under_drift**: 5Q, 96 steps of 15-minute drift; asserts fidelity standard deviation < 0.005, demonstrating the DAG keeps the system stable.
3. **test_diagnosis**: Injects a severe T1 drop (50+ us → 5 us) on qubit 0; verifies that the maintain loop detects degradation and triggers recalibration.
4. **test_tolerance_sweep**: Compares tight (0.2x) vs loose (5x) tolerances; tight must produce more recalibrations.
5. **test_timeout_sweep**: Compares short (0.2x) vs long (5x) timeouts; short must produce more recalibrations.
