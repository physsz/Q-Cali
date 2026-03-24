"""Frequency-collision detection for transmon qubits.

Checks a proposed frequency configuration against five standard collision
types that arise in fixed-frequency / flux-tunable transmon architectures.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class Collision:
    """A detected frequency collision."""

    kind: str          # collision type identifier
    qubits: tuple      # involved qubit indices
    delta_ghz: float   # separation that triggers the collision
    description: str   # human-readable explanation


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def check_collisions(
    freq_config: dict[int, float],
    coupling_map: list[tuple[int, int]],
    anharmonicities: dict[int, float],
    min_sep: float = 0.02,
) -> list[Collision]:
    """Return a list of frequency collisions for a configuration.

    Parameters
    ----------
    freq_config : dict[int, float]
        Mapping qubit index -> operating frequency (GHz).
    coupling_map : list of (int, int)
        Pairs of coupled qubits.
    anharmonicities : dict[int, float]
        Mapping qubit index -> anharmonicity (GHz).  Typically ~ -0.2 GHz.
    min_sep : float
        Minimum acceptable separation (GHz) for each collision condition.

    Returns
    -------
    list[Collision]
        Detected collisions (may be empty).
    """
    collisions: list[Collision] = []

    for qi, qj in coupling_map:
        fi = freq_config.get(qi)
        fj = freq_config.get(qj)
        if fi is None or fj is None:
            continue

        ai = anharmonicities.get(qi, -0.2)
        aj = anharmonicities.get(qj, -0.2)

        # 1. Resonant swap: |fi - fj| < min_sep
        delta = abs(fi - fj)
        if delta < min_sep:
            collisions.append(Collision(
                kind="resonant_swap",
                qubits=(qi, qj),
                delta_ghz=delta,
                description=(
                    f"Q{qi} ({fi:.4f} GHz) and Q{qj} ({fj:.4f} GHz) are "
                    f"within {delta*1e3:.1f} MHz -- resonant swap collision."
                ),
            ))

        # 2. Parasitic CZ (0-2): |fi - (fj + aj)| < min_sep
        delta_02 = abs(fi - (fj + aj))
        if delta_02 < min_sep:
            collisions.append(Collision(
                kind="parasitic_cz_02",
                qubits=(qi, qj),
                delta_ghz=delta_02,
                description=(
                    f"Q{qi} |0>->|1> at {fi:.4f} GHz collides with "
                    f"Q{qj} |1>->|2> at {fj + aj:.4f} GHz."
                ),
            ))

        # 3. Parasitic CZ (2-0): |fj - (fi + ai)| < min_sep
        delta_20 = abs(fj - (fi + ai))
        if delta_20 < min_sep:
            collisions.append(Collision(
                kind="parasitic_cz_20",
                qubits=(qi, qj),
                delta_ghz=delta_20,
                description=(
                    f"Q{qj} |0>->|1> at {fj:.4f} GHz collides with "
                    f"Q{qi} |1>->|2> at {fi + ai:.4f} GHz."
                ),
            ))

        # 4. Leakage 01-12: |fi - fj - aj| < min_sep  (|01> <-> |12>)
        delta_l1 = abs(fi - fj - aj)
        if delta_l1 < min_sep:
            collisions.append(Collision(
                kind="leakage_01_12",
                qubits=(qi, qj),
                delta_ghz=delta_l1,
                description=(
                    f"Leakage: Q{qi} 01 transition near Q{qj} 12 "
                    f"(separation {delta_l1*1e3:.1f} MHz)."
                ),
            ))

        # 5. Leakage 10-21: |fj - fi - ai| < min_sep  (|10> <-> |21>)
        delta_l2 = abs(fj - fi - ai)
        if delta_l2 < min_sep:
            collisions.append(Collision(
                kind="leakage_10_21",
                qubits=(qi, qj),
                delta_ghz=delta_l2,
                description=(
                    f"Leakage: Q{qj} 10 transition near Q{qi} 21 "
                    f"(separation {delta_l2*1e3:.1f} MHz)."
                ),
            ))

    return collisions
