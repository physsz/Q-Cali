# TLS Forecasting Algorithm Reconstruction: Research Report

## Executive Summary

Google's Willow paper (Nature, 2024, DOI:10.1038/s41586-024-08449-y) states: *"Prior to the repeated runs, we employ a frequency optimization strategy which forecasts defect frequencies of two-level systems (TLS). This helps to avoid qubits coupling to TLSs during the initial calibration as well as over the duration of the experiments."* The paper also acknowledges that *"the performance of the worst distance-3 quadrant appears to fluctuate due to a transient TLS moving faster than our forecasts."* No algorithmic details are provided.

This report synthesizes the physics, measurements, and methods needed to independently reconstruct such a forecasting capability.

---

## 1. TLS Physics in Transmon Qubits

### 1.1 Physical Origins

TLS defects in transmon qubits arise from multiple sources:

- **Structural tunneling systems**: Atoms or small groups of atoms tunnel between two configurations in disordered (amorphous) materials at device interfaces. These are the classical "glassy" TLS described by the Standard Tunneling Model (STM).
- **Trapped quasiparticles**: Quasiparticles trapped in shallow subgap states created by spatial fluctuations of the superconducting order parameter form a new type of TLS, with maximum density of states around 6-10 GHz -- precisely where transmon qubits operate. These have a low reconfiguration temperature ~300 mK.
- **Hydrogen-based defects**: Hydrogen trapped by oxygen, titanium, or zirconium in niobium/aluminum films occupies thermodynamically favored interstitial sites, creating tunneling systems with computed splittings of 0.06-0.57 meV.

### 1.2 Physical Locations

Mapping studies using trilateration with gate electrodes (55 detected TLS) reveal:
- **58% on Josephson junction leads** (DC-SQUID region)
- **25% near qubit island edges**
- **16% near ground plane edges**

The junction lead concentration is attributed to shadow evaporation and lift-off fabrication processes leaving resist residuals and enhanced roughness. Detection is limited to TLS within ~1-2 um from electrode edges where the qubit's AC field is strong enough.

### 1.3 Coupling Mechanism

TLS couple to qubits via their electric dipole moment interacting with the oscillating electric field of the qubit circuit:

$$g = \frac{p \cdot E_{\text{zpf}}}{\hbar}$$

Where $p$ is the TLS dipole moment and $E_{\text{zpf}}$ is the zero-point electric field at the TLS location.

**Measured parameters:**
- Median dipole moment: $p_\parallel \approx 1.12 \pm 0.12$ eA (surface TLS)
- Maximum dipole moment for SA interface: $p_{\max} = 5$ Debye
- Coupling strengths: $g/2\pi \sim 5$-$50$ MHz (individually detectable), with threshold $g/2\pi \geq 0.5$ MHz for "strongly coupled"
- Coupling rates for weaker TLS: 50-500 kHz

**Two coupling types identified:**
1. **Linear coupling** (conventional): Charge fluctuations from TLS dipole
2. **Nonlinear coupling** (rare): Critical-current fluctuations from TLS in junction barrier

### 1.4 TLS Energy and Frequency

The TLS Hamiltonian in the standard tunneling model:

$$H_{\text{TLS}} = \frac{1}{2}(\epsilon \sigma_z + \Delta \sigma_x)$$

where $\epsilon$ is the asymmetry energy and $\Delta$ is the tunnel splitting. The TLS transition frequency is:

$$f_{\text{TLS}} = \frac{1}{h}\sqrt{\epsilon^2 + \Delta^2}$$

The asymmetry energy depends on external fields:

$$\epsilon = 2\gamma \cdot S + 2p \cdot E + \epsilon_0$$

where $\gamma$ is the elastic dipole (strain coupling), $S$ is the strain field, and $E$ is the applied electric field. This gives the characteristic hyperbolic frequency dependence under applied electric fields.

