# Gap 3: Snake Frequency Optimizer -- Design Journal

## Overview

Implements a snake-traversal frequency optimizer for a transmon qubit processor.
The optimizer assigns idle frequencies to each qubit to minimize aggregate cycle
error while avoiding frequency collisions.

## Architecture Decisions

### Error Model (error_model.py)

- **16-weight parameterization**: 4 contexts (direct, next-nearest, spectator,
  global) x 4 mechanisms (dephasing, relaxation, stray ZZ, pulse distortion).
  Initialized to ones so that the model is useful even before training.
- **NNLS training**: Non-negative least squares ensures weights stay physical.
  We build a design matrix from per-pair mechanism vectors and solve against
  measured XEB errors.
- **ZZ formula**: Uses the standard dispersive-regime expression
  `zz ~ 2*(alpha_i + alpha_j)*J^2 / ((delta+alpha_i)*(delta-alpha_j))` with a
  guard against near-zero denominators (collision regime).

### Collision Detection (collision.py)

- Five collision types checked per coupled pair:
  1. **resonant_swap**: `|f_i - f_j| < min_sep`
  2. **parasitic_cz_02**: `|f_i - (f_j + alpha_j)| < min_sep`
  3. **parasitic_cz_20**: `|f_j - (f_i + alpha_i)| < min_sep`
  4. **leakage_01_12**: `|f_i - f_j - alpha_j| < min_sep`
  5. **leakage_10_21**: `|f_j - f_i - alpha_i| < min_sep`
- Returns structured `Collision` dataclass objects for downstream use.

### Inner Loop Optimizers (inner_loop.py)

- **Grid search** for single-qubit problems (S=1): exhaustive, reliable.
- **Nelder-Mead** for small clusters (S<=3): scipy's implementation with
  penalty-based box constraints.
- **CMA-ES** for larger clusters (S>=4): uses the `cma` package with graceful
  fallback to Nelder-Mead if the package is unavailable.
- `select_optimizer(scope_S)` returns the appropriate callable.

### Snake Optimizer (snake.py)

- **Traversal**: BFS from the most-connected qubit. Each qubit is optimized
  exactly once, with its S-hop neighbourhood forming the sub-problem.
- **Objective**: error-model prediction + collision penalty (0.05 per collision).
- **Healing**: re-optimizes the neighbourhood of specified outlier qubits without
  touching the rest of the chip.
- **Bounds**: each qubit searches within `[f_max - 0.5 GHz, f_max]`, staying
  near the sweet spot to preserve coherence.

## Testing Strategy

Seven tests covering:
1. Non-negativity of all error mechanisms
2. Correlation (R^2 > 0.3) between model predictions and XEB measurements
3. Collision detection on a planted scenario
4. Snake optimizer reduces error vs. sweet-spot baseline on a 9-qubit grid
5. Grid search finds minimum of a 1-D quadratic
6. Nelder-Mead finds minimum of a 2-D quadratic
7. Healing reduces error after artificially degrading a qubit

## Open Questions / Future Work

- Training the error model on real XEB data to improve R^2.
- Extending collision checks to non-nearest-neighbour pairs (crosstalk).
- Parallelizing independent sub-problems in the snake traversal.
- Adaptive scope_S based on local error landscape curvature.
