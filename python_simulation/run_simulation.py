"""
run_simulation.py
Main simulation script for platooning scenario with adaptive MCS
Compares different MCS adjustment algorithms

All parameters are scientifically justified in ADAPTIVE_MCS_DESIGN.md
"""

import numpy as np
import matplotlib.pyplot as plt
from adaptive_mcs import (
    AdaptiveMCS, NLOSModel, PlatooningScenario, get_bits_per_packet
)
from typing import Dict, List
import json
from datetime import datetime
import os


def run_single_simulation(algorithm: str, n_blocking: int,
                         duration_s: float, time_step_s: float,
                         beacon_interval_s: float, initial_mcs: int) -> Dict:
    """
    Run a single simulation instance

    Args:
        algorithm: MCS algorithm type
        n_blocking: Number of blocking vehicles
        duration_s: Simulation duration
        time_step_s: Time step
        beacon_interval_s: Beacon interval
        initial_mcs: Initial MCS value

    Returns:
        Performance metrics dictionary
    """
    # Initialize components
    scenario = PlatooningScenario()
    channel = NLOSModel(n_blocking)
    mcs_controller = AdaptiveMCS(algorithm, initial_mcs)

    # Simulation variables
    num_steps = int(duration_s / time_step_s)
    next_beacon_time = 0.0

    # Performance tracking
    total_packets = 0
    successful_packets = 0
    total_bits = 0
    mcs_values = []

    # Main simulation loop
    for step in range(num_steps):
        current_time = step * time_step_s

        # Update scenario (vehicle positions)
        scenario.update(time_step_s)

        # Check if it's time to send beacon
        if current_time >= next_beacon_time:
            # Groupcast from leader (vehicle 0) to all followers
            tx_vehicle = 0

            for rx_vehicle in range(1, scenario.n_vehicles):
                # Get distance and blocking vehicles
                distance = scenario.get_distance(tx_vehicle, rx_vehicle)
                n_blocking_actual = scenario.get_n_blocking_vehicles(
                    tx_vehicle, rx_vehicle
                )

                # Update channel model for this link
                channel.n_blocking = min(n_blocking_actual, n_blocking)

                # Compute SINR
                sinr = channel.compute_sinr(distance)

                # Get current MCS
                current_mcs = mcs_controller.current_mcs

                # Simulate transmission
                ack_received = channel.simulate_transmission(sinr, current_mcs)

                # Update MCS controller
                mcs_controller.update(current_time, sinr, ack_received)

                # Track performance
                total_packets += 1
                if ack_received:
                    successful_packets += 1

                # Calculate bits transmitted
                bits_per_packet = get_bits_per_packet(current_mcs)
                if ack_received:
                    total_bits += bits_per_packet

                mcs_values.append(current_mcs)

            next_beacon_time += beacon_interval_s

    # Calculate metrics
    result = {
        'prr': successful_packets / total_packets if total_packets > 0 else 0,
        'throughput': total_bits / duration_s / 1000,  # kbps
        'mcs_changes': len(mcs_controller.mcs_history) - 1,
        'avg_mcs': np.mean(mcs_values) if mcs_values else 0
    }

    return result


def run_experiments(algorithms: List[str], n_blocking_values: List[int],
                   sim_params: Dict) -> Dict:
    """
    Run all experiments

    Args:
        algorithms: List of algorithm names
        n_blocking_values: List of N_blocking values to test
        sim_params: Simulation parameters

    Returns:
        Results dictionary
    """
    results = {}

    for algorithm in algorithms:
        print(f"Running algorithm: {algorithm}")

        for n_blocking in n_blocking_values:
            print(f"  N_blocking = {n_blocking}...", end=' ')

            # Storage for Monte Carlo runs
            prr_runs = []
            throughput_runs = []
            mcs_changes_runs = []
            avg_mcs_runs = []

            for run in range(sim_params['n_runs']):
                result = run_single_simulation(
                    algorithm, n_blocking,
                    sim_params['duration_s'],
                    sim_params['time_step_s'],
                    sim_params['beacon_interval_s'],
                    sim_params['initial_mcs']
                )

                prr_runs.append(result['prr'])
                throughput_runs.append(result['throughput'])
                mcs_changes_runs.append(result['mcs_changes'])
                avg_mcs_runs.append(result['avg_mcs'])

            # Store averaged results
            key = f"{algorithm}_nlos{n_blocking}"
            results[key] = {
                'algorithm': algorithm,
                'n_blocking': n_blocking,
                'prr_mean': np.mean(prr_runs),
                'prr_std': np.std(prr_runs),
                'throughput_mean': np.mean(throughput_runs),
                'throughput_std': np.std(throughput_runs),
                'mcs_changes_mean': np.mean(mcs_changes_runs),
                'mcs_changes_std': np.std(mcs_changes_runs),
                'avg_mcs_mean': np.mean(avg_mcs_runs),
                'avg_mcs_std': np.std(avg_mcs_runs)
            }

            print(f"PRR={results[key]['prr_mean']*100:.2f}% "
                  f"(±{results[key]['prr_std']*100:.2f}%), "
                  f"MCS changes={results[key]['mcs_changes_mean']:.1f} "
                  f"(±{results[key]['mcs_changes_std']:.1f})")

    return results


