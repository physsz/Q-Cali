# Q-Cali

**Superconducting qubit calibration framework** — an open-source effort to reproduce and extend the calibration stack used by Google Quantum AI on their Sycamore and Willow processors.

## Motivation

Calibration of superconducting transmon qubits is the rate-limiting step in scaling quantum processors toward fault-tolerant operation. Google's calibration stack (Optimus + Snake) is the most complete published system, but critical implementation details remain undisclosed. This project bridges the four critical reproduction gaps identified in our survey:

| Gap | Description | Status |
|-----|------------|--------|
| 1 | Optimus calibration DAG (52-node reconstruction) | In progress |
| 3 | Snake frequency optimizer (error model + inner loop) | In progress |
| 5 | TLS forecasting (6 proposed algorithms) | In progress |
| 10 | Control electronics stack | Benchmarked |

## Architecture

```
src/
├── simulator/          # Digital twin of a transmon processor
│   ├── transmon.py     # Single qubit model (frequency, coherence, drift)
│   ├── tls.py          # TLS defect landscape with spectral diffusion
│   ├── processor.py    # Multi-qubit processor with noise + drift
│   └── backend.py      # SimulatedBackend (same API as hardware)
├── calibration/        # DAG-based calibration framework
│   ├── dag.py          # DAG engine (maintain, diagnose, check_state)
│   └── nodes/          # Individual calibration procedures
├── optimizer/          # Snake-like frequency optimizer
│   ├── snake.py        # Graph traversal outer loop
│   ├── error_model.py  # 4-component error estimator (16 weights)
│   └── inner_loop.py   # NM / CMA-ES / grid search
├── tls_forecast/       # TLS prediction algorithms
│   ├── changepoint.py  # Change-point detection + extrapolation
│   ├── particle_filter.py
│   ├── hmm.py
│   └── gp_forecast.py
└── backend/            # Hardware abstraction
    ├── base.py         # ProcessorBackend ABC
    └── hardware.py     # Real hardware adapter
```

Key design principle: calibration algorithms import `ProcessorBackend` and run identically on `SimulatedBackend` (fast iteration) or `RealBackend` (hardware validation).

## Documents

The `docs/` directory contains three survey/design documents:

- **`survey.pdf`** — SOTA survey on superconducting qubit calibration (21 pages, 38 references)
- **`gap_solutions.pdf`** — Proposed solutions for the 4 critical reproduction gaps (19 pages)
- **`testbed.pdf`** — Simulation + experimental testbed design (16 pages)

## Quick Start

```bash
# Install
pip install -e ".[dev]"

# Run tests
pytest tests/

# Run a basic simulation
python -c "
from src.simulator.backend import SimulatedBackend
backend = SimulatedBackend(n_qubits=5, seed=42)
for q in range(5):
    t1 = backend.measure_T1(q)
    f = backend.measure_frequency(q)
    print(f'Q{q}: f={f:.3f} GHz, T1={t1:.1f} us')
"
```

## Dependencies

- Python >= 3.10
- NumPy, SciPy
- QuTiP >= 5.0 (master equation solver)
- scqubits >= 4.0 (transmon spectrum)
- CMA (CMA-ES optimizer)
- matplotlib (visualization)

## References

Key papers this project builds on:

- Kelly *et al.*, "Physical qubit calibration on a directed acyclic graph," [arXiv:1803.03226](https://arxiv.org/abs/1803.03226) (2018)
- Klimov *et al.*, "Optimizing quantum gates towards the scale of logical qubits," [Nature Comm. **15**, 2442](https://doi.org/10.1038/s41467-024-46623-y) (2024)
- Google Quantum AI, "Quantum error correction below the surface code threshold," [Nature (2024)](https://doi.org/10.1038/s41586-024-08449-y)
- Berritta *et al.*, "Real-time adaptive tracking of fluctuating relaxation rates," [arXiv:2506.09576](https://arxiv.org/abs/2506.09576) (2026)

## License

MIT
