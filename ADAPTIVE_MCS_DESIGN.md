# Groupcast MCS - Algorithm Design

## Overview
This document describes the design of adaptive MCS (Modulation and Coding Scheme) algorithms for groupcast communication in platooning scenarios, with scientific justification for all parameters.

## 1. MCS Adjustment Algorithms

### 1.1 Fixed MCS (Baseline)
- **Description**: Static MCS throughout the simulation
- **MCS Value**: MCS 9 (16-QAM, code rate 1/2)
- **Justification**:
  - According to 3GPP TS 36.213, MCS 9 provides balanced throughput and reliability
  - Typical for V2V communications at medium distances (50-150m) [1]
  - Spectral efficiency: 2.4063 bits/symbol [3GPP TS 36.213 Table 8.6.1-1]

### 1.2 BLER-based Adaptive MCS
- **Description**: Adjusts MCS based on Block Error Rate feedback (NAK/ACK)
- **Algorithm**:
  ```
  if (BLER > BLER_HIGH_THRESHOLD):
      MCS = max(MCS - MCS_STEP_DOWN, MCS_MIN)
  elif (BLER < BLER_LOW_THRESHOLD):
      MCS = min(MCS + MCS_STEP_UP, MCS_MAX)
  ```

- **Parameters**:
  - `BLER_HIGH_THRESHOLD = 0.1 (10%)`
    - **Justification**: 3GPP TS 22.186 specifies PSSCH BLER target of 10% for V2V [2]
    - ETSI TS 103 324 V2V QoS requirements: <10% packet error rate

  - `BLER_LOW_THRESHOLD = 0.01 (1%)`
    - **Justification**: Indicates excellent channel conditions with margin for MCS increase
    - Conservative approach: 10x safety margin below target BLER

  - `MCS_STEP_DOWN = 2`
    - **Justification**: Aggressive reduction to quickly adapt to degrading channel
    - IEEE 802.11p rate adaptation studies show 2-step reduction effective [3]

  - `MCS_STEP_UP = 1`
    - **Justification**: Conservative increase to avoid oscillation
    - Standard practice in link adaptation (e.g., Minstrel algorithm) [4]

  - `MCS_MIN = 0` (QPSK 1/5)
    - **Justification**: Most robust MCS in LTE, ensures connectivity

  - `MCS_MAX = 20` (64-QAM 3/4)
    - **Justification**: 3GPP TS 36.213 maximum MCS for high SINR conditions
    - Practical limit for vehicular channels with high Doppler

  - `BLER_WINDOW_SIZE = 100 packets`
    - **Justification**:
      - At 10 Hz beacon rate (typical CAM frequency per ETSI EN 302 637-2)
      - Window = 10 seconds, balancing responsiveness and stability
      - Sufficient samples for statistical significance (n>30)

### 1.3 SINR-based Adaptive MCS
- **Description**: Adjusts MCS based on measured SINR
- **Algorithm**:
  ```
  MCS = lookup_table(average_SINR)
  ```

- **SINR-to-MCS Mapping** (based on 3GPP TR 36.942 and empirical studies [5]):
  ```
  SINR (dB)  | MCS | Modulation | Code Rate | Justification
  -----------|-----|------------|-----------|---------------
  < -5       |  0  | QPSK       | 1/5       | Min sensitivity
  -5 to 0    |  2  | QPSK       | 1/3       | Low SINR region
  0 to 5     |  5  | QPSK       | 2/3       | Moderate SINR
  5 to 10    |  9  | 16-QAM     | 1/2       | Good SINR
  10 to 15   | 14  | 16-QAM     | 3/4       | High SINR
  15 to 20   | 17  | 64-QAM     | 1/2       | Very high SINR
  > 20       | 20  | 64-QAM     | 3/4       | Excellent SINR
  ```
  - **Justification**: Derived from link-level simulations in 3GPP TR 36.942
  - Target BLER = 10% at each SINR point

- **SINR_WINDOW_SIZE = 50 measurements**
  - **Justification**:
    - At 1ms subframe duration, window = 50ms
    - Covers multiple fading periods (coherence time ~10ms at 60 km/h)
    - Fast enough to track channel variations in vehicular environment

### 1.4 Hybrid Adaptive MCS
- **Description**: Combines SINR prediction with BLER feedback
- **Algorithm**:
  ```
  MCS_predicted = lookup_table(average_SINR)
  if (BLER > BLER_HIGH_THRESHOLD):
      MCS_actual = max(MCS_predicted - PENALTY, MCS_MIN)
  elif (BLER < BLER_LOW_THRESHOLD and MCS_current < MCS_predicted):
      MCS_actual = min(MCS_current + 1, MCS_predicted)
  else:
      MCS_actual = MCS_predicted
  ```

- **Parameters**:
  - `PENALTY = 3`
    - **Justification**: Significant reduction when prediction fails
    - Compensates for SINR estimation errors in high-mobility scenarios

  - Uses same thresholds as BLER-based and SINR-based algorithms

## 2. NLOS Parameters

### 2.1 Number of Blocking Vehicles (N_blocking)
- **Range**: 0 to 5 vehicles
- **Justification**:
  - Platooning typically involves 3-8 vehicles [ETSI TR 103 299]
  - N_blocking ∈ {0, 1, 2, 3, 4, 5} covers realistic scenarios
  - N_blocking = 0: LOS (baseline)
  - N_blocking ≥ 1: NLOS (increasing severity)

### 2.2 Additional Path Loss due to Vehicle Blocking
```
PL_NLOS(N_blocking) = PL_LOS + α * N_blocking + β
```

