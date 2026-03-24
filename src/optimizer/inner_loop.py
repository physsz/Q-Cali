"""Inner-loop optimizers used by the snake frequency optimizer.

Provides three optimizers of increasing sophistication and a selector
that picks the appropriate one based on the scope (number of qubits
being optimized simultaneously).
"""

from __future__ import annotations

from typing import Callable

import numpy as np
from scipy.optimize import minimize as sp_minimize


# ---------------------------------------------------------------------------
# 1-D grid search
# ---------------------------------------------------------------------------

def grid_search_1d(
    objective: Callable[[float], float],
    bounds: tuple[float, float],
    n_points: int = 100,
) -> float:
    """Exhaustive 1-D grid search.

    Parameters
    ----------
    objective : callable  (float -> float)
        Function to minimise.
    bounds : (lo, hi)
        Search interval.
    n_points : int
        Number of grid points.

    Returns
    -------
    float
        The x value that minimises *objective* on the grid.
    """
    xs = np.linspace(bounds[0], bounds[1], n_points)
    ys = np.array([objective(x) for x in xs])
    return float(xs[np.argmin(ys)])


# ---------------------------------------------------------------------------
# Nelder-Mead (bounded via penalty)
# ---------------------------------------------------------------------------

def nelder_mead_optimize(
    objective: Callable[[np.ndarray], float],
    x0: np.ndarray,
    bounds: list[tuple[float, float]] | None = None,
    maxiter: int = 500,
) -> np.ndarray:
    """Nelder-Mead simplex optimisation with optional box constraints.

    Bounds are enforced by adding a large penalty when a trial point
    leaves the feasible region.

    Parameters
    ----------
    objective : callable  (ndarray -> float)
        Function to minimise.
    x0 : ndarray
        Starting point.
    bounds : list of (lo, hi) or None
        Box constraints per dimension.
    maxiter : int
        Maximum iterations.

    Returns
    -------
    ndarray
        Best point found.
    """
    x0 = np.asarray(x0, dtype=float)

    if bounds is not None:
        lo = np.array([b[0] for b in bounds])
        hi = np.array([b[1] for b in bounds])

        def penalised(x):
            if np.any(x < lo) or np.any(x > hi):
                return 1e12
            return objective(x)

        fun = penalised
    else:
        fun = objective

    res = sp_minimize(fun, x0, method="Nelder-Mead",
                      options={"maxiter": maxiter, "xatol": 1e-6, "fatol": 1e-8})
    return res.x


# ---------------------------------------------------------------------------
# CMA-ES (with fallback)
# ---------------------------------------------------------------------------

def cmaes_optimize(
    objective: Callable[[np.ndarray], float],
    x0: np.ndarray,
    sigma0: float = 0.05,
    bounds: list[tuple[float, float]] | None = None,
    maxiter: int = 300,
) -> np.ndarray:
    """CMA-ES optimisation with graceful fallback to Nelder-Mead.

    Parameters
    ----------
    objective : callable  (ndarray -> float)
        Function to minimise.
    x0 : ndarray
        Starting point.
    sigma0 : float
        Initial step-size.
    bounds : list of (lo, hi) or None
        Box constraints.
    maxiter : int
        Maximum number of CMA-ES iterations.

    Returns
    -------
    ndarray
        Best point found.
    """
    x0 = np.asarray(x0, dtype=float)
    try:
        import cma  # noqa: F811

        opts: dict = {"maxiter": maxiter, "verbose": -9}
        if bounds is not None:
            lo = [b[0] for b in bounds]
            hi = [b[1] for b in bounds]
            opts["bounds"] = [lo, hi]

        es = cma.CMAEvolutionStrategy(x0.tolist(), sigma0, opts)
        es.optimize(objective)
        return np.asarray(es.result.xbest)

    except ImportError:
        # Fall back to Nelder-Mead
        return nelder_mead_optimize(objective, x0, bounds=bounds, maxiter=maxiter)


# ---------------------------------------------------------------------------
# Selector
# ---------------------------------------------------------------------------

def select_optimizer(scope_S: int) -> Callable:
    """Pick an optimiser based on the neighbourhood scope.

    Parameters
    ----------
    scope_S : int
        Number of qubits in the local sub-problem.

    Returns
    -------
    callable
        One of ``grid_search_1d``, ``nelder_mead_optimize``,
        or ``cmaes_optimize``.
    """
    if scope_S == 1:
        return grid_search_1d
    elif scope_S <= 3:
        return nelder_mead_optimize
    else:
        return cmaes_optimize
