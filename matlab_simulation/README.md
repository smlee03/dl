# MATLAB Simulation - Adaptive MCS for Platooning

## Quick Start

```matlab
% Run from MATLAB command window
cd matlab_simulation
main_platooning_adaptive_mcs
```

## Requirements

- MATLAB R2018b or later
- Statistics and Machine Learning Toolbox (for `erfc` function)

## File Descriptions

### Core Classes

- **`core/AdaptiveMCS.m`**: Implements 4 MCS adjustment algorithms
  - Fixed MCS (baseline)
  - BLER-based adaptive MCS
  - SINR-based adaptive MCS
  - Hybrid adaptive MCS

### Scenario

- **`scenarios/PlatooningScenario.m`**: Vehicle platooning simulation
  - 5-vehicle platoon
  - Convergence from 15m to 5m spacing
  - Simple proportional controller

### Channel Model

- **`channel_models/NLOSModel.m`**: NLOS channel with vehicle blocking
  - 3GPP TR 36.885 V2V path loss model
  - WINNER+ B1 vehicle blocking model
  - Configurable N_blocking (0-5 vehicles)

### Utilities

- **`utils/plotComparison.m`**: Generate comparison plots
  - PRR vs N_blocking
  - Throughput vs N_blocking
  - MCS stability analysis
  - Heatmaps

### Main Script

- **`main_platooning_adaptive_mcs.m`**: Run all experiments
  - 4 algorithms × 4 NLOS scenarios × 10 Monte Carlo runs
  - Automated result collection and plotting

## Customization

### Modify Simulation Duration

```matlab
% In main_platooning_adaptive_mcs.m
SIM_DURATION_S = 60;  % Change to 60 seconds
```

### Add More Algorithms

1. Add new algorithm to `AdaptiveMCS.m`:
```matlab
function mcs = updateMyAlgorithm(obj, time, sinr, ack_received)
    % Your algorithm implementation
end
```

2. Update main script:
```matlab
ALGORITHMS = {'fixed', 'bler', 'sinr', 'hybrid', 'my_algorithm'};
```

### Change Vehicle Parameters

```matlab
% In scenarios/PlatooningScenario.m
N_VEHICLES = 8;                 % Larger platoon
TARGET_SPACING_M = 3;           % Tighter spacing
VELOCITY_DIFFERENTIAL_MS = 1.0; % Faster convergence
```

## Output

Results are saved in `results/` directory with timestamp:

- `results_YYYYMMDD_HHMMSS.mat`: Complete simulation data
- `comparison_vs_nlos_YYYYMMDD_HHMMSS.png`: Line plots
- `comparison_bars_YYYYMMDD_HHMMSS.png`: Bar charts per scenario
- `heatmaps_YYYYMMDD_HHMMSS.png`: Performance heatmaps

## Troubleshooting

### Error: "Undefined function 'erfc'"

Solution 1: Install Statistics and Machine Learning Toolbox

Solution 2: Replace in `NLOSModel.m`:
```matlab
% Replace:
bler = 0.5 * erfc((sinr - threshold) / sigma);

% With:
bler = 0.5 * (1 - erf((sinr - threshold) / (sigma * sqrt(2))));
```

### Error: "Out of memory"

Reduce Monte Carlo runs:
```matlab
N_RUNS = 5;  % Instead of 10
```

## Performance Tips

- Use parallel computing:
```matlab
parfor run = 1:N_RUNS
    % Simulation code
end
```

- Reduce time resolution:
```matlab
TIME_STEP_MS = 10;  % 10ms instead of 1ms
```
