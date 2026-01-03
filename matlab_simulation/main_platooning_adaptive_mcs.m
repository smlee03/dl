% main_platooning_adaptive_mcs.m
% Main simulation script for platooning scenario with adaptive MCS
% Compares different MCS adjustment algorithms
%
% All parameters are scientifically justified in ADAPTIVE_MCS_DESIGN.md

clear; close all; clc;

% Add paths
addpath('core');
addpath('scenarios');
addpath('channel_models');
addpath('utils');

%% Simulation Parameters (all justified in ADAPTIVE_MCS_DESIGN.md)

% Simulation duration
SIM_DURATION_S = 30;        % 30 seconds - covers formation (0-20s) and
                            % steady state (20-30s)
TIME_STEP_MS = 1;           % 1 ms - LTE subframe duration
TIME_STEP_S = TIME_STEP_MS * 1e-3;

% Beacon parameters (ETSI EN 302 637-2)
BEACON_INTERVAL_S = 0.1;    % 10 Hz CAM frequency for platooning

% Algorithms to compare
ALGORITHMS = {'fixed', 'bler', 'sinr', 'hybrid'};

% NLOS scenarios to test
N_BLOCKING_VALUES = [0, 1, 2, 3];  % 0=LOS, 1-3 blocking vehicles

% Initial MCS (3GPP TS 36.213)
INITIAL_MCS = 9;            % 16-QAM 1/2 - balanced throughput/reliability

% Number of Monte Carlo runs for statistical significance
N_RUNS = 10;                % Balances accuracy and computation time

fprintf('=== Platooning Adaptive MCS Simulation ===\n');
fprintf('Duration: %d seconds\n', SIM_DURATION_S);
fprintf('Time step: %d ms\n', TIME_STEP_MS);
fprintf('Beacon interval: %.1f Hz\n', 1/BEACON_INTERVAL_S);
fprintf('Algorithms: %s\n', strjoin(ALGORITHMS, ', '));
fprintf('NLOS scenarios: N_blocking = [%s]\n', num2str(N_BLOCKING_VALUES));
fprintf('Monte Carlo runs: %d\n\n', N_RUNS);

%% Run Simulations

results = struct();

for alg_idx = 1:length(ALGORITHMS)
    algorithm = ALGORITHMS{alg_idx};
    fprintf('Running algorithm: %s\n', algorithm);

    for nlos_idx = 1:length(N_BLOCKING_VALUES)
        n_blocking = N_BLOCKING_VALUES(nlos_idx);
        fprintf('  N_blocking = %d... ', n_blocking);

        % Storage for Monte Carlo runs
        prr_runs = zeros(1, N_RUNS);
        throughput_runs = zeros(1, N_RUNS);
        mcs_changes_runs = zeros(1, N_RUNS);
        avg_mcs_runs = zeros(1, N_RUNS);

        for run = 1:N_RUNS
            % Run single simulation
            result = runSingleSimulation(algorithm, n_blocking, ...
                                        SIM_DURATION_S, TIME_STEP_S, ...
                                        BEACON_INTERVAL_S, INITIAL_MCS);

            prr_runs(run) = result.prr;
            throughput_runs(run) = result.throughput;
            mcs_changes_runs(run) = result.mcs_changes;
            avg_mcs_runs(run) = result.avg_mcs;
        end

        % Store averaged results
        key = sprintf('%s_nlos%d', algorithm, n_blocking);
        results.(key).algorithm = algorithm;
        results.(key).n_blocking = n_blocking;
        results.(key).prr_mean = mean(prr_runs);
        results.(key).prr_std = std(prr_runs);
        results.(key).throughput_mean = mean(throughput_runs);
        results.(key).throughput_std = std(throughput_runs);
        results.(key).mcs_changes_mean = mean(mcs_changes_runs);
        results.(key).mcs_changes_std = std(mcs_changes_runs);
        results.(key).avg_mcs_mean = mean(avg_mcs_runs);
        results.(key).avg_mcs_std = std(avg_mcs_runs);

        fprintf('PRR=%.2f%% (±%.2f%%), MCS changes=%.1f (±%.1f)\n', ...
                results.(key).prr_mean * 100, ...
                results.(key).prr_std * 100, ...
                results.(key).mcs_changes_mean, ...
                results.(key).mcs_changes_std);
    end
end

%% Save Results

