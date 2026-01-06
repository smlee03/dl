# Groupcast MCS - Experiment Summary

## Objective

Compare adaptive MCS (Modulation and Coding Scheme) adjustment algorithms for V2V groupcast communication in platooning scenarios, with varying NLOS (Non-Line-of-Sight) severity.

## Research Questions

1. How do different MCS adaptation strategies perform under varying NLOS conditions?
2. What is the impact of blocking vehicles on groupcast reliability?
3. Which algorithm provides the best balance between reliability (PRR) and throughput?

## Experimental Design

### Algorithms Compared

| Algorithm | Description | Key Parameters |
|-----------|-------------|----------------|
| **Fixed** | Baseline with static MCS 9 | MCS = 9 (16-QAM 1/2) |
| **BLER-based** | Adapts based on Block Error Rate | BLER_high = 10%, BLER_low = 1% |
| **SINR-based** | Adapts based on SINR measurements | SINR-to-MCS mapping table |
| **Hybrid** | Combines SINR + BLER feedback | Penalty = 3 on prediction failure |

All parameters justified in `ADAPTIVE_MCS_DESIGN.md`.

### Independent Variables

1. **MCS Algorithm**: {Fixed, BLER-based, SINR-based, Hybrid}
2. **N_blocking**: {0, 1, 2, 3} vehicles blocking LOS
   - N_blocking = 0: Pure LOS scenario
   - N_blocking = 1-3: Increasing NLOS severity

### Dependent Variables (Metrics)

1. **Packet Reception Ratio (PRR)**: Percentage of successful transmissions
   - Target: >90% (3GPP TS 22.186)
2. **Throughput**: Average data rate in kbps
3. **MCS Stability**: Number of MCS changes (lower = more stable)
4. **Average MCS**: Mean MCS value during simulation

### Controlled Variables

| Parameter | Value | Standard/Reference |
|-----------|-------|-------------------|
| Simulation Duration | 30 s | Formation + steady state |
| Beacon Frequency | 10 Hz | ETSI EN 302 637-2 (CAM) |
| Number of Vehicles | 5 | ETSI TR 103 299 |
| Initial Spacing | 15 m | SAE J3216 (safe distance) |
| Target Spacing | 5 m | Automated platooning |
| Base Velocity | 90 km/h | Typical highway speed |
| Velocity Differential | 0.5 m/s | Δd = 10m in 20s |
| Carrier Frequency | 5.9 GHz | ETSI EN 302 571 (ITS-G5) |
| Transmit Power | 23 dBm | Max V2V power |
| Packet Size | 300 bytes | Typical CAM size |
| Monte Carlo Runs | 10 | Statistical significance |

### Channel Model

**LOS Path Loss** (3GPP TR 36.885):
```
PL_LOS(d) = 38.77 + 16.7*log10(d) + 18.2*log10(5.9)
```

**NLOS Additional Loss**:
```
PL_additional = 5 + 3*N_blocking (dB)
```
- 5 dB: Base NLOS penalty (ITU-R M.2135)
- 3 dB per vehicle: Empirical (WINNER+ B1 V2V)

**Shadowing**: Log-normal
- σ_LOS = 3 dB
- σ_NLOS = 4 dB

## Expected Results

### Hypothesis 1: PRR vs N_blocking

**Prediction**:
- Fixed MCS will degrade significantly with increasing N_blocking
- Adaptive algorithms will maintain ~90% PRR by reducing MCS
- Hybrid will perform best due to combined feedback

**Reasoning**: As path loss increases (more blocking vehicles), fixed MCS will exceed SINR threshold for reliable decoding. Adaptive algorithms compensate by selecting more robust (lower) MCS.

### Hypothesis 2: Throughput vs N_blocking

**Prediction**:
- Fixed MCS: High in LOS, drops sharply in NLOS (due to packet losses)
- BLER-based: Moderate but stable (conservative adaptation)
- SINR-based: Highest in LOS, aggressive reduction in NLOS
- Hybrid: Best overall efficiency

**Reasoning**: Trade-off between MCS level and reliability. Too high MCS → packet loss. Too low MCS → wasted spectral efficiency.

### Hypothesis 3: MCS Stability

**Prediction**:
- Fixed: 0 changes (by definition)
- SINR-based: Most changes (fast tracking of channel)
- BLER-based: Moderate changes (slower feedback loop)
- Hybrid: Moderate changes (damped by SINR prediction)

**Reasoning**: SINR varies due to shadowing/fading → frequent updates. BLER window smooths variations.

## Implementation

### WiLabV2Xsim-Inspired Simulator

