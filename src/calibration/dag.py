"""Calibration DAG engine: dependency-aware calibration management.

Provides the core CalibrationNode base class and CalibrationDAG orchestrator.
"""

from __future__ import annotations

import time as _wallclock
from abc import ABC, abstractmethod
from enum import Enum, auto
from collections import deque
from typing import Any

from .tolerances import get_tolerance, get_timeout


class NodeStatus(Enum):
    """Status of a calibration node after a data check."""
    IN_SPEC = auto()
    OUT_OF_SPEC = auto()
    BAD_DATA = auto()
    UNCALIBRATED = auto()


class CalibrationNode(ABC):
    """Base class for a single calibration step in the DAG.

    Parameters
    ----------
    name : str
        Unique identifier, typically ``"<node_type>_q{qubit}"``.
    node_type : str
        Category key used to look up default tolerances/timeouts.
    qubit : int
        Target qubit index.
    tolerance : dict | None
        Override tolerance dict (merged with defaults).
    timeout_hours : float | None
        Override timeout in hours.
    dependencies : list[str] | None
        Names of nodes that must be calibrated first.
    """

    def __init__(
        self,
        name: str,
        node_type: str,
        qubit: int,
        tolerance: dict | None = None,
        timeout_hours: float | None = None,
        dependencies: list[str] | None = None,
    ):
        self.name = name
        self.node_type = node_type
        self.qubit = qubit
        self.tolerance = get_tolerance(node_type, tolerance)
        self.timeout_hours = get_timeout(node_type, timeout_hours)
        self.dependencies = list(dependencies or [])

        self.last_result: dict[str, Any] = {}
        self.last_check_time: float | None = None
        self.last_calibration_time: float | None = None
        self.status: NodeStatus = NodeStatus.UNCALIBRATED

    # ------------------------------------------------------------------
    # Public interface
    # ------------------------------------------------------------------

    def check_state(self, param_store: dict, current_time: float) -> bool:
        """Fast metadata check: within timeout and no dependency invalidation.

        Returns True if node is *presumed* in-spec without re-measuring.
        """
        if self.status == NodeStatus.UNCALIBRATED:
            return False
        if self.last_calibration_time is None:
            return False
        # Timeout check
        if current_time - self.last_calibration_time > self.timeout_hours:
            return False
        # Check if any dependency was recalibrated *after* this node
        for dep_name in self.dependencies:
            dep_cal_time = param_store.get(f"_cal_time_{dep_name}")
            if dep_cal_time is not None and dep_cal_time > self.last_calibration_time:
                return False
        return True

    def check_data(self, backend, param_store: dict) -> NodeStatus:
        """Re-measure and compare to stored calibration; update status."""
        try:
            result = self._run_check(backend, param_store)
        except Exception:
            self.status = NodeStatus.BAD_DATA
            return self.status

        if result is None:
            self.status = NodeStatus.UNCALIBRATED
            return self.status

        # Compare each checked parameter against tolerance
        for key, value in result.items():
            tol = self.tolerance.get(key)
            stored = param_store.get(f"{self.name}_{key}")
            if tol is None or stored is None:
                continue
            if abs(value - stored) > tol:
                self.status = NodeStatus.OUT_OF_SPEC
                return self.status

        self.status = NodeStatus.IN_SPEC
        return self.status

    def calibrate(self, backend, param_store: dict, current_time: float) -> dict:
        """Run full calibration, store results, return calibrated params."""
        result = self._run_calibration(backend, param_store)
        # Update param store
        for key, value in result.items():
            param_store[f"{self.name}_{key}"] = value
        param_store[f"_cal_time_{self.name}"] = current_time
        self.last_result = dict(result)
        self.last_calibration_time = current_time
        self.last_check_time = current_time
        self.status = NodeStatus.IN_SPEC
        return result

    # ------------------------------------------------------------------
    # Abstract interface for subclasses
    # ------------------------------------------------------------------

    @abstractmethod
    def _run_check(self, backend, param_store: dict) -> dict | None:
        """Quick measurement to verify current calibration.

        Returns dict of measured parameter values, or None if not yet calibrated.
        """

    @abstractmethod
    def _run_calibration(self, backend, param_store: dict) -> dict:
        """Full calibration procedure.

        Returns dict of calibrated parameter values.
        """