def plot_results(results: Dict, algorithms: List[str],
                n_blocking_values: List[int], output_dir: str):
    """Generate comparison plots"""

    n_algorithms = len(algorithms)
    n_nlos = len(n_blocking_values)

    # Extract data
    prr_matrix = np.zeros((n_algorithms, n_nlos))
    prr_std_matrix = np.zeros((n_algorithms, n_nlos))
    throughput_matrix = np.zeros((n_algorithms, n_nlos))
    throughput_std_matrix = np.zeros((n_algorithms, n_nlos))
    mcs_changes_matrix = np.zeros((n_algorithms, n_nlos))
    avg_mcs_matrix = np.zeros((n_algorithms, n_nlos))

    for i, alg in enumerate(algorithms):
        for j, n_blocking in enumerate(n_blocking_values):
            key = f"{alg}_nlos{n_blocking}"
            prr_matrix[i, j] = results[key]['prr_mean']
            prr_std_matrix[i, j] = results[key]['prr_std']
            throughput_matrix[i, j] = results[key]['throughput_mean']
            throughput_std_matrix[i, j] = results[key]['throughput_std']
            mcs_changes_matrix[i, j] = results[key]['mcs_changes_mean']
            avg_mcs_matrix[i, j] = results[key]['avg_mcs_mean']

    # Figure 1: Line plots vs N_blocking
    fig, axes = plt.subplots(1, 3, figsize=(15, 5))

    colors = ['b', 'r', 'g', 'm']
    markers = ['o', 's', '^', 'd']

    # PRR
    for i, alg in enumerate(algorithms):
        axes[0].errorbar(n_blocking_values, prr_matrix[i, :] * 100,
                        yerr=prr_std_matrix[i, :] * 100,
                        color=colors[i], marker=markers[i],
                        label=alg.upper(), linewidth=2, capsize=5)
    axes[0].axhline(y=90, color='k', linestyle='--', label='Target (90%)')
    axes[0].set_xlabel('Number of Blocking Vehicles')
    axes[0].set_ylabel('Packet Reception Ratio (%)')
    axes[0].set_title('PRR vs NLOS Severity')
    axes[0].legend()
    axes[0].grid(True)
    axes[0].set_ylim([0, 105])

    # Throughput
    for i, alg in enumerate(algorithms):
        axes[1].errorbar(n_blocking_values, throughput_matrix[i, :],
                        yerr=throughput_std_matrix[i, :],
                        color=colors[i], marker=markers[i],
                        label=alg.upper(), linewidth=2, capsize=5)
    axes[1].set_xlabel('Number of Blocking Vehicles')
    axes[1].set_ylabel('Throughput (kbps)')
    axes[1].set_title('Throughput vs NLOS Severity')
    axes[1].legend()
    axes[1].grid(True)

    # MCS Changes
    for i, alg in enumerate(algorithms):
        axes[2].plot(n_blocking_values, mcs_changes_matrix[i, :],
                    color=colors[i], marker=markers[i],
                    label=alg.upper(), linewidth=2)
    axes[2].set_xlabel('Number of Blocking Vehicles')
    axes[2].set_ylabel('Number of MCS Changes')
    axes[2].set_title('MCS Stability')
    axes[2].legend()
    axes[2].grid(True)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/comparison_vs_nlos.png', dpi=300)
    print(f"Saved: {output_dir}/comparison_vs_nlos.png")

    # Figure 2: Heatmaps
    fig, axes = plt.subplots(1, 3, figsize=(15, 5))

    # PRR Heatmap
    im1 = axes[0].imshow(prr_matrix * 100, aspect='auto', cmap='RdYlGn',
                        vmin=0, vmax=100)
    axes[0].set_xticks(range(n_nlos))
    axes[0].set_xticklabels(n_blocking_values)
    axes[0].set_yticks(range(n_algorithms))
    axes[0].set_yticklabels([a.upper() for a in algorithms])
    axes[0].set_xlabel('Number of Blocking Vehicles')
    axes[0].set_ylabel('Algorithm')
    axes[0].set_title('PRR (%) Heatmap')
    plt.colorbar(im1, ax=axes[0])

    # Add text annotations
    for i in range(n_algorithms):
        for j in range(n_nlos):
            axes[0].text(j, i, f'{prr_matrix[i, j]*100:.1f}',
                        ha='center', va='center', color='black')

    # Throughput Heatmap
    im2 = axes[1].imshow(throughput_matrix, aspect='auto', cmap='viridis')
    axes[1].set_xticks(range(n_nlos))
    axes[1].set_xticklabels(n_blocking_values)
    axes[1].set_yticks(range(n_algorithms))
    axes[1].set_yticklabels([a.upper() for a in algorithms])
    axes[1].set_xlabel('Number of Blocking Vehicles')
    axes[1].set_ylabel('Algorithm')
    axes[1].set_title('Throughput (kbps) Heatmap')
    plt.colorbar(im2, ax=axes[1])

    # Add text annotations
    for i in range(n_algorithms):
        for j in range(n_nlos):
            axes[1].text(j, i, f'{throughput_matrix[i, j]:.0f}',
                        ha='center', va='center', color='white')

    # MCS Changes Heatmap
    im3 = axes[2].imshow(mcs_changes_matrix, aspect='auto', cmap='plasma')
    axes[2].set_xticks(range(n_nlos))
    axes[2].set_xticklabels(n_blocking_values)
    axes[2].set_yticks(range(n_algorithms))
    axes[2].set_yticklabels([a.upper() for a in algorithms])
    axes[2].set_xlabel('Number of Blocking Vehicles')
    axes[2].set_ylabel('Algorithm')
    axes[2].set_title('MCS Changes Heatmap')
    plt.colorbar(im3, ax=axes[2])

    # Add text annotations
    for i in range(n_algorithms):
        for j in range(n_nlos):
            axes[2].text(j, i, f'{mcs_changes_matrix[i, j]:.0f}',
                        ha='center', va='center', color='white')

    plt.tight_layout()
    plt.savefig(f'{output_dir}/heatmaps.png', dpi=300)
    print(f"Saved: {output_dir}/heatmaps.png")


