# WiLabV2Xsim MCS Comparison Results

## Experiment Configuration

- **Simulator**: WiLabV2Xsim v6.1 (Octave version)
- **Technology**: LTE-V2X (C-V2X Mode 4)
- **Scenario**: ETSI Highway (3-lane, 2 km)
- **Vehicle Density**: 100 vehicles/km
- **Speed**: 90 km/h
- **Beacon Size**: 190 bytes (CAM)
- **Beacon Rate**: 10 Hz
- **Bandwidth**: 10 MHz
- **Simulation Time**: 5 seconds

## MCS Comparison Results

### PRR vs Distance (0-150m Range)

| Distance | MCS 3 (QPSK) | MCS 7 (16-QAM) | MCS 11 (16-QAM) |
|----------|--------------|----------------|-----------------|
| 10m      | 99.56%       | 99.12%         | 98.56%          |
| 50m      | 96.97%       | 96.36%         | 95.16%          |
| 100m     | 92.21%       | 92.15%         | 90.11%          |
| 150m     | 86.82%       | 86.76%         | 83.34%          |

### Average PRR in Range 0-150m

| MCS | Modulation | PRR (0-150m) | Error Rate |
|-----|------------|--------------|------------|
| 3   | QPSK       | **93.76%**   | 6.24%      |
| 7   | 16-QAM     | **93.21%**   | 6.79%      |
| 11  | 16-QAM     | **91.05%**   | 8.95%      |

## Key Findings

1. **MCS 3 (Most Robust)**: Highest PRR across all distances due to lower-order modulation (QPSK)
   - Best for safety-critical platooning communications
   - Lower throughput but more reliable

2. **MCS 7 (Balanced)**: Good balance between reliability and throughput
   - Slightly lower PRR than MCS 3 but within acceptable range
   - Suitable for general V2X communications

3. **MCS 11 (Higher Throughput)**: Lower PRR especially at longer distances
   - 3-4% lower PRR compared to MCS 3 at 150m
   - Higher throughput but less robust against channel degradation

## Recommendations for Platooning

For groupcast communication in platooning scenarios:

- **Close Range (< 50m)**: MCS 7-11 acceptable (PRR > 95%)
- **Medium Range (50-100m)**: MCS 3-7 recommended (PRR > 90%)
- **Extended Range (100-150m)**: MCS 3 preferred for reliability

## Adaptive MCS Justification

These results support the need for adaptive MCS algorithms:
- Use higher MCS (11+) when vehicles are close (high SINR)
- Fall back to lower MCS (3-7) as distance increases or channel degrades
- BLER-based adaptation can maintain >90% PRR target by dynamically adjusting MCS

## Files

- `WiLabV2Xsim/Output/MCS3/`: MCS 3 simulation results
- `WiLabV2Xsim/Output/MCS7/`: MCS 7 simulation results
- `WiLabV2Xsim/Output/MCS11/`: MCS 11 simulation results