- **MATLAB version**: Object-oriented implementation
  - `AdaptiveMCS.m`: MCS controllers
  - `NLOSModel.m`: Channel with vehicle blocking
  - `PlatooningScenario.m`: Vehicle dynamics

- **Python version**: NumPy/SciPy-based
  - `adaptive_mcs.py`: Core classes
  - `run_simulation.py`: Main script

### Validation

1. **BLER curves**: Match 3GPP TR 36.942 link-level simulations
2. **Path loss**: Agrees with 3GPP TR 36.885 V2V Urban
3. **Platooning dynamics**: Realistic convergence behavior

## How to Run Experiments

### Quick Start (Python)

```bash
./run_python.sh
```

### Quick Start (MATLAB)

```bash
./run_matlab.sh
```

### Custom Configuration

Edit parameters in:
- `python_simulation/run_simulation.py`
- `matlab_simulation/main_platooning_adaptive_mcs.m`

Example: Test extreme NLOS

```python
n_blocking_values = [0, 3, 5]  # LOS, moderate NLOS, severe NLOS
sim_params['n_runs'] = 20      # More statistical samples
```

## Data Analysis

### Automated Plots

Both MATLAB and Python versions generate:

1. **Line Plots**: PRR, Throughput, MCS Changes vs N_blocking
2. **Heatmaps**: Performance across all algorithm-NLOS combinations
3. **Bar Charts**: Per-scenario comparison

### Statistical Analysis

- Mean ± Std Dev across Monte Carlo runs
- 95% confidence intervals (can be added)
- ANOVA for algorithm comparison (can be added)

### Example Interpretation

**Scenario: N_blocking = 2**

| Algorithm | PRR | Throughput | MCS Changes |
|-----------|-----|------------|-------------|
| Fixed | 65% | 800 kbps | 0 |
| BLER | 92% | 600 kbps | 15 |
| SINR | 88% | 650 kbps | 25 |
| Hybrid | 93% | 680 kbps | 18 |

**Interpretation**:
- Fixed fails (PRR < 90%) → MCS too high for channel conditions
- BLER achieves target PRR but conservative (lower throughput)
- SINR slightly below target, more oscillations
- Hybrid best: meets PRR target with highest throughput among adaptive

## Extensions

### Future Work

1. **More algorithms**:
   - Reinforcement learning-based MCS
   - Multi-agent coordination
   - Predictive algorithms using vehicle trajectory

2. **Additional metrics**:
   - Latency (end-to-end delay)
   - Inter-vehicle spacing accuracy
   - Fuel consumption (via drag reduction)

3. **Advanced scenarios**:
   - Highway merging
   - Mixed LOS/NLOS (urban canyons)
   - Dynamic platoon size

4. **Real-world validation**:
   - Compare with WiLabV2Xsim
   - Validate against field trials
   - OTA (Over-The-Air) testing

## No Magic Numbers - Parameter Justification

Every numerical value is justified:

| Parameter | Value | Justification |
|-----------|-------|---------------|
| BLER_HIGH = 10% | 0.1 | 3GPP TS 22.186 PSSCH target |
| BLER_LOW = 1% | 0.01 | 10x safety margin |
| MCS_STEP_DOWN = 2 | 2 | IEEE 802.11p rate adaptation |
| MCS_STEP_UP = 1 | 1 | Conservative (Minstrel) |
| ALPHA = 3 dB | 3 | WINNER+ B1 (2-5 dB range) |
| BETA = 5 dB | 5 | ITU-R M.2135 NLOS penalty |
| N_VEHICLES = 5 | 5 | ETSI TR 103 299 typical platoon |
| TARGET_SPACING = 5m | 5 | 15-20% fuel savings |
| ... | ... | See ADAPTIVE_MCS_DESIGN.md |

## Reproducibility

### Software Versions

- MATLAB: R2018b or later
- Python: 3.7+
- NumPy: >= 1.19.0
- SciPy: >= 1.5.0
- Matplotlib: >= 3.3.0

### Random Seed

For reproducible results, set seed in:

```python
# Python
np.random.seed(42)
```

```matlab
% MATLAB
rng(42);
```

### Data Archival

- Raw results: JSON (Python) or .mat (MATLAB)
- Plots: PNG (high-res, 300 dpi)
- Git hash: Commit ID for exact code version

## References

See `ADAPTIVE_MCS_DESIGN.md` for complete list of 10+ references including:
- 3GPP standards (TS 36.213, 22.186, TR 36.885, 36.942)
- ETSI specifications (EN 302 637-2, 302 571, TR 103 299)
- Channel models (WINNER+, ITU-R M.2135)
- Platooning research literature

## Contact

For questions about the experiment:
1. Check README.md
2. Review ADAPTIVE_MCS_DESIGN.md
3. Open issue on GitHub
