"""Snake frequency optimizer for transmon processor calibration.

Traverses the processor's qubit graph in a snake-like order, optimising
each qubit's idle frequency while holding previously-calibrated neighbours
fixed.  This mirrors the "snake optimizer" strategy used in Google's
Sycamore frequency-allocation workflow.
"""

from __future__ import annotations

from collections import deque
from typing import TYPE_CHECKING

import numpy as np

from .collision import check_collisions
from .error_model import ErrorModel
from .inner_loop import (
    cmaes_optimize,
    grid_search_1d,
    nelder_mead_optimize,
    select_optimizer,
)

if TYPE_CHECKING:
    from src.simulator.processor import ProcessorModel


class SnakeOptimizer:
    """Greedy snake-traversal frequency optimiser.

    Parameters
    ----------
    processor : ProcessorModel
        The processor to optimise.
    error_model : ErrorModel
        Analytical error model used as the objective function.
    scope_S : int
        Neighbourhood radius (hops) used when building each sub-problem.
        * S = 1  -->  optimise one qubit at a time  (grid search)
        * S = 2  -->  optimise qubit + nearest neighbours (Nelder-Mead)
        * S >= 4 -->  larger cluster (CMA-ES)
    """

    def __init__(self, processor: "ProcessorModel", error_model: ErrorModel,
                 scope_S: int = 2):
        self.processor = processor
        self.error_model = error_model
        self.scope_S = scope_S

        # Build adjacency list from coupling map
        self._adj: dict[int, list[int]] = {i: [] for i in range(processor.n_qubits)}
        for qi, qj in processor.coupling_map:
            self._adj[qi].append(qj)
            self._adj[qj].append(qi)

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def optimize(self) -> dict[int, float]:
        """Run the snake optimiser and return the best frequency config.

        Returns
        -------
        dict[int, float]
            Mapping qubit index -> optimised frequency (GHz).
        """
        freq_config = self._initial_config()
        calibrated: set[int] = set()

        # Start from the qubit with the most connections (heuristic)
        start = max(range(self.processor.n_qubits),
                    key=lambda i: len(self._adj[i]))
        self._traverse(start, freq_config, calibrated)

        return freq_config

    def heal(self, freq_config: dict[int, float],
             outlier_qubits: list[int]) -> dict[int, float]:
        """Re-optimise the neighbourhood around outlier qubits.

        Parameters
        ----------
        freq_config : dict[int, float]
            Current frequency allocation.
        outlier_qubits : list[int]
            Qubits whose error is unacceptably high.

        Returns
        -------
        dict[int, float]
            Updated frequency config.
        """
        new_config = dict(freq_config)  # copy

        for q in outlier_qubits:
            neighbourhood = self._get_neighborhood(q, self.scope_S)
            self._optimize_local(neighbourhood, new_config)

        return new_config

    # ------------------------------------------------------------------
    # Internals
    # ------------------------------------------------------------------

    def _initial_config(self) -> dict[int, float]:
        """Start every qubit at its sweet-spot frequency (f_max)."""
        return {i: self.processor.qubits[i].f_max
                for i in range(self.processor.n_qubits)}

    def _get_neighborhood(self, node: int, S: int) -> list[int]:
        """Return qubit indices within *S* hops of *node* (BFS)."""
        visited: set[int] = {node}
        queue: deque[tuple[int, int]] = deque([(node, 0)])
        result: list[int] = [node]

        while queue:
            current, depth = queue.popleft()
            if depth >= S:
                continue
            for nb in self._adj[current]:
                if nb not in visited:
                    visited.add(nb)
                    result.append(nb)
                    queue.append((nb, depth + 1))

        return result

    def _traverse(self, node: int, freq_config: dict[int, float],
                  calibrated: set[int]) -> None:
        """Recursively traverse the graph, optimising each qubit once."""
        if node in calibrated:
            return
        calibrated.add(node)

        # Build the local sub-problem
        neighbourhood = self._get_neighborhood(node, self.scope_S)
        self._optimize_local(neighbourhood, freq_config)

        # Recurse into uncalibrated neighbours (BFS order)
        for nb in self._adj[node]:
            self._traverse(nb, freq_config, calibrated)

    def _optimize_local(self, qubit_indices: list[int],
                        freq_config: dict[int, float]) -> None:
        """Optimise the frequencies of *qubit_indices* jointly."""
        proc = self.processor
        em = self.error_model
        n_local = len(qubit_indices)

        # Build bounds: each qubit can move within [f_max - 0.5, f_max]
        bounds = []
        for qi in qubit_indices:
            f_max = proc.qubits[qi].f_max
            bounds.append((f_max - 0.5, f_max))

        anharmonicities = {i: proc.qubits[i].alpha
                           for i in range(proc.n_qubits)}

        # Objective: error model prediction + collision penalty
        def objective_nd(x: np.ndarray) -> float:
            trial = dict(freq_config)
            for k, qi in enumerate(qubit_indices):
                trial[qi] = float(x[k])

            err = em.predict_cycle_error(trial, proc)

            # Collision penalty
            collisions = check_collisions(
                trial, proc.coupling_map, anharmonicities, min_sep=0.017,
            )
            err += 0.05 * len(collisions)
            return err

        def objective_1d(x: float) -> float:
            return objective_nd(np.array([x]))

        x0 = np.array([freq_config[qi] for qi in qubit_indices])

        optimizer = select_optimizer(n_local)

        if n_local == 1:
            best_x = optimizer(objective_1d, bounds[0], n_points=100)
            freq_config[qubit_indices[0]] = best_x
        else:
            best_x = optimizer(objective_nd, x0, bounds=bounds)
            for k, qi in enumerate(qubit_indices):
                freq_config[qi] = float(best_x[k])