- **Parameters** (based on [6] - WINNER+ B1 V2V model):
  - `α = 3 dB per vehicle`
    - **Justification**: Empirical measurements show 2-5 dB additional loss per vehicle
    - Conservative median value from [6, 7]

  - `β = 5 dB (base NLOS penalty)`
    - **Justification**: Accounts for first diffraction loss
    - Consistent with ITU-R M.2135 urban micro-cell NLOS model

  - `PL_LOS`: Standard V2V path loss model (3GPP TR 36.885)
    ```
    PL_LOS(d) = 38.77 + 16.7 * log10(d) + 18.2 * log10(fc)
    ```
    - d: distance in meters
    - fc: carrier frequency in GHz (5.9 GHz for V2V)

### 2.3 Impact on SINR
```
SINR_NLOS = P_tx - PL_NLOS(N_blocking) - N0 - I
```
- Where:
  - `P_tx = 23 dBm` (max power for V2V per ETSI EN 302 571)
  - `N0 = -95 dBm` (thermal noise in 10 MHz bandwidth at 9 dB noise figure)
  - `I`: interference from other vehicles (scenario-dependent)

## 3. Platooning Scenario Parameters

### 3.1 Vehicle Configuration
- **Number of vehicles (N_vehicles)**: 5
  - **Justification**: Typical platoon size in research and pilots [8]
  - Manageable for groupcast without excessive overhead

- **Initial spacing (d_init)**: 15 meters
  - **Justification**:
    - Safe distance at highway speeds per SAE J3216
    - Time headway ~0.6s at 25 m/s (90 km/h)

- **Target spacing (d_target)**: 5 meters
  - **Justification**:
    - Target for automated platooning [ETSI TR 103 299]
    - Achieves fuel savings (15-20% reduction in drag) [9]

### 3.2 Velocity Profile (Convergence Scenario)
```
v_i(t) = v_base + Δv_i
```
- **Base velocity (v_base)**: 90 km/h (25 m/s)
  - **Justification**: Typical highway cruising speed [10]

- **Velocity differential (Δv_i)**:
  - Leader (i=0): 0 m/s (constant speed)
  - Follower i: `(i) * 0.5 m/s` (rear vehicles faster)
  - **Justification**:
    - Creates gradual convergence
    - Realistic for platoon formation phase
    - 0.5 m/s chosen to achieve spacing reduction in 20 seconds: Δd = Δv * t = 0.5 * 20 = 10 meters

### 3.3 Communication Parameters
- **Beacon frequency**: 10 Hz
  - **Justification**: ETSI EN 302 637-2 CAM transmission frequency for platooning

- **Packet size**: 300 bytes
  - **Justification**:
    - Typical CAM size: 100-300 bytes [ETSI EN 302 637-2]
    - Includes position, velocity, acceleration, heading

- **Carrier frequency**: 5.9 GHz
  - **Justification**: ITS-G5 band (ETSI EN 302 571)

- **Bandwidth**: 10 MHz
  - **Justification**: Standard ITS channel bandwidth

## 4. Simulation Parameters

### 4.1 Duration and Resolution
- **Simulation time**: 30 seconds
  - **Justification**:
    - Covers platoon formation phase (0-20s) and steady state (20-30s)
    - Sufficient for statistical analysis (300 beacon intervals)

- **Time step**: 1 ms
  - **Justification**: LTE subframe duration

### 4.2 Channel Model
- **Model**: 3GPP TR 36.885 V2V Urban
  - **Justification**: Standard model for V2V simulations

- **Doppler frequency**: 518 Hz at 5.9 GHz, 90 km/h
  - **Justification**: f_d = v * f_c / c = 25 * 5.9e9 / 3e8

- **Coherence time**: ~10 ms
  - **Justification**: T_c ≈ 1 / (2 * f_d) ≈ 1 / 1036 ≈ 0.001s

## 5. Performance Metrics

### 5.1 Packet Reception Ratio (PRR)
- **Target**: PRR > 90% (BLER < 10%)
- **Justification**: 3GPP TS 22.186 V2V reliability requirement

### 5.2 Throughput
- **Metric**: Average data rate (kbps) per vehicle
- **Justification**: Indicates spectrum efficiency

### 5.3 MCS Stability
- **Metric**: MCS change frequency (changes per second)
- **Justification**: Frequent changes indicate oscillation, undesirable

### 5.4 Latency (optional, for future work)
- **Target**: < 100 ms end-to-end
- **Justification**: ETSI TS 122 186 cooperative awareness latency requirement

## References

[1] 3GPP TS 36.213, "Physical layer procedures"
[2] 3GPP TS 22.186, "Enhancement of 3GPP support for V2X scenarios"
[3] Campolo et al., "Modeling IEEE 802.11p for vehicular communications," IEEE Commun. Letters, 2011
[4] Wong et al., "Robust rate adaptation for 802.11 wireless networks," MobiCom 2006
[5] 3GPP TR 36.942, "Radio Frequency (RF) system scenarios"
[6] WINNER+ Final Report, "D5.3: WINNER+ Final Channel Models"
[7] Karedal et al., "A geometry-based stochastic MIMO model for vehicle-to-vehicle communications," IEEE Trans. Wireless Commun., 2009
[8] Bergenhem et al., "Overview of platooning systems," ITS World Congress, 2012
[9] Alam et al., "Fuel-efficient heavy-duty vehicle platooning," ESV Conference, 2015
[10] ETSI TR 103 299, "Intelligent Transport Systems (ITS); Cooperative Adaptive Cruise Control (CACC)"