class CalibrationDAG:
    """Manages a directed acyclic graph of CalibrationNode instances.

    Parameters
    ----------
    tolerance_scale : float
        Multiplicative factor applied to all node tolerances (>1 = looser).
    timeout_scale : float
        Multiplicative factor applied to all node timeouts (>1 = longer).
    """

    def __init__(self, tolerance_scale: float = 1.0, timeout_scale: float = 1.0):
        self.nodes: dict[str, CalibrationNode] = {}
        self.param_store: dict[str, Any] = {}
        self.sim_time: float = 0.0
        self.calibration_log: list[dict] = []
        self.tolerance_scale = tolerance_scale
        self.timeout_scale = timeout_scale

    def add_node(self, node: CalibrationNode) -> None:
        """Register a calibration node (applies scale factors)."""
        # Apply scale factors
        for key in node.tolerance:
            node.tolerance[key] *= self.tolerance_scale
        node.timeout_hours *= self.timeout_scale
        self.nodes[node.name] = node

    def get_dependencies(self, node_name: str) -> list[str]:
        """Return transitive dependency list in topological (leaf-first) order."""
        visited: set[str] = set()
        order: list[str] = []

        def _dfs(name: str):
            if name in visited:
                return
            visited.add(name)
            node = self.nodes.get(name)
            if node is None:
                return
            for dep in node.dependencies:
                _dfs(dep)
            order.append(name)

        _dfs(node_name)
        return order

    def maintain(self, target: str, backend) -> dict:
        """Maintain a target node: ensure it and all deps are in-spec.

        Uses depth-first traversal.  Returns summary dict.
        """
        n_checks = 0
        n_calibrations = 0
        n_diagnoses = 0

        dep_order = self.get_dependencies(target)  # leaf-first

        for name in dep_order:
            node = self.nodes[name]
            # Fast metadata check first
            if node.check_state(self.param_store, self.sim_time):
                n_checks += 1
                continue

            # Need a data check
            status = node.check_data(backend, self.param_store)
            n_checks += 1

            if status == NodeStatus.IN_SPEC:
                # Update check time but don't recalibrate
                node.last_check_time = self.sim_time
                continue

            if status in (NodeStatus.OUT_OF_SPEC, NodeStatus.UNCALIBRATED, NodeStatus.BAD_DATA):
                # Calibrate
                node.calibrate(backend, self.param_store, self.sim_time)
                n_calibrations += 1
                self.calibration_log.append({
                    "time": self.sim_time,
                    "node": name,
                    "reason": status.name,
                })

        return {
            "n_checks": n_checks,
            "n_calibrations": n_calibrations,
            "n_diagnoses": n_diagnoses,
        }

    def diagnose(self, node_name: str, backend) -> str:
        """Check ancestors of a problem node, recalibrate any out-of-spec.

        Returns diagnostic summary string.
        """
        dep_order = self.get_dependencies(node_name)
        messages: list[str] = []

        for name in dep_order:
            node = self.nodes[name]
            status = node.check_data(backend, self.param_store)
            if status == NodeStatus.OUT_OF_SPEC:
                node.calibrate(backend, self.param_store, self.sim_time)
                messages.append(f"{name}: OUT_OF_SPEC -> recalibrated")
                self.calibration_log.append({
                    "time": self.sim_time,
                    "node": name,
                    "reason": "diagnose:OUT_OF_SPEC",
                })
            elif status == NodeStatus.BAD_DATA:
                node.calibrate(backend, self.param_store, self.sim_time)
                messages.append(f"{name}: BAD_DATA -> recalibrated")
                self.calibration_log.append({
                    "time": self.sim_time,
                    "node": name,
                    "reason": "diagnose:BAD_DATA",
                })
            elif status == NodeStatus.UNCALIBRATED:
                node.calibrate(backend, self.param_store, self.sim_time)
                messages.append(f"{name}: UNCALIBRATED -> calibrated")
            else:
                messages.append(f"{name}: IN_SPEC")

        return "\n".join(messages)

    def cold_start(self, backend) -> dict:
        """Calibrate every node from scratch in topological order.

        Returns summary dict with n_calibrated, n_failed, success_rate.
        """
        order = self._topological_sort()
        n_calibrated = 0
        n_failed = 0

        for name in order:
            node = self.nodes[name]
            try:
                node.calibrate(backend, self.param_store, self.sim_time)
                n_calibrated += 1
                self.calibration_log.append({
                    "time": self.sim_time,
                    "node": name,
                    "reason": "cold_start",
                })
            except Exception:
                n_failed += 1

        total = n_calibrated + n_failed
        return {
            "n_calibrated": n_calibrated,
            "n_failed": n_failed,
            "success_rate": n_calibrated / total if total > 0 else 0.0,
        }

    def _topological_sort(self) -> list[str]:
        """Kahn's algorithm for topological ordering."""
        in_degree: dict[str, int] = {name: 0 for name in self.nodes}
        for name, node in self.nodes.items():
            for dep in node.dependencies:
                if dep in self.nodes:
                    in_degree[name] += 1  # this node depends on dep

        queue = deque(name for name, deg in in_degree.items() if deg == 0)
        order: list[str] = []

        while queue:
            current = queue.popleft()
            order.append(current)
            # Find nodes that depend on current
            for name, node in self.nodes.items():
                if current in node.dependencies:
                    in_degree[name] -= 1
                    if in_degree[name] == 0:
                        queue.append(name)

        return order


