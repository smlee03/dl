# Adaptive MCS for Platooning Groupcast

Adaptive Modulation and Coding Scheme (MCS) algorithms for V2V groupcast communication in platooning scenarios, with NLOS parameter for blocking vehicles.

## Overview

This project implements and compares four MCS adjustment algorithms for vehicular platooning scenarios:

1. **Fixed MCS**: Baseline with static MCS (MCS 9: 16-QAM 1/2)
2. **BLER-based Adaptive MCS**: Adjusts based on Block Error Rate feedback (NAK/ACK)
3. **SINR-based Adaptive MCS**: Adjusts based on measured Signal-to-Interference-plus-Noise Ratio
4. **Hybrid Adaptive MCS**: Combines SINR prediction with BLER feedback

### Key Features

- **Scientifically Justified Parameters**: All numerical values are backed by 3GPP standards, ETSI specifications, or peer-reviewed research
- **NLOS Modeling**: Parameterized number of blocking vehicles (0-5) affecting path loss
- **Platooning Scenario**: Realistic vehicle convergence scenario with velocity differentials
- **WiLabV2Xsim-inspired**: Based on WiLabV2Xsim simulator principles
- **Dual Implementation**: Both MATLAB and Python versions available

## Scientific Justification

All parameters are documented with scientific references in `ADAPTIVE_MCS_DESIGN.md`. Key standards:

- **3GPP TS 36.213**: MCS table and spectral efficiency
- **3GPP TS 22.186**: V2V reliability requirements (10% BLER target)
- **3GPP TR 36.885**: V2V path loss model
- **ETSI EN 302 637-2**: CAM transmission frequency (10 Hz)
- **ETSI TR 103 299**: Platooning parameters
- **WINNER+ B1**: Vehicle blocking path loss model

### Example: No Magic Numbers

```python
# ❌ BAD - Magic number
BLER_THRESHOLD = 0.1

# ✅ GOOD - Justified parameter
BLER_HIGH_THRESHOLD = 0.1   # 10% - 3GPP TS 22.186 PSSCH BLER target for V2V
                            # ETSI TS 103 324 V2V QoS: <10% packet error rate
```

## Directory Structure

```
.
├── ADAPTIVE_MCS_DESIGN.md          # Complete parameter justification
├── README.md                        # This file
├── matlab_simulation/               # MATLAB implementation
│   ├── core/
│   │   └── AdaptiveMCS.m           # MCS adjustment algorithms
│   ├── scenarios/
│   │   └── PlatooningScenario.m    # Platooning scenario configuration
│   ├── channel_models/
│   │   └── NLOSModel.m             # NLOS channel with vehicle blocking
│   ├── utils/
│   │   └── plotComparison.m        # Result visualization
│   ├── main_platooning_adaptive_mcs.m  # Main simulation script
│   └── results/                    # Output directory
└── python_simulation/               # Python implementation
    ├── adaptive_mcs.py              # Core classes
    ├── run_simulation.py            # Main simulation script
    ├── requirements.txt             # Python dependencies
    └── results_*/                   # Output directories
```

## Installation

### MATLAB Version

Requirements:
- MATLAB R2018b or later
- Statistics and Machine Learning Toolbox (for `erfc`)

No installation needed - just clone and run.

### Python Version

Requirements:
- Python 3.7+
- NumPy
- SciPy
- Matplotlib

Install dependencies:

```bash
cd python_simulation
pip install -r requirements.txt
```

## Usage

### MATLAB

```matlab
cd matlab_simulation
main_platooning_adaptive_mcs
```

This will:
1. Run all 4 algorithms across 4 NLOS scenarios (N_blocking = 0, 1, 2, 3)
2. Perform 10 Monte Carlo runs per configuration
3. Generate comparison plots
4. Save results to `results/results_YYYYMMDD_HHMMSS.mat`

### Python

```bash
cd python_simulation
python run_simulation.py
```

This will:
1. Run all 4 algorithms across 4 NLOS scenarios
2. Perform 10 Monte Carlo runs per configuration
3. Generate comparison plots
4. Save results to `results_YYYYMMDD_HHMMSS/results.json`

## Simulation Parameters

All parameters are scientifically justified. Key parameters:

| Parameter | Value | Justification |
|-----------|-------|---------------|
| Simulation Duration | 30 s | Covers formation (0-20s) and steady state (20-30s) |
| Time Step | 1 ms | LTE subframe duration |
| Beacon Frequency | 10 Hz | ETSI EN 302 637-2 CAM frequency for platooning |
| Number of Vehicles | 5 | Typical platoon size (ETSI TR 103 299) |
| Initial Spacing | 15 m | Safe distance at 90 km/h (SAE J3216) |
| Target Spacing | 5 m | Automated platooning target (15-20% fuel savings) |
| Velocity Differential | 0.5 m/s | Achieves 10m spacing reduction in 20s |
| Carrier Frequency | 5.9 GHz | ITS-G5 band (ETSI EN 302 571) |
| Transmit Power | 23 dBm | Max V2V power (ETSI EN 302 571) |
| BLER Target | 10% | 3GPP TS 22.186 V2V reliability requirement |

### NLOS Parameters

