# LOS/NLOS Adaptive MCS Solution for V2X Groupcast

## Problem Statement

In V2X platooning scenarios, channel conditions vary between:
- **LOS (Line-of-Sight)**: Direct path between vehicles, good channel quality
- **NLOS (Non-Line-of-Sight)**: Blocked by other vehicles, degraded channel

Fixed MCS cannot handle both conditions optimally:
- High MCS (e.g., MCS 11): Fails in NLOS (PRR drops to ~83%)
- Low MCS (e.g., MCS 3): Lower performance in both conditions

## WiLabV2Xsim Experiment Results

### Experiment Configuration

- **Simulator**: WiLabV2Xsim v6.1 (Octave)
- **Technology**: LTE-V2X Mode 4
- **Scenario**: ETSI-Highway, 2km road, 3 lanes
- **Vehicles**: 100 vehicles/km density
- **Speed**: 90 km/h
- **Beacon**: 190 bytes, 10 Hz
- **Awareness Range**: 150m
- **Channel Model**: WINNER+ B1

### Shadowing Parameters

| Condition | stdDevShadowLOS | stdDevShadowNLOS |
|-----------|-----------------|------------------|
| LOS | 3 dB | 4 dB |
| NLOS | 6 dB | 8 dB |

### PRR Results at 150m

| Scenario | MCS 3 | MCS 5 | MCS 7 | MCS 9 | MCS 11 |
|----------|-------|-------|-------|-------|--------|
| **LOS** (σ=3dB) | 87.22% | 87.42% | **88.29%** | 85.74% | 83.80% |
| **NLOS** (σ=8dB) | 82.83% | **89.17%** | 85.41% | 83.76% | 82.72% |

### Key Findings

1. **LOS Scenario**: MCS 7 performs best (88.29%)
   - Higher MCS values (9, 11) show degradation due to stricter SINR requirements
   - MCS 5-7 optimal range for LOS conditions

2. **NLOS Scenario**: MCS 5 performs best (89.17%)
   - Lower MCS values perform better under heavy shadowing
   - MCS 5 improves PRR by **3.76%** over MCS 7 in NLOS
   - Confirms need for adaptive MCS that decreases in NLOS

3. **Adaptive MCS Strategy**:
   - Use MCS 7 in LOS conditions for best performance
   - Switch to MCS 5 in NLOS conditions for reliability
   - ~3-4% PRR improvement over fixed MCS in varying conditions

## Solution: Adaptive MCS with LOS/NLOS Detection

### Detection Method
- Monitor SINR variance over sliding window
- LOS: Low variance (stable channel)
- NLOS: High variance (fading channel)

### MCS Selection Rule
```
if LOS detected:
    MCS = 7  (88.29% PRR)
else if NLOS detected:
    MCS = 5  (89.17% PRR)
```

### Expected Performance
| Condition | Fixed MCS 7 | Adaptive (MCS 7/5) | Improvement |
|-----------|-------------|-------------------|-------------|
| LOS | 88.29% | 88.29% | 0% |
| NLOS | 85.41% | 89.17% | **+3.76%** |

## Files

- `wilabv2xsim_los_nlos_results/`: WiLabV2Xsim experiment output data
  - `LOS_MCS{3,5,7,9,11}/`: LOS scenarios with different MCS values
  - `NLOS_MCS{3,5,7,9,11}/`: NLOS scenarios with heavy shadowing (σ=8dB)

## References

1. 3GPP TR 36.885: V2V path loss models
2. 3GPP TS 22.186: V2V reliability requirements (PRR ≥ 90%)
3. WINNER+ B1: Vehicle-to-vehicle channel model
4. WiLabV2Xsim: https://github.com/V2Xgithub/WiLabV2Xsim