timestamp = datestr(now, 'yyyymmdd_HHMMSS');
results_dir = 'results';
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end
save(sprintf('%s/results_%s.mat', results_dir, timestamp), 'results');

fprintf('\nResults saved to: %s/results_%s.mat\n', results_dir, timestamp);

%% Generate Comparison Plots

plotComparison(results, ALGORITHMS, N_BLOCKING_VALUES, results_dir, timestamp);

fprintf('\nSimulation complete!\n');

%% Helper Functions

function result = runSingleSimulation(algorithm, n_blocking, ...
                                     duration_s, time_step_s, ...
                                     beacon_interval_s, initial_mcs)
    % Run a single simulation instance
    % Returns performance metrics

    % Initialize scenario
    scenario = PlatooningScenario();

    % Initialize channel model
    channel = NLOSModel(n_blocking);

    % Initialize MCS controller
    mcs_controller = AdaptiveMCS(algorithm, initial_mcs);

    % Simulation variables
    num_steps = floor(duration_s / time_step_s);
    beacon_counter = 0;
    next_beacon_time = 0;

    % Performance tracking
    total_packets = 0;
    successful_packets = 0;
    total_bits = 0;
    mcs_values = [];

    % Main simulation loop
    for step = 1:num_steps
        current_time = step * time_step_s;

        % Update scenario (vehicle positions)
        scenario.update(time_step_s);

        % Check if it's time to send beacon
        if current_time >= next_beacon_time
            % Groupcast from leader (vehicle 1) to all followers
            tx_vehicle = 1;

            for rx_vehicle = 2:scenario.n_vehicles
                % Get distance and blocking vehicles
                distance = scenario.getDistance(tx_vehicle, rx_vehicle);
                n_blocking_actual = scenario.getNBlockingVehicles(tx_vehicle, ...
                                                                   rx_vehicle);

                % Update channel model for this link
                channel.n_blocking = min(n_blocking_actual, n_blocking);

                % Compute SINR
                sinr = channel.computeSINR(distance);

                % Get current MCS
                current_mcs = mcs_controller.current_mcs;

                % Simulate transmission
                ack_received = channel.simulateTransmission(sinr, current_mcs);

                % Update MCS controller
                mcs_controller.update(current_time, sinr, ack_received);

                % Track performance
                total_packets = total_packets + 1;
                if ack_received
                    successful_packets = successful_packets + 1;
                end

                % Calculate bits transmitted (based on MCS)
                bits_per_packet = getBitsPerPacket(current_mcs);
                if ack_received
                    total_bits = total_bits + bits_per_packet;
                end

                mcs_values = [mcs_values, current_mcs];
            end

            next_beacon_time = next_beacon_time + beacon_interval_s;
        end
    end

    % Calculate metrics
    result.prr = successful_packets / total_packets;
    result.throughput = total_bits / duration_s / 1000;  % kbps
    result.mcs_changes = length(mcs_controller.mcs_history) - 1;
    result.avg_mcs = mean(mcs_values);
    result.mcs_controller = mcs_controller;
end

function bits = getBitsPerPacket(mcs)
    % Get bits per packet based on MCS
    % Simplified model based on 3GPP TS 36.213

    % Spectral efficiency (bits/symbol) for each MCS
    spectral_efficiency = [
        0.1523,  % MCS 0
        0.2344,  % MCS 1
        0.3770,  % MCS 2
        0.6016,  % MCS 3
        0.8770,  % MCS 4
        1.1758,  % MCS 5
        1.4766,  % MCS 6
        1.9141,  % MCS 7
        2.4063,  % MCS 8
        2.7305,  % MCS 9
        3.3223,  % MCS 10
        3.9023,  % MCS 11
        4.5234,  % MCS 12
        5.1152,  % MCS 13
        5.5547,  % MCS 14
        6.2266,  % MCS 15
        6.9141,  % MCS 16
        7.4063,  % MCS 17
        8.0977,  % MCS 18
        8.9063,  % MCS 19
        9.6094   % MCS 20
    ];

    if mcs < 0 || mcs > 20
        error('MCS must be in range [0, 20]');
    end

    % Assume 1 RB (resource block) = 12 subcarriers * 7 symbols = 84 symbols
    % For simplicity, assume 10 RBs allocated per packet
    num_rbs = 10;
    symbols_per_rb = 84;
    total_symbols = num_rbs * symbols_per_rb;

    bits = floor(spectral_efficiency(mcs + 1) * total_symbols);
end