| N_blocking | Description | Additional Path Loss |
|------------|-------------|---------------------|
| 0 | LOS (Line-of-Sight) | 0 dB |
| 1 | 1 vehicle blocking | 8 dB (5 + 3×1) |
| 2 | 2 vehicles blocking | 11 dB (5 + 3×2) |
| 3 | 3 vehicles blocking | 14 dB (5 + 3×3) |

Formula: `PL_NLOS = PL_LOS + 5 + 3×N_blocking`
- 5 dB: Base NLOS penalty (ITU-R M.2135)
- 3 dB per vehicle: Empirical measurements (WINNER+ B1 V2V model)

## Performance Metrics

1. **Packet Reception Ratio (PRR)**: Percentage of successfully received packets
   - Target: >90% (3GPP TS 22.186)

2. **Throughput**: Average data rate in kbps
   - Indicates spectrum efficiency

3. **MCS Stability**: Number of MCS changes during simulation
   - Lower is better (indicates stable operation)

4. **Average MCS**: Mean MCS value during simulation
   - Higher generally means better channel conditions

## Expected Results

### PRR vs N_blocking

- **Fixed MCS**: Degrades significantly with increasing NLOS
- **BLER-based**: Maintains target PRR by reducing MCS
- **SINR-based**: Fast adaptation but may overshoot
- **Hybrid**: Best balance of reliability and throughput

### Throughput vs N_blocking

- **Fixed MCS**: High in LOS, fails in NLOS
- **BLER-based**: Moderate, stable across conditions
- **SINR-based**: High in good conditions, aggressive reduction in NLOS
- **Hybrid**: Optimizes throughput while maintaining reliability

## Output Files

### MATLAB

- `results/results_YYYYMMDD_HHMMSS.mat`: All simulation results
- `results/comparison_vs_nlos_YYYYMMDD_HHMMSS.png`: Line plots
- `results/comparison_bars_YYYYMMDD_HHMMSS.png`: Bar charts
- `results/heatmaps_YYYYMMDD_HHMMSS.png`: Heatmaps

### Python

- `results_YYYYMMDD_HHMMSS/results.json`: All simulation results
- `results_YYYYMMDD_HHMMSS/comparison_vs_nlos.png`: Line plots
- `results_YYYYMMDD_HHMMSS/heatmaps.png`: Heatmaps

## Customization

### Changing NLOS Scenarios

Edit the `N_BLOCKING_VALUES` in the main script:

```matlab
% MATLAB
N_BLOCKING_VALUES = [0, 1, 2, 3, 4, 5];  % Test all scenarios
```

```python
# Python
n_blocking_values = [0, 1, 2, 3, 4, 5]
```

### Adjusting MCS Algorithm Parameters

Edit `AdaptiveMCS.m` (MATLAB) or `adaptive_mcs.py` (Python):

```python
# Example: Change BLER thresholds
BLER_HIGH_THRESHOLD = 0.15  # 15% instead of 10%
BLER_LOW_THRESHOLD = 0.02   # 2% instead of 1%

# Remember to document your justification!
```

### Changing Platooning Scenario

Edit `PlatooningScenario.m` or `PlatooningScenario` class:

```python
# Example: Larger platoon
N_VEHICLES = 8  # Instead of 5

# Closer target spacing (more aggressive)
TARGET_SPACING_M = 3.0  # Instead of 5.0
```

## Validation

The simulator has been validated against:

1. **3GPP link-level curves**: BLER vs SINR matches 3GPP TR 36.942
2. **Path loss models**: Agrees with 3GPP TR 36.885 V2V Urban
3. **Platooning dynamics**: Realistic convergence behavior

## Troubleshooting

### MATLAB: "Function 'erfc' not found"

Install Statistics and Machine Learning Toolbox, or replace with:
```matlab
bler = 0.5 * (1 - erf((sinr - threshold) / (sigma * sqrt(2))));
```

### Python: "ModuleNotFoundError: No module named 'scipy'"

Install dependencies:
```bash
pip install -r requirements.txt
```

### Low PRR for all algorithms

- Check SINR values (may be too low due to path loss)
- Reduce N_blocking or increase transmit power
- Verify MCS adjustment is working (check MCS history)

## Citation

If you use this code in your research, please cite:

```bibtex
@software{adaptive_mcs_platooning,
  title = {Adaptive MCS for Platooning Groupcast},
  author = {Your Name},
  year = {2026},
  note = {GitHub repository},
  url = {https://github.com/yourusername/yourrepo}
}
```

## References

1. 3GPP TS 36.213, "Physical layer procedures"
2. 3GPP TS 22.186, "Enhancement of 3GPP support for V2X scenarios"
3. 3GPP TR 36.885, "Study on LTE-based V2X Services"
4. 3GPP TR 36.942, "Radio Frequency (RF) system scenarios"
5. ETSI EN 302 637-2, "Intelligent Transport Systems - Cooperative Awareness Messages"
6. ETSI EN 302 571, "Intelligent Transport Systems - Radiocommunications equipment"
7. ETSI TR 103 299, "Intelligent Transport Systems - Cooperative Adaptive Cruise Control"
8. WINNER+ Final Report, "D5.3: WINNER+ Final Channel Models"
9. SAE J3216, "Taxonomy and Definitions for Terms Related to Driving Automation"
10. ITU-R M.2135, "Guidelines for evaluation of radio interface technologies"

## License

MIT License - See LICENSE file for details

## Contact

For questions or issues, please open an issue on GitHub.
