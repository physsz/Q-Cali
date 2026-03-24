# Gap 3 Prompts

## Original Prompt

You are implementing Gap 3 (Snake Frequency Optimizer) for the Q-Cali project. Working directory: E:\Projects\Q-Cali

### YOUR FILES (only touch these)
- src/optimizer/error_model.py (CREATE)
- src/optimizer/collision.py (CREATE)
- src/optimizer/inner_loop.py (CREATE)
- src/optimizer/snake.py (CREATE)
- tests/test_snake.py (CREATE)
- gap3_journal.md (CREATE)
- gap3_prompts.md (CREATE)

DO NOT modify any existing files.

### Existing API (DO NOT MODIFY)

`src/simulator/processor.py` — ProcessorModel:
- .n_qubits, .coupling_map (list of (i,j) tuples), .couplings (dict: (i,j)->J in GHz)
- .qubits[i].frequency() -> GHz, .qubits[i].alpha -> GHz (~-0.2), .qubits[i].f_max -> GHz
- .qubits[i].flux_sensitivity() -> GHz/Phi0, .qubits[i].T1 -> us, .qubits[i]._T1_base -> us
- .measure_T1(qubit_idx, frequency=None, n_shots=1000) -> float
- .gate_fidelity_1q(qubit_idx, calib_params=None) -> float
- .gate_fidelity_2q(q1, q2, calib_params=None) -> float
- .run_xeb(qubit_pair, n_cycles=20, n_circuits=50) -> float (cycle error)

`src/simulator/backend.py` — SimulatedBackend wraps ProcessorModel

### Implementation

#### error_model.py (~200 lines)
ErrorModel class with:
- 16 weights (4 contexts x 4 mechanisms), initially ones
- dephasing_error(freq, flux_sens, flux_noise=3e-6) -> float
- relaxation_error(freq, T1) -> float
- stray_coupling_error(f_i, f_j, J, alpha_i, alpha_j, t_gate=42e-3) -> float: ZZ formula
- pulse_distortion_error(idle_f, interaction_f, coeff=0.001) -> float
- predict_cycle_error(freq_config: dict[int,float], processor) -> float: sum over all pairs
- train_weights(configs: list[dict], measured_errors: list[float], processor): scipy.optimize.nnls

#### collision.py (~80 lines)
- check_collisions(freq_config, coupling_map, anharmonicities, min_sep=0.02) -> list
- Five collision types: resonant_swap, parasitic_cz_02, parasitic_cz_20, leakage_01_12, leakage_10_21

#### inner_loop.py (~120 lines)
- grid_search_1d(objective, bounds, n_points=100) -> best_x
- nelder_mead_optimize(objective, x0, bounds=None) -> best_x (scipy.optimize.minimize)
- cmaes_optimize(objective, x0, sigma0=0.05) -> best_x (try import cma; fallback to NM)
- select_optimizer(scope_S) -> callable: S=1->grid, S<=3->NM, S>=4->CMA-ES

#### snake.py (~200 lines)
SnakeOptimizer class:
- __init__(processor, error_model, scope_S=2)
- optimize() -> dict[int, float]: freq_config mapping qubit->freq
  - _initial_config(): start at sweet spots (f_max for each qubit)
  - _get_neighborhood(node, S) -> list of qubit indices within S hops
  - _traverse(node, freq_config, calibrated): optimize local, mark done, recurse to neighbors
- heal(freq_config, outlier_qubits) -> dict: re-optimize only around outliers

#### tests/test_snake.py — Must pass:
1. test_error_model_basic: ErrorModel computes non-negative errors
2. test_error_model_correlation: predicted errors correlate with measured (R^2>0.3 is ok for simple model)
3. test_collision_detection: detects planted collision (two qubits at same freq)
4. test_snake_reduces_error: optimize() reduces cycle error vs baseline on 9-qubit grid
5. test_inner_loop_grid: grid search finds minimum of simple 1D function
6. test_inner_loop_nm: Nelder-Mead finds minimum of 2D function
7. test_healing: healing reduces outlier errors

#### gap3_journal.md: document decisions
#### gap3_prompts.md: copy this prompt

Run `pytest tests/test_snake.py -v` at the end.