### References for Section 1
- [Mapping TLS positions on transmon qubits](https://arxiv.org/html/2511.05365v2)
- [Electric field spectroscopy of material defects in transmon qubits](https://www.nature.com/articles/s41534-019-0224-1)
- [Two-level systems from trapped quasiparticles](https://www.science.org/doi/10.1126/sciadv.abc5055)
- [Identification of different types of high-frequency defects](https://ar5iv.labs.arxiv.org/html/2112.05391)
- [Lattice-renormalized tunneling models](https://arxiv.org/abs/2512.18156)
- [Statistics of strongly coupled defects](https://arxiv.org/html/2506.00193v1)

---

## 2. TLS Temporal Dynamics

### 2.1 Spectral Diffusion Mechanism

TLS frequencies are not static. The interacting TLS model (Muller, Lisenfeld, Shnirman 2015) explains this:

1. **High-frequency TLS** (near qubit frequency, ~5 GHz) are the ones that directly couple to and decohere qubits.
2. **Low-frequency "thermal" TLS** (energies below $k_BT$, i.e., below ~1 GHz at 20 mK) fluctuate thermally between their two states.
3. High-frequency TLS interact with the thermal TLS bath via strain/electric dipole coupling, causing their transition frequencies to wander -- this is **spectral diffusion**.

The result: high-frequency TLS frequencies execute a random walk driven by the switching of nearby thermal fluctuators.

### 2.2 Measured Switching Rates and Drift Rates

**Spectral diffusion rate:**
- Measured diffusivity: $D = 2.2 \pm 0.1$ MHz/hr$^{1/2}$ (from statistics of strongly coupled defects paper)
- TLS frequency wander: ~10 MHz over 60+ hours observed in multilevel relaxation studies
- Defect mode frequencies drift at **several MHz per day** at 10 mK
- TLS spectral landscape can change drastically on **hour timescales**

**TLS switching rates (telegraphic behavior):**
- Slow fluctuators: 71.4 uHz to 1.9 mHz (from early studies, hours-to-days timescale)
- Medium fluctuators: ~100 mHz (stable across 3+ hours of observation)
- Fast fluctuators: **up to 10 Hz** (newly discovered via FPGA-based Bayesian tracking, 2026)
  - This is **4 orders of magnitude faster** than previously reported
  - ~2.6% of measurement intervals show T1 changes >100 us, roughly one event every 7.7 seconds

**T1 impact dynamics:**
- T1 switches between >500 us and ~100 us on timescales of tens to hundreds of milliseconds
- Overall T1 fluctuations typically ~20% amplitude
- Autocorrelation timescales range from seconds to months

### 2.3 Power Spectral Density of T1 Fluctuations

The PSD of relaxation rate fluctuations shows three components:
1. **White noise**: $A_w \approx 3.30 \times 10^{-5}$ s$^3$
2. **1/f noise**: $A_{1/f} \approx 1.36 \times 10^{-4}$ s$^2$
3. **Lorentzian processes** (from individual TLS):
   - $A_{L,1} \approx 1.8 \times 10^{-4}$ s$^2$, $\gamma_1 \approx 46$ mHz
   - $A_{L,2} \approx 1.0 \times 10^{-4}$ s$^2$, $\gamma_2 \approx 2$ mHz

### 2.4 Radiation-Induced TLS Scrambling

Ionizing radiation (cosmic rays) causes **TLS scrambling**: a radiation impact causes multiple TLS to simultaneously jump in frequency. This introduces a non-diffusive, sudden reconfiguration channel:
- Correlated multi-qubit error bursts at millisecond timescale
- TLS frequency shifts can move defects into or out of resonance with qubits
- Cosmic ray rate: ~1 event per 592 seconds, accounting for ~17% of correlated error events

### References for Section 2
- [Dynamics of superconducting qubit relaxation times](https://www.nature.com/articles/s41534-022-00643-y)
- [Klimov et al. 2018 - Fluctuations of Energy-Relaxation Times](https://link.aps.org/doi/10.1103/PhysRevLett.121.090502)
- [Real-time adaptive tracking of fluctuating relaxation rates](https://arxiv.org/html/2506.09576)
- [TLS dynamics due to background ionizing radiation](https://arxiv.org/abs/2210.04780)
- [Interacting two-level defects as noise sources](https://arxiv.org/abs/1503.01637)
- [TLS spectroscopy from correlated multilevel relaxation](https://arxiv.org/html/2602.11127v1)
- [Statistics of strongly coupled defects](https://arxiv.org/html/2506.00193v1)
- [Cosmic rays and correlated errors in qubit arrays](https://www.nature.com/articles/s41467-025-61385-x)

---

## 3. TLS Detection and Spectroscopy Methods

### 3.1 Swap Spectroscopy

The primary method for mapping TLS across frequency:
1. Excite qubit with a pi-pulse
2. Tune qubit to various probe frequencies via flux pulses
3. Measure population loss after variable interaction time
4. TLS appear as dark traces (reduced T1) in the frequency-time map

Sensitivity threshold: g/2pi >= 0.5 MHz (corresponding to ~10% population loss during 100 ns interaction).

### 3.2 AC Stark Shift Spectroscopy

For fixed-frequency transmons:
- Off-resonant microwave drive shifts qubit frequency via AC Stark effect
- Enables scanning ~100 MHz range without flux tunability
- Individual TLS appear as dips in T1 spectrum

### 3.3 Two-Tone Spectroscopy

For detecting TLS without frequency tunability:
- Pulse A: Drive at varying frequencies to excite TLS of unknown frequency
- Pulse B: Calibrated pi-pulse at qubit frequency for readout
- Generates (omega, t)-maps containing TLS frequency and coupling information
- CNN-based analysis achieves 98.6-98.7% accuracy for two-TLS identification

### 3.4 Multilevel Relaxation Correlation Spectroscopy (2026)

Novel method requiring no frequency tunability:
- Repeatedly prepare |2> state and simultaneously measure T1 of |1>->|0> and |2>->|1> transitions
- Anti-correlation between the two T1 values indicates TLS drifting between the two transition frequencies
- Enables reconstruction of TLS frequency trajectory over time (60+ hours demonstrated)
- Finds that TLS detuned by >100 MHz can still significantly influence relaxation

### 3.5 Electric Field Spectroscopy

Applied DC electric fields tune TLS frequencies via the dipole coupling:
- Tuning sensitivity: ~4 MHz/V for typical dipole moments (~3 Debye)
- Individual TLS show tuning sensitivities of 99-330 MHz/V
- Enables distinguishing junction-barrier TLS from interface TLS

### References for Section 3
- [Electric field spectroscopy of material defects](https://www.nature.com/articles/s41534-019-0224-1)
- [Two-tone spectroscopy for TLS detection](https://arxiv.org/html/2404.14039)
- [TLS spectroscopy from correlated multilevel relaxation](https://arxiv.org/html/2602.11127v1)
- [Scalable site-specific TLS frequency tuning](https://arxiv.org/html/2503.04702v1)
- [Mitigating losses from strongly coupled defect modes](https://arxiv.org/html/2407.18746v1)

---

## 4. TLS Modeling and Simulation

### 4.1 Standard Tunneling Model (STM)

The classical framework treats TLS as double-well potentials with:
- Asymmetry energy epsilon: uniformly distributed
- Tunnel splitting Delta: log-uniformly distributed (P(Delta) ~ 1/Delta)
- Resulting in flat density of states: $P_0 \approx$ constant per unit energy per unit volume
- Bulk TLS density: 200-1200 GHz$^{-1}$ um$^{-3}$

### 4.2 Generalized Tunneling Model (GTM)

The GTM introduces TLS-TLS interactions and a modified density of states:
- Low-energy TLS density of states is **pseudo-gapped** (not constant)
- Strong strain interactions between TLS create correlated behavior
- Successfully explains 1/f noise spectra, temperature-dependent dephasing rates, and non-STM features in resonator experiments
- Thermal cycling evidence: heating to ~20 K reconfigures >90% of TLS (cf. ~10% at 2 K cycling)

### 4.3 Lattice-Renormalized Tunneling Model (2025)

Most ab-initio approach to date:
- Computes tunnel splittings from first-principles nuclear Hamiltonians
- Uses composite phonon coordinates to capture lattice distortions
- For hydrogen TLS in niobium: tunnel splitting 0.06-0.57 meV depending on concentration
- Reveals that local strain fields strongly modulate TLS energetics: 0.2-1 eV shifts per 0.002-0.02% strain
- Identifies that four-level (and higher) systems persist under strain, complicating the two-level picture

### 4.4 TLS Density and Distribution for Transmon Qubits

**Substrate-air (SA) interface:**
- Surface density: sigma = 2/GHz/um$^2$
- p_max = 5 Debye

**Junction lead region:**
- Linear density: lambda = 0.4-0.7/GHz/um
- Equivalent surface density: 3-6/GHz/um$^2$ (enhanced ~2x vs capacitor region)

**Strongly coupled defects** (g/2pi >= 0.5 MHz):
- ~3% of total TLS population
- Predominantly from junction tunnel barrier (where E-fields reach kV/m)
- Defect relaxation rates: Gaussian distribution, mean ~5 us$^{-1}$, range 2-30 us$^{-1}$

**T1 scaling:** For fixed charging energy, $T_1 \propto \Delta_r^{0.6}$ where $\Delta_r$ is the gap size.

### References for Section 4
- [Generalized tunneling model](https://arxiv.org/abs/1404.2410)
- [Thermal cycling evidence for GTM](https://arxiv.org/html/2410.19930)
- [Lattice-renormalized tunneling models](https://arxiv.org/html/2512.18156)
- [Statistics of strongly coupled defects](https://arxiv.org/html/2506.00193v1)
- [Mitigating losses from strongly coupled defect modes](https://arxiv.org/html/2407.18746v1)

---

## 5. Existing Approaches to TLS Management

### 5.1 Google's Snake Optimizer (Frequency Trajectory Optimization)

Google's published approach (Nature Communications, 2024) for their 68-qubit Sycamore processor:

**Error model with ~40,000 components and only 16 trained weights:**
1. **Relaxation mitigation**: Bias qubits away from T1 hotspots (TLS resonances, coupling to control/readout circuitry)
2. **Dephasing mitigation**: Bias qubits toward max frequency (flux-insensitive sweet spots)
3. **Stray-coupling mitigation**: Disperse qubit frequencies to avoid parasitic couplings

**Data requirements:**
- Qubit flux-sensitivity spectra
- Energy-relaxation rate (1/T1) spectra across frequency
- Parasitic stray coupling parameters
- Pulse distortion parameters
- ~6,500 benchmarks for weight training

**Result:** ~3.7x suppression of physical error rates vs unoptimized; projected to scale to distance-23 codes (1,057 qubits).

### 5.2 DC Electric Field TLS Tuning (Lisenfeld et al.)

Apply DC bias to local gate electrodes to Stark-shift TLS away from qubit frequency:
- Average T1 improvement: **23%**
- Per-qubit electrodes enable independent optimization
- Tuning range: ~4 MHz/V for typical TLS
- Over 40-hour observation: 36% improvement in single-qubit error rates, 17% improvement in T1, 4-fold suppression of TLS-induced outliers

### 5.3 Scalable Site-Specific TLS Frequency Tuning (2025)

Voltage biases on individual qubits tune TLS out of resonance:
- Individual TLS tuning sensitivities: 99-330 MHz/V
- 1V produces >130 V/m at qubit pad edges
- Challenge: In multi-qubit devices, tuning one TLS away may tune another into resonance with a different qubit

### 5.4 Junction Area Reduction (Fabrication)

Reducing Josephson junction area directly reduces the number of strongly coupled TLS:
- Linear scaling: fewer defects with smaller junction area
- Reduction from 0.22 um$^2$ to 0.034 um$^2$ substantially decreased defect density
- Maintain qubit frequency by adjusting critical current density

### References for Section 5
- [Optimizing quantum gates towards the scale of logical qubits](https://www.nature.com/articles/s41467-024-46623-y)
- [Enhancing coherence with electric fields](https://www.nature.com/articles/s41534-023-00678-9)
- [Scalable site-specific TLS frequency tuning](https://arxiv.org/html/2503.04702v1)
- [Mitigating losses from strongly coupled defect modes](https://arxiv.org/html/2407.18746v1)

---

## 6. Impact of TLS on Quantum Error Correction

The Willow paper demonstrates:
- **Transient TLS cause fluctuations** in distance-3 code performance, but these are **suppressed in distance-5 codes** because larger codes average over more physical qubits.
- **TLS moving faster than forecasts** are acknowledged as a limitation: they cause the worst-performing quadrant to fluctuate.
- Logical memory lifetime exceeds best physical qubit by factor **2.4 +/- 0.3** (break-even), enabled partly by TLS forecasting.

**Quantitative impact of a single resonant TLS:**
- 60% reduction in T1
- 35% reduction in T2
- 35-fold increase in single-qubit error rate

This means even one TLS coupling event during a QEC experiment can catastrophically degrade a physical qubit, making forecasting essential.

### References for Section 6
- [Quantum error correction below the surface code threshold](https://www.nature.com/articles/s41586-024-08449-y)
- [Scalable site-specific TLS frequency tuning](https://arxiv.org/html/2503.04702v1)

---

## 7. Temperature Dependence of TLS

- At T < 35 mK: qubit excited-state population saturates at ~0.1%
- 35-150 mK: Maxwell-Boltzmann distribution applies
- TLS with energies below ~kBT (~1 GHz at 20 mK) are thermally active and drive spectral diffusion
- Trapped quasiparticle TLS have reconfiguration temperature ~300 mK
- Thermal cycling to ~20 K reconfigures >90% of TLS; to ~2 K reconfigures ~10%
- Thermal cycling randomizes TLS configuration -- it becomes exponentially unlikely to find a good configuration for all qubits as processor size grows

### References for Section 7
- [Thermal cycling evidence for generalized tunneling model](https://arxiv.org/html/2410.19930)
- [Thermal and residual excited-state population in 3D transmon](https://link.aps.org/doi/10.1103/PhysRevLett.114.240501)
- [Two-level systems from trapped quasiparticles](https://www.science.org/doi/10.1126/sciadv.abc5055)

---

## 8. Materials Science Solutions

Recent advances in TLS reduction:

- **Tantalum films** (2025): Room-temperature alpha-Ta growth on Si using Nb seed layer achieves state-of-the-art quality factors
- **Crystalline silicon fin capacitors**: High aspect ratio Si-fin capacitors (widths <300 nm) reduce amorphous dielectric volume
- **Cleaning protocols**: Ultra-thin resist residue removal reduces weakly coupled TLS loss by ~3x, but does NOT affect strongly coupled defect density (those are in junction barrier)
- **Junction thermal annealing**: Reduces defects/impurities in insulating oxide layer

Key insight: **Strongly coupled defects (the dangerous ones for qubits) originate in the junction barrier and are NOT reduced by surface cleaning.** Junction area reduction is the most effective fabrication mitigation.

### References for Section 8
- [Low-loss tantalum films at room temperature](https://www.nature.com/articles/s43246-025-00897-x)
- [Low-loss Al/Si/Al parallel plate capacitors](https://www.nature.com/articles/s41534-025-00967-5)
- [Mitigation of interfacial dielectric loss](https://www.nature.com/articles/s41534-024-00868-z)
- [Mitigating losses from strongly coupled defect modes](https://arxiv.org/html/2407.18746v1)

---

## 9. Proposed TLS Forecasting Algorithms

Based on the physics and data surveyed above, here are concrete algorithmic proposals for independent TLS forecasting.

### 9.1 Algorithm 1: Bayesian TLS Tracker with Lorentzian Model

**Concept:** Model T1(f,t) as a function of qubit frequency f and time t, where TLS appear as Lorentzian dips that move in frequency space.

**State representation:**
For each known TLS defect i:
$$\text{State}_i(t) = \{f_{\text{TLS},i}(t), \gamma_i, g_i, \text{active}_i\}$$
where $f_{\text{TLS}}$ is frequency, $\gamma$ is linewidth, $g$ is coupling strength, and active is a binary state.

**Dynamics model:**
$$f_{\text{TLS},i}(t+\delta t) = f_{\text{TLS},i}(t) + \sqrt{2D \cdot \delta t} \cdot \xi$$
where $D = 2.2$ MHz/hr$^{1/2}$ (measured diffusion constant) and $\xi \sim \mathcal{N}(0,1)$.

Augment with telegraphic switching:
$$\text{active}_i(t+\delta t) = \begin{cases} 1-\text{active}_i(t) & \text{with probability } r_i \cdot \delta t \\ \text{active}_i(t) & \text{otherwise} \end{cases}$$
where $r_i$ is the switching rate for the i-th TLS ($10^{-4}$ to $10$ Hz based on measurements).

**Observation model:**
$$\Gamma_1(f_q, t) = \Gamma_{1,\text{bg}}(f_q) + \sum_{i} \frac{g_i^2 \gamma_i}{\gamma_i^2 + (f_q - f_{\text{TLS},i}(t))^2} \cdot \text{active}_i(t)$$

**Inference:** Particle filter (Sequential Monte Carlo) with:
- N ~ 1000-10000 particles per TLS
- Resampling when effective sample size drops below N/2
- New TLS spawned when unexplained T1 dip detected

**Prediction:** Propagate particle ensemble forward using diffusion model. The predictive distribution at time t+tau gives probability of TLS being at frequency f:
$$P(f_{\text{TLS},i}(t+\tau) | \text{data up to } t) \approx \mathcal{N}(f_{\text{TLS},i}(t), 2D\tau)$$

For safe frequency allocation, choose qubit operating frequency $f_q$ to maximize minimum distance from all predicted TLS frequency distributions, with safety margin proportional to $\sqrt{2D\tau}$.

**Data requirements:**
- T1 vs frequency scans every 1-4 hours (each scan: ~100 frequency points, ~5 min)
- Continuous T1 monitoring at operating frequency (every few seconds)
- Historical TLS database from swap spectroscopy

**Computational cost:** O(N_particles * N_TLS) per update, ~ms on modern CPU. FPGA implementation feasible for real-time.

**Expected prediction accuracy:**
- Short-term (1-4 hours): sigma_f ~ 3-5 MHz (using D=2.2 MHz/hr^{1/2})
- Medium-term (24 hours): sigma_f ~ 10-15 MHz
- Long-term (1 week): sigma_f ~ 30-40 MHz

**Limitation:** Cannot predict TLS activation/deactivation (telegraphic switching) or radiation-induced scrambling.

---

### 9.2 Algorithm 2: Hidden Markov Model for TLS Landscape

**Concept:** Discretize the frequency-time landscape and model TLS occupation as a hidden Markov model.

**State space:**
Discretize qubit-accessible frequency range (e.g., 4-6 GHz) into bins of width delta_f ~ 1 MHz (2000 bins). Each bin has binary occupation: TLS present/absent.

**Transition model:**
$$P(\text{bin } j \text{ occupied at } t+\delta t | \text{bin } i \text{ occupied at } t) \propto \exp\left(-\frac{(f_j - f_i)^2}{4D\delta t}\right)$$

Plus activation/deactivation:
$$P(\text{activation in bin } j) = \rho_{\text{TLS}} \cdot \delta f \cdot r_{\text{on}} \cdot \delta t$$
$$P(\text{deactivation}) = r_{\text{off}} \cdot \delta t$$

**Observation model:**
T1 measurements at operating frequency provide noisy information about nearby TLS occupation.

**Inference:** Forward-backward algorithm or Viterbi decoding.

**Data requirements:** Same as Algorithm 1, plus swap spectroscopy snapshots for initialization.

**Computational cost:** O(N_bins^2) per transition update -- expensive for fine resolution. Use sparse transitions (only adjacent bins need consideration) to reduce to O(N_bins).

**Expected accuracy:** Similar to Algorithm 1 for tracked TLS; better at handling appearance/disappearance through explicit activation rates.

---

### 9.3 Algorithm 3: Neural Network Time-Series Forecaster

**Concept:** Train LSTM/Transformer on historical T1 time-series data to predict future T1 at each qubit frequency.

**Architecture:**
- Input: Rolling window of T1 measurements (e.g., last 48 hours at 10-minute resolution = 288 time steps)
- Per-qubit features: operating frequency, anharmonicity, junction parameters
- Cross-qubit features: neighboring qubit states (for correlated TLS effects)
- Output: Predicted T1 distribution over next 1-24 hours; probability of T1 dropping below threshold

**Training data requirements:**
- Months of continuous T1 monitoring across many qubits (Google has this from Sycamore/Willow)
- Estimated: >10,000 qubit-hours of T1 time series for robust training
- Include thermal cycling events, radiation events for robustness

**Computational cost:**
- Training: GPU-hours to GPU-days
- Inference: ~1 ms per prediction on GPU, real-time capable

**Expected accuracy:**
- Can learn TLS-specific patterns (individual TLS have characteristic timescales)
- Likely achieves better short-term prediction than physics-based models due to implicit learning of device-specific correlations
- Weakness: Cannot generalize to new devices without retraining; black-box predictions

---

### 9.4 Algorithm 4: Gaussian Process Regression with Physics-Informed Kernel

**Concept:** Model T1(f,t) as a Gaussian process with kernel designed to capture TLS physics.

**Kernel design:**
$$k((f_1,t_1), (f_2,t_2)) = k_{\text{freq}}(f_1,f_2) \cdot k_{\text{time}}(t_1,t_2) + k_{\text{TLS}}$$

where:
- $k_{\text{freq}}$: Matern kernel with lengthscale ~ TLS linewidth (0.1-1 MHz)
- $k_{\text{time}}$: Composite kernel = RBF(long timescale ~ days) + Matern(short ~ hours) to capture both slow drift and faster switching
- $k_{\text{TLS}}$: Spectral mixture kernel to capture Lorentzian structure

**Prediction:** GP posterior gives both mean prediction and uncertainty bounds. Qubit frequency chosen where lower confidence bound on T1 exceeds threshold.

**Data requirements:**
- T1(f,t) measurements: ~100 frequency points x ~100 time points for initial fit
- Online updates as new measurements arrive

**Computational cost:**
- Exact GP: O(n^3) -- prohibitive for large datasets
- Sparse GP (inducing points): O(nm^2) with m ~ 500 inducing points
- Scalable to real-time with periodic batch updates

**Expected accuracy:** Competitive with Bayesian tracker; provides natural uncertainty quantification for conservative frequency allocation.

---

### 9.5 Algorithm 5: Change-Point Detection + Extrapolation (Likely closest to Google's approach)

**Concept:** This is the most likely reconstruction of what Google actually does, based on available evidence:

**Phase 1: TLS Catalog Construction**
1. Perform swap spectroscopy across full frequency range at start of cooldown
2. Identify all strongly coupled TLS: record {f_TLS, g, gamma, T1_TLS}
3. Build exclusion zones: frequency bands where T1 < threshold

**Phase 2: TLS Tracking**
1. Monitor T1 at operating frequency continuously (every 4 QEC rounds in Willow)
2. Periodically (every few hours) perform rapid T1-vs-frequency scans
3. Use change-point detection (CUSUM or Bayesian online change-point detection) to identify when a TLS has shifted

**Phase 3: Forecasting**
1. For each tracked TLS, maintain a running estimate of frequency and drift velocity
2. **Linear extrapolation** with diffusion uncertainty:
   $$f_{\text{TLS}}(t+\tau) \sim \mathcal{N}(\hat{f}_{\text{TLS}}(t) + \hat{v}\tau, \ 2D\tau + \sigma_{\text{meas}}^2)$$
3. Define exclusion zones as intervals where:
   $$P(|f_q - f_{\text{TLS}}| < g/\pi) > p_{\text{threshold}}$$

**Phase 4: Frequency Reallocation**
1. When a TLS is forecast to enter the operating frequency band, trigger recalibration
2. Shift qubit to alternative operating frequency that avoids all forecast TLS positions
3. In Willow: this happens between experimental blocks (every 4 runs)

**Data requirements:**
- Initial swap spectroscopy: ~30 minutes per qubit
- Continuous T1 monitoring: built into QEC syndrome extraction
- Periodic T1-vs-frequency scans: ~5 min every 2-4 hours

**Computational cost:** Negligible -- simple tracking and linear extrapolation. Runs on experiment control computer.

**Expected accuracy:**
- Catches TLS drifting at typical rates (few MHz/day) with hours of lead time
- Fails for fast TLS switching (>1 Hz) -- consistent with Willow paper's acknowledgment
- Fails for radiation-induced scrambling events

**Why this is likely Google's approach:**
1. Google has swap spectroscopy capability (used in all their papers since 2018)
2. The Willow paper says "forecasts" (plural) suggesting per-TLS tracking
3. They acknowledge failure for "transient TLS moving faster than our forecasts" -- consistent with diffusion-based prediction failing for telegraphic events
4. The approach scales linearly with qubit count
5. Google's Snake optimizer already incorporates T1-vs-frequency spectra

---

### 9.6 Algorithm 6: Real-Time FPGA-Based Adaptive Tracker (State of the Art, 2026)

Based on the Niels Bohr Institute work (Phys. Rev. X, Feb 2026):

**Algorithm:** Gamma-distribution Bayesian estimation on FPGA:
1. Model relaxation rate Gamma_1 as gamma-distributed
2. Per measurement: prepare |1>, wait adaptive time tau = c * T1_hat, single-shot readout
3. Update posterior via method-of-moments matching to gamma distribution
4. Each update: ~2.2 us; full estimate from 50 shots: ~11 ms

**Key innovation:** Adaptive waiting time selection makes each measurement maximally informative. Previous methods used fixed measurement protocols requiring seconds for a single T1 estimate; this achieves millisecond resolution.

**For TLS forecasting extension:**
- Run parallel trackers at multiple frequency points (using AC Stark shift)
- Detect TLS as transient Lorentzian dips in the Gamma_1(f) landscape
- Track TLS frequency by fitting dip center over time
- Predict future position via diffusion model

**Computational cost:** FPGA real-time, ~2.2 us per update. Hardware: commercial quantum control system with integrated FPGA.

**Expected accuracy:** Resolves TLS switching events at up to 10 Hz, revealing dynamics previously invisible.

---

## 10. Recommended Implementation Roadmap

### Phase 1: Baseline TLS Characterization (Weeks 1-4)
1. Implement swap spectroscopy protocol
2. Map T1 vs frequency across full accessible range
3. Identify all strongly coupled TLS (g/2pi >= 0.5 MHz)
4. Measure TLS linewidths and coupling strengths
5. **Output:** Initial TLS catalog with {f, g, gamma} for each defect

### Phase 2: Temporal Tracking (Weeks 5-12)
1. Deploy continuous T1 monitoring at operating frequency (1 measurement/second minimum)
2. Periodic T1-vs-frequency scans (every 2-4 hours)
3. Build time-series database of TLS positions
4. Fit spectral diffusion constant D for each TLS
5. **Output:** Time-resolved TLS database with drift statistics

### Phase 3: Forecasting Implementation (Weeks 13-20)
1. Implement Algorithm 5 (change-point detection + extrapolation) as baseline
2. Implement Algorithm 1 (Bayesian particle filter) for comparison
3. Define exclusion zones with appropriate safety margins
4. Integrate with qubit frequency allocation optimizer
5. **Output:** Working forecasting system with defined prediction horizons

### Phase 4: Advanced Methods (Weeks 21+)
1. Implement FPGA-based real-time tracker (Algorithm 6) if hardware available
2. Train neural network forecaster (Algorithm 3) once sufficient data collected
3. Explore GP regression (Algorithm 4) for uncertainty-aware frequency planning
4. Implement voltage-bias TLS tuning for active mitigation
5. **Output:** Multi-method forecasting with active TLS management

---

## 11. Summary of Key Quantitative Parameters

| Parameter | Value | Source |
|-----------|-------|--------|
| TLS spectral diffusion constant D | 2.2 +/- 0.1 MHz/hr^{1/2} | Statistics of strongly coupled defects |
| TLS frequency drift rate | Few MHz/day | Multiple sources |
| TLS switching rates (slow) | 0.07-1.9 mHz | Klimov 2018 |
| TLS switching rates (fast) | Up to 10 Hz | FPGA Bayesian tracker 2026 |
| Strongly coupled TLS density (SA interface) | 2/GHz/um^2 | Statistics paper |
| Strongly coupled TLS density (junction leads) | 0.4-0.7/GHz/um | Statistics paper |
| TLS coupling strength (detectable) | 5-50 MHz | Multiple sources |
| TLS coupling threshold (strongly coupled) | >= 0.5 MHz | Mitigating losses paper |
| TLS linewidth (coherent) | ~70 kHz | Defect identification paper |
| TLS linewidth (dissipative) | Several MHz | Defect identification paper |
| TLS dipole moment (surface) | ~1.12 eA | TLS mapping paper |
| TLS dipole moment (max, SA) | 5 Debye | Statistics paper |
| T1 impact of resonant TLS | 60% reduction | Site-specific tuning paper |
| T2 impact of resonant TLS | 35% reduction | Site-specific tuning paper |
| Single-qubit error impact | 35x increase | Site-specific tuning paper |
| Electric field tuning sensitivity | ~4 MHz/V | Site-specific tuning paper |
| Typical T1 monitoring resolution | ~11 ms (FPGA) to minutes (conventional) | FPGA tracker / standard methods |
| Cosmic ray TLS scrambling rate | ~1/592 seconds | Cosmic ray correlation paper |
| Loss tangent of amorphous oxides | mid 10^{-4} to mid 10^{-3} | Resonator analysis papers |

---

## 12. Open Questions and Research Gaps

1. **No published TLS forecasting algorithm exists.** Google's approach is proprietary. The methods proposed here are reconstructions based on available physics and data.

2. **Fast TLS switching (10 Hz regime) is newly discovered.** Forecasting methods must account for this multi-timescale behavior.

3. **Radiation-induced TLS scrambling is fundamentally unpredictable.** The best strategy is to detect scrambling events quickly and re-characterize.

4. **TLS-TLS interactions create correlated behavior.** Current models treat TLS independently; incorporating interaction effects could improve predictions.

5. **Scaling to hundreds/thousands of qubits** requires efficient parameterization of the TLS landscape and fast frequency reallocation algorithms.

6. **The connection between fabrication parameters and TLS properties** remains empirical. First-principles prediction of TLS populations is in its infancy (lattice-renormalized models, 2025).

7. **Active TLS management** (voltage biasing) is promising but not yet demonstrated at scale in a processor.

---

## Complete Reference List

### TLS Physics and Coupling
1. [Two-level systems from trapped quasiparticles - Science Advances](https://www.science.org/doi/10.1126/sciadv.abc5055)
2. [Identification of different types of high-frequency defects - PRX Quantum](https://ar5iv.labs.arxiv.org/html/2112.05391)
3. [Electric field spectroscopy of material defects - npj Quantum Information](https://www.nature.com/articles/s41534-019-0224-1)
4. [Mapping TLS positions on transmon qubits](https://arxiv.org/html/2511.05365v2)
5. [Mitigating losses from strongly coupled defect modes](https://arxiv.org/html/2407.18746v1)
6. [Statistics of strongly coupled defects](https://arxiv.org/html/2506.00193v1)
7. [Observation of directly interacting coherent TLS - Nature Communications](https://www.nature.com/articles/ncomms7182)

### TLS Temporal Dynamics
8. [Klimov et al. - Fluctuations of energy-relaxation times - PRL 2018](https://link.aps.org/doi/10.1103/PhysRevLett.121.090502)
9. [Google blog - Understanding performance fluctuations](http://ai.googleblog.com/2018/08/understanding-performance-fluctuations.html)
10. [Dynamics of superconducting qubit relaxation times - npj Quantum Information](https://www.nature.com/articles/s41534-022-00643-y)
11. [Real-time adaptive tracking of fluctuating relaxation rates - PRX 2026](https://arxiv.org/html/2506.09576)
12. [TLS dynamics due to background ionizing radiation - PRX Quantum](https://arxiv.org/abs/2210.04780)
13. [TLS spectroscopy from correlated multilevel relaxation (2026)](https://arxiv.org/html/2602.11127v1)

### TLS Spectroscopy
14. [Two-tone spectroscopy for TLS detection](https://arxiv.org/html/2404.14039)
15. [Scalable site-specific TLS frequency tuning](https://arxiv.org/html/2503.04702v1)
16. [Enhancing coherence with electric fields - npj Quantum Information](https://www.nature.com/articles/s41534-023-00678-9)

### TLS Models
17. [Generalized tunneling model for TLS](https://arxiv.org/abs/1404.2410)
18. [Thermal cycling evidence for GTM](https://arxiv.org/html/2410.19930)
19. [Lattice-renormalized tunneling models](https://arxiv.org/abs/2512.18156)
20. [Interacting two-level defects as noise sources - PRB 2015](https://arxiv.org/abs/1503.01637)
21. [Quantum sensors for microscopic tunneling systems - npj Quantum Information](https://www.nature.com/articles/s41534-020-00359-x)

### Google Willow and Processor Calibration
22. [Quantum error correction below the surface code threshold - Nature 2024](https://www.nature.com/articles/s41586-024-08449-y)
23. [Willow spec sheet](https://quantumai.google/static/site-assets/downloads/willow-spec-sheet.pdf)
24. [Optimizing quantum gates towards the scale of logical qubits - Nature Communications 2024](https://www.nature.com/articles/s41467-024-46623-y)
25. [Neural network-based frequency optimization](https://arxiv.org/html/2412.01183)
26. [Google Quantum AI Quest for error-corrected computers](https://arxiv.org/html/2410.00917v1)

### Drift Detection and Calibration
27. [ReloQate: Transient drift detection in surface code QEC](https://arxiv.org/abs/2603.00837)
28. [Fast-feedback calibration protocols](https://arxiv.org/html/2512.07815)
29. [Detecting and tracking drift in quantum processors - Nature Communications](https://www.nature.com/articles/s41467-020-19074-4)
30. [Real-time calibration with spectator qubits - npj Quantum Information](https://www.nature.com/articles/s41534-020-0251-y)
31. [Adaptive estimation of drifting noise in QEC](https://arxiv.org/html/2511.09491)

### QEC and TLS Impact
32. [Suppressing quantum errors by scaling surface code - Nature 2022](https://www.nature.com/articles/s41586-022-05434-1)
33. [Cosmic rays and correlated errors in qubit arrays - Nature Communications](https://www.nature.com/articles/s41467-025-61385-x)

### Materials and Fabrication
34. [Low-loss tantalum films at room temperature - Comm. Materials](https://www.nature.com/articles/s43246-025-00897-x)
35. [Low-loss Al/Si/Al parallel plate capacitors - npj Quantum Information](https://www.nature.com/articles/s41534-025-00967-5)
36. [Mitigation of interfacial dielectric loss - npj Quantum Information](https://www.nature.com/articles/s41534-024-00868-z)
37. [Material matters in superconducting qubits](https://arxiv.org/pdf/2106.05919)

### ML and Prediction
38. [Machine learning for predictive estimation of qubit dynamics](https://www.semanticscholar.org/paper/Machine-Learning-for-Predictive-Estimation-of-Qubit-Gupta-Biercuk/6aed6208adbec275635126633ffed84560f41529)
39. [Q-fid: Quantum circuit fidelity improvement with LSTM](https://advanced.onlinelibrary.wiley.com/doi/full/10.1002/qute.202500022)

### Temperature Dependence
40. [Thermal and residual excited-state population in 3D transmon - PRL](https://link.aps.org/doi/10.1103/PhysRevLett.114.240501)
41. [Evaluating radiation impact on transmon qubits](https://link.springer.com/article/10.1140/epjqt/s40507-026-00490-2)
