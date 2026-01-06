# Groupcast MCS - Python Simulation

## Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# Run simulation
python run_simulation.py
```

## Requirements

- Python 3.7+
- NumPy >= 1.19.0
- SciPy >= 1.5.0
- Matplotlib >= 3.3.0

## File Descriptions

### Core Module

- **`adaptive_mcs.py`**: Core classes
  - `AdaptiveMCS`: MCS adjustment algorithms
  - `NLOSModel`: NLOS channel model
  - `PlatooningScenario`: Vehicle platooning scenario
  - Helper functions

### Main Script

- **`run_simulation.py`**: Main simulation entry point
  - Run all experiments
  - Generate plots
  - Save results

## Usage Examples

### Basic Run

```bash
python run_simulation.py
```

### Custom Parameters

Edit `run_simulation.py`:

```python
sim_params = {
    'duration_s': 60.0,        # 60 seconds instead of 30
    'time_step_s': 0.01,       # 10ms instead of 1ms
    'beacon_interval_s': 0.1,
    'initial_mcs': 9,
    'n_runs': 20               # More Monte Carlo runs
}

algorithms = ['bler', 'hybrid']  # Test only these algorithms
n_blocking_values = [0, 1, 2, 3, 4, 5]  # All NLOS scenarios
```

### Interactive Use

```python
from adaptive_mcs import AdaptiveMCS, NLOSModel, PlatooningScenario

# Create scenario
scenario = PlatooningScenario(n_vehicles=5)

# Create channel
channel = NLOSModel(n_blocking=2)

# Create MCS controller
mcs = AdaptiveMCS('hybrid', initial_mcs=9)

# Simulate one time step
scenario.update(0.001)  # 1ms
distance = scenario.get_distance(0, 1)
sinr = channel.compute_sinr(distance)
ack = channel.simulate_transmission(sinr, mcs.current_mcs)
new_mcs = mcs.update(0.001, sinr, ack)
```

## Output

Results are saved in timestamped directories:

```
results_YYYYMMDD_HHMMSS/
├── results.json              # All numerical results
├── comparison_vs_nlos.png    # Line plots
└── heatmaps.png             # Performance heatmaps
```

### Results JSON Format

```json
{
  "fixed_nlos0": {
    "algorithm": "fixed",
    "n_blocking": 0,
    "prr_mean": 0.95,
    "prr_std": 0.02,
    "throughput_mean": 1234.5,
    "throughput_std": 45.6,
    ...
  },
  ...
}
```

## Customization

### Add New Algorithm

In `adaptive_mcs.py`:

```python
class AdaptiveMCS:
    def _update_my_algorithm(self, time, sinr, ack_received):
        """My custom algorithm"""
        # Your implementation
        return new_mcs

    def update(self, time, sinr, ack_received):
        # Add to dispatch
        elif self.algorithm_type == 'my_algorithm':
            mcs = self._update_my_algorithm(time, sinr, ack_received)
```

In `run_simulation.py`:

```python
algorithms = ['fixed', 'bler', 'sinr', 'hybrid', 'my_algorithm']
```

### Custom Channel Model

Subclass `NLOSModel`:

```python
class CustomChannel(NLOSModel):
    def compute_path_loss(self, distance_m):
        # Your custom path loss model
        return pl
```

### Custom Platooning Scenario

```python
scenario = PlatooningScenario(n_vehicles=8)
scenario.TARGET_SPACING_M = 3.0  # Override target spacing
```

## Performance Optimization

### Reduce Simulation Time

```python
# Larger time step
sim_params['time_step_s'] = 0.01  # 10ms instead of 1ms

# Fewer Monte Carlo runs
sim_params['n_runs'] = 5

# Shorter duration
sim_params['duration_s'] = 10.0
```

### Parallel Processing

Use multiprocessing:

```python
from multiprocessing import Pool

def run_parallel(params):
    return run_single_simulation(*params)

with Pool() as pool:
    results = pool.map(run_parallel, param_list)
```

## Troubleshooting

### ImportError: No module named 'scipy'

```bash
pip install scipy
```

### Plots not showing

Add to `run_simulation.py`:

```python
import matplotlib
matplotlib.use('TkAgg')  # Or 'Qt5Agg'
```

### Memory issues

Reduce time resolution or duration:

```python
sim_params['time_step_s'] = 0.01   # 10ms
sim_params['duration_s'] = 10.0    # 10 seconds
```

## Testing

Run unit tests:

```python
# test_adaptive_mcs.py
from adaptive_mcs import AdaptiveMCS, NLOSModel

def test_mcs_bounds():
    mcs = AdaptiveMCS('bler')
    # Test that MCS stays in [0, 20]
    for _ in range(100):
        new_mcs = mcs.update(0, 10, True)
        assert 0 <= new_mcs <= 20

def test_nlos_path_loss():
    channel_los = NLOSModel(n_blocking=0)
    channel_nlos = NLOSModel(n_blocking=2)

    pl_los = channel_los.compute_path_loss(100)
    pl_nlos = channel_nlos.compute_path_loss(100)

    # NLOS should have higher path loss
    assert pl_nlos > pl_los
```

Run tests:

```bash
pytest test_adaptive_mcs.py
```

## Visualization

Custom plots:

```python
import matplotlib.pyplot as plt
import json

# Load results
with open('results_YYYYMMDD_HHMMSS/results.json') as f:
    results = json.load(f)

# Custom plot
fig, ax = plt.subplots()
for alg in ['fixed', 'bler', 'sinr', 'hybrid']:
    prr_values = [results[f'{alg}_nlos{n}']['prr_mean']
                  for n in [0, 1, 2, 3]]
    ax.plot([0, 1, 2, 3], prr_values, label=alg.upper())

ax.set_xlabel('N_blocking')
ax.set_ylabel('PRR')
ax.legend()
plt.savefig('custom_plot.png')
```
