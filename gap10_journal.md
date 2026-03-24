# Gap 10: Electronics Noise Budget -- Design Journal

## Goal

Build a quantitative noise budget that decomposes single-qubit and two-qubit
gate errors into contributions from each electronics noise source, allowing
platform comparison and confirming that decoherence (T1/T2) remains the
dominant error mechanism for state-of-the-art control hardware.

## Key Design Decisions

### 1. ElectronicsProfile as a frozen dataclass

Profiles are immutable value objects so they can be shared safely across
threads and used as dict keys.  Every field maps to a single datasheet number,
making it easy for users to add their own platform.

### 2. Error channel decomposition

Each noise mechanism gets its own method returning a scalar error probability.
This makes the budget transparent: callers can see exactly which channel
dominates for a given profile.

| Channel             | Formula basis                                |
|---------------------|----------------------------------------------|
| DAC quantization    | SQNR = 6.02*bits + 1.76; error = 1/snr^2    |
| Amplitude noise     | noise_floor * BW / signal_power              |
| Phase noise         | L(f) * 1e6 * gate_time (integrated dephasing)|
| Timing jitter       | (2*pi*f*sigma_t)^2 / 2                       |
| Thermal photons     | n_bar * 0.1 (photon-induced dephasing)       |

### 3. Two-qubit error as 2x single-qubit

A CZ-type gate involves driving both qubits, so each electronics channel
contributes roughly twice.  This is a first-order approximation; the actual
ratio depends on gate topology (e.g., cross-resonance vs. tunable coupler).

### 4. Coherence-limited comparison via ProcessorModel

The benchmark imports ProcessorModel to compute a coherence-limited gate error
from the same qubit parameters the rest of the simulator uses, ensuring
consistency.  For typical transmon T1 ~ 50-80 us and a 25 ns gate,
coherence-limited error is ~ 2-5e-4, which comfortably exceeds the electronics
contribution of even the QICK FPGA platform.

### 5. Profile data sources

- Zurich SHFQC+: Zurich Instruments datasheet (2024), SHFQC+ specifications
- QM OPX1000: Quantum Machines OPX1000 product brief (2024)
- Qblox Cluster: Qblox product documentation, Cluster QRM/QCM specs
- Keysight QCS: Keysight M5xxx / PXIe quantum control system specs
- QICK ZCU216: Open-source QICK project, Xilinx ZCU216 RFSoC datasheet

Cost ranges are approximate list prices for a minimal multi-qubit-capable
configuration as of late 2024 / early 2025.

## Validation

All six unit tests pass, confirming:
- Model construction and plausibility of error magnitudes
- Monotonicity (worse specs -> higher error)
- Decoherence dominance over best-in-class electronics
- Correct platform ranking (OPX1000 < QICK)
- Benchmark harness produces expected output structure
