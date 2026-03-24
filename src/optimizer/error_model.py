"""Error model for predicting cycle errors from frequency configurations.

Combines four error mechanisms (dephasing, relaxation, stray coupling, pulse
distortion) across four pair-context types (direct, next-nearest, spectator,
global) into a weighted sum that can be trained against XEB measurements.
"""

import numpy as np
from scipy.optimize import nnls


# ---------------------------------------------------------------------------
# Context labels  (rows of the weight matrix)
# ---------------------------------------------------------------------------
CTX_DIRECT = 0       # directly coupled pair
CTX_NEXT_NEAREST = 1 # two hops apart
CTX_SPECTATOR = 2    # spectator qubit watching a gate
CTX_GLOBAL = 3       # global / residual

# Mechanism labels (columns)
MECH_DEPHASING = 0
MECH_RELAXATION = 1
MECH_STRAY_ZZ = 2
MECH_PULSE_DIST = 3

N_CONTEXTS = 4
N_MECHANISMS = 4


class ErrorModel:
    """Lightweight analytical error model for frequency-allocation scoring.

    The model predicts the XEB *cycle error* for a full frequency
    configuration ``{qubit_idx: freq_GHz}`` by summing per-pair error
    contributions weighted by 16 trainable (non-negative) weights.
    """

    def __init__(self):
        # 4 contexts x 4 mechanisms, initialised to ones
        self.weights = np.ones((N_CONTEXTS, N_MECHANISMS), dtype=float)

    # ------------------------------------------------------------------
    # Individual error mechanisms
    # ------------------------------------------------------------------

    @staticmethod
    def dephasing_error(freq: float, flux_sens: float,
                        flux_noise: float = 3e-6) -> float:
        """Pure-dephasing error from flux noise.

        Parameters
        ----------
        freq : float
            Operating frequency (GHz) -- not used directly but kept for API symmetry.
        flux_sens : float
            df/dPhi (GHz / Phi_0).
        flux_noise : float
            RMS flux noise amplitude in Phi_0.

        Returns
        -------
        float
            Estimated dephasing error (dimensionless, >= 0).
        """
        # Gamma_phi ~ |df/dPhi| * flux_noise.  Gate-time factor folded into weight.
        return abs(flux_sens) * flux_noise

    @staticmethod
    def relaxation_error(freq: float, T1: float) -> float:
        """Relaxation-limited gate error.

        A rough metric: t_gate / T1 where t_gate ~ 42 ns (CZ).
        """
        t_gate_us = 42e-3  # 42 ns in microseconds
        if T1 <= 0:
            return 1.0
        return t_gate_us / T1

    @staticmethod
    def stray_coupling_error(f_i: float, f_j: float,
                             J: float, alpha_i: float, alpha_j: float,
                             t_gate: float = 42e-3) -> float:
        """Static ZZ interaction error between two qubits.

        Uses the dispersive-regime ZZ formula:
            zz ~ 2 * (alpha_i + alpha_j) * J^2 / ((delta + alpha_i) * (delta - alpha_j))

        Parameters
        ----------
        f_i, f_j : float
            Qubit frequencies (GHz).
        J : float
            Coupling strength (GHz).
        alpha_i, alpha_j : float
            Anharmonicities (GHz), typically negative ~ -0.2 GHz.
        t_gate : float
            Gate duration in microseconds (default 42 ns).

        Returns
        -------
        float
            Error contribution (>= 0).
        """
        delta = f_i - f_j
        denom1 = delta + alpha_i
        denom2 = delta - alpha_j
        # Avoid division by zero near collisions
        if abs(denom1) < 1e-4 or abs(denom2) < 1e-4:
            # Near collision -- return a large but finite penalty
            return abs(J) * t_gate * 1e3
        zz = abs(2 * (alpha_i + alpha_j) * J ** 2 / (denom1 * denom2))
        return zz * t_gate * 1e3  # rough scaling to error units

    @staticmethod
    def pulse_distortion_error(idle_f: float, interaction_f: float,
                               coeff: float = 0.001) -> float:
        """Error from imperfect flux-pulse shaping.

        Proportional to the frequency excursion during a CZ gate.
        """
        return coeff * abs(idle_f - interaction_f)

    # ------------------------------------------------------------------
    # Full prediction
    # ------------------------------------------------------------------

    def _pair_error_vector(self, f_i: float, f_j: float,
                           J: float, alpha_i: float, alpha_j: float,
                           flux_sens_i: float, flux_sens_j: float,
                           T1_i: float, T1_j: float) -> np.ndarray:
        """Return a 4-element mechanism vector for one coupled pair."""
        e_deph = (self.dephasing_error(f_i, flux_sens_i)
                  + self.dephasing_error(f_j, flux_sens_j))
        e_relax = (self.relaxation_error(f_i, T1_i)
                   + self.relaxation_error(f_j, T1_j))
        e_zz = self.stray_coupling_error(f_i, f_j, J, alpha_i, alpha_j)
        e_pulse = self.pulse_distortion_error(f_i, f_j)
        return np.array([e_deph, e_relax, e_zz, e_pulse])

    def predict_cycle_error(self, freq_config: dict[int, float],
                            processor) -> float:
        """Predict the total cycle error for a frequency configuration.

        Iterates over every coupled pair and sums weighted mechanism errors.

        Parameters
        ----------
        freq_config : dict[int, float]
            Mapping qubit index -> operating frequency (GHz).
        processor : ProcessorModel
            The processor supplying coupling map, J values, qubit properties.

        Returns
        -------
        float
            Predicted aggregate cycle error.
        """
        total = 0.0
        for (qi, qj) in processor.coupling_map:
            pair_key = (min(qi, qj), max(qi, qj))
            J = processor.couplings.get(pair_key, 0.005)

            q_i = processor.qubits[qi]
            q_j = processor.qubits[qj]

            f_i = freq_config.get(qi, q_i.frequency())
            f_j = freq_config.get(qj, q_j.frequency())

            alpha_i = q_i.alpha
            alpha_j = q_j.alpha
            flux_sens_i = q_i.flux_sensitivity()
            flux_sens_j = q_j.flux_sensitivity()
            T1_i = q_i.T1
            T1_j = q_j.T1

            mech_vec = self._pair_error_vector(
                f_i, f_j, J, alpha_i, alpha_j,
                flux_sens_i, flux_sens_j, T1_i, T1_j,
            )

            # For simplicity, use CTX_DIRECT for every pair in the coupling map
            ctx = CTX_DIRECT
            total += float(self.weights[ctx] @ mech_vec)

        # Add a small global baseline per qubit
        n_q = len(freq_config)
        total += n_q * 1e-4 * float(np.mean(self.weights[CTX_GLOBAL]))

        return max(0.0, total)

    # ------------------------------------------------------------------
    # Training
    # ------------------------------------------------------------------

    def train_weights(self, configs: list[dict[int, float]],
                      measured_errors: list[float],
                      processor) -> None:
        """Fit the 16 weights via non-negative least squares.

        Parameters
        ----------
        configs : list of freq_config dicts
            Each entry maps qubit -> freq (GHz).
        measured_errors : list of float
            Corresponding measured XEB cycle errors.
        processor : ProcessorModel
            Processor supplying topology and qubit parameters.
        """
        n_samples = len(configs)
        n_weights = N_CONTEXTS * N_MECHANISMS

        # Build the design matrix A (n_samples x n_weights)
        A = np.zeros((n_samples, n_weights))
        b = np.array(measured_errors, dtype=float)

        for idx, cfg in enumerate(configs):
            for (qi, qj) in processor.coupling_map:
                pair_key = (min(qi, qj), max(qi, qj))
                J = processor.couplings.get(pair_key, 0.005)
                q_i = processor.qubits[qi]
                q_j = processor.qubits[qj]
                f_i = cfg.get(qi, q_i.frequency())
                f_j = cfg.get(qj, q_j.frequency())

                mech_vec = self._pair_error_vector(
                    f_i, f_j, J, q_i.alpha, q_j.alpha,
                    q_i.flux_sensitivity(), q_j.flux_sensitivity(),
                    q_i.T1, q_j.T1,
                )
                # Direct context columns
                start = CTX_DIRECT * N_MECHANISMS
                A[idx, start:start + N_MECHANISMS] += mech_vec

            # Global baseline
            n_q = len(cfg)
            A[idx, CTX_GLOBAL * N_MECHANISMS:CTX_GLOBAL * N_MECHANISMS + N_MECHANISMS] += (
                n_q * 1e-4 / N_MECHANISMS
            )

        # NNLS solve
        w, _ = nnls(A, b)
        self.weights = w.reshape((N_CONTEXTS, N_MECHANISMS))