def main():
    """Main entry point"""

    print("=== Platooning Adaptive MCS Simulation ===\n")

    # Simulation parameters (all justified in ADAPTIVE_MCS_DESIGN.md)
    sim_params = {
        'duration_s': 30.0,           # 30 seconds
        'time_step_s': 0.001,         # 1 ms - LTE subframe duration
        'beacon_interval_s': 0.1,     # 10 Hz CAM frequency
        'initial_mcs': 9,             # 16-QAM 1/2 - balanced
        'n_runs': 10                  # Monte Carlo runs
    }

    algorithms = ['fixed', 'bler', 'sinr', 'hybrid']
    n_blocking_values = [0, 1, 2, 3]

    print(f"Duration: {sim_params['duration_s']} seconds")
    print(f"Time step: {sim_params['time_step_s']*1000} ms")
    print(f"Beacon interval: {1/sim_params['beacon_interval_s']} Hz")
    print(f"Algorithms: {', '.join(algorithms)}")
    print(f"NLOS scenarios: N_blocking = {n_blocking_values}")
    print(f"Monte Carlo runs: {sim_params['n_runs']}\n")

    # Run experiments
    results = run_experiments(algorithms, n_blocking_values, sim_params)

    # Create output directory
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    output_dir = f'results_{timestamp}'
    os.makedirs(output_dir, exist_ok=True)

    # Save results
    with open(f'{output_dir}/results.json', 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to: {output_dir}/results.json")

    # Generate plots
    plot_results(results, algorithms, n_blocking_values, output_dir)

    print("\nSimulation complete!")


if __name__ == '__main__':
    main()
