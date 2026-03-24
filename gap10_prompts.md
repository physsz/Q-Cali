# Gap 10: Electronics Noise Budget -- Prompt

You are implementing Gap 10 (Electronics Noise Budget) for the Q-Cali project. Working directory: E:\Projects\Q-Cali

## YOUR FILES (only touch these)
- src/simulator/noise.py (CREATE)
- benchmarks/noise_budget.py (CREATE)
- tests/test_noise.py (CREATE)
- gap10_journal.md (CREATE)
- gap10_prompts.md (CREATE)

DO NOT modify any existing files.

## Existing API (DO NOT MODIFY)

`src/simulator/processor.py` — ProcessorModel:
- .qubits[i].T1 -> us, .qubits[i].T2 -> us, .qubits[i].frequency() -> GHz

## Implementation

### noise.py (~200 lines)

ElectronicsProfile dataclass: name, dac_bits, dac_sample_rate_gsps, phase_noise_dBcHz_10kHz, output_noise_dBmHz, timing_jitter_ps, feedback_latency_ns, cost_usd

Pre-configured profiles:
- ZURICH_SHFQC_PLUS: 14-bit, 2 GSa/s, -110 dBc/Hz, -143 dBm/Hz, 1.0 ps, 350 ns, "$150-300k"
- QM_OPX1000: 16-bit, 2 GSa/s, -125 dBc/Hz, -140 dBm/Hz, 0.15 ps, 160 ns, "$200-500k"
- QBLOX_CLUSTER: 16-bit, 1 GSa/s, -115 dBc/Hz, -135 dBm/Hz, 1.0 ps, 364 ns, "$100-250k"
- KEYSIGHT_QCS: 12-bit, 11 GSa/s, -110 dBc/Hz, -135 dBm/Hz, 1.0 ps, 500 ns, "$100-200k"
- QICK_ZCU216: 14-bit, 9.85 GSa/s, -70 dBc/Hz, -120 dBm/Hz, 5.0 ps, 1000 ns, "$30-50k"
- ALL_PROFILES = [all five]

ElectronicsNoiseModel(profile):
- dac_quantization_error(gate_time_ns=25): SQNR = 6.02*bits + 1.76, error = 1/snr²
- dac_amplitude_noise_error(): noise_power * bandwidth / signal_power
- phase_noise_error(qubit_freq_ghz=5.0, gate_time_ns=25): 10^(PN/10) * 1e6 * gate_time_s
- timing_jitter_error(qubit_freq_ghz=5.0): (2π * f * jitter)² / 2
- thermal_photon_error(n_bar=1e-3): n_bar * 0.1
- total_1q_gate_error(): sum of all above
- total_2q_gate_error(): ~2× total_1q

### benchmarks/noise_budget.py (~100 lines)
- compare_platforms() -> dict: compute all error components for each platform
- Print a formatted comparison table
- Compute coherence-limited error from ProcessorModel for comparison
- Print conclusion: "decoherence dominates" if coherence_error > max(electronics_error)

### tests/test_noise.py — Must pass:
1. test_noise_model_creates: ElectronicsNoiseModel(QM_OPX1000) works, error > 0 and < 0.01
2. test_all_profiles: all 5 profiles produce valid errors in (0, 0.1)
3. test_higher_noise_higher_error: 8-bit/-70dBc profile has higher error than 16-bit/-130dBc
4. test_decoherence_dominates: coherence error > OPX1000 electronics error
5. test_platform_ranking: OPX1000 error < QICK error
6. test_benchmark_runs: compare_platforms() returns 5 entries with "1q_error" key

### gap10_journal.md: document decisions
### gap10_prompts.md: copy this prompt

Run `pytest tests/test_noise.py -v` and `python benchmarks/noise_budget.py` at the end.