def build_default_dag(
    n_qubits: int,
    coupling_map: list[tuple[int, int]],
    tolerance_scale: float = 1.0,
    timeout_scale: float = 1.0,
) -> CalibrationDAG:
    """Factory: construct a fully-wired CalibrationDAG for a given chip layout.

    Node graph per qubit::

        resonator_spec_q{i}
            -> qubit_spec_q{i}
                -> rabi_q{i}
                    -> ramsey_q{i}
                        -> drag_q{i}
                -> readout_q{i}
            -> rb_q{i} (depends on drag + readout)
    """
    from .nodes.spectroscopy import ResonatorSpectroscopyNode, QubitSpectroscopyNode
    from .nodes.rabi import RabiAmplitudeNode
    from .nodes.ramsey import RamseyNode
    from .nodes.drag import DRAGNode
    from .nodes.readout import ReadoutNode
    from .nodes.benchmarking import RBNode

    dag = CalibrationDAG(tolerance_scale=tolerance_scale, timeout_scale=timeout_scale)

    for q in range(n_qubits):
        res_name = f"resonator_spec_q{q}"
        qs_name = f"qubit_spec_q{q}"
        rabi_name = f"rabi_q{q}"
        ramsey_name = f"ramsey_q{q}"
        drag_name = f"drag_q{q}"
        readout_name = f"readout_q{q}"
        rb_name = f"rb_q{q}"

        dag.add_node(ResonatorSpectroscopyNode(
            name=res_name, qubit=q, dependencies=[],
        ))
        dag.add_node(QubitSpectroscopyNode(
            name=qs_name, qubit=q, dependencies=[res_name],
        ))
        dag.add_node(RabiAmplitudeNode(
            name=rabi_name, qubit=q, dependencies=[qs_name],
        ))
        dag.add_node(RamseyNode(
            name=ramsey_name, qubit=q, dependencies=[rabi_name],
        ))
        dag.add_node(DRAGNode(
            name=drag_name, qubit=q, dependencies=[ramsey_name],
        ))
        dag.add_node(ReadoutNode(
            name=readout_name, qubit=q, dependencies=[qs_name],
        ))
        dag.add_node(RBNode(
            name=rb_name, qubit=q, dependencies=[drag_name, readout_name],
        ))

    return dag
