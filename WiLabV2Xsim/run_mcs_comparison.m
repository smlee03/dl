% run_mcs_comparison.m
% Compare different MCS values using WiLabV2Xsim
close all; clear; clc;

fprintf('=== WiLabV2Xsim MCS Comparison ===\n\n');

configFile = 'ConfigFiles/Clean_Highway.cfg';
simTime = 5;
rho = 100;

% MCS values to compare
MCS_list = [3, 7, 11];

fprintf('Testing MCS values: %s\n', mat2str(MCS_list));
fprintf('Simulation time: %d s, Density: %d veh/km\n\n', simTime, rho);

% Run simulations for each MCS
for i = 1:length(MCS_list)
    MCS = MCS_list(i);
    fprintf('\n========== MCS = %d ==========\n', MCS);

    outFolder = sprintf('Output/MCS%d', MCS);

    WiLabV2Xsim(configFile, ...
        'outputFolder', outFolder, ...
        'simulationTime', simTime, ...
        'rho', rho, ...
        'MCS_LTE', MCS, ...
        'Raw', 150, ...
        'beaconSizeBytes', 190, ...
        'printPacketReceptionRatio', true, ...
        'dcc_active', false);

    fprintf('MCS %d done\n', MCS);
end

%% Display Results Summary
fprintf('\n\n============ RESULTS SUMMARY ============\n');
fprintf('Distance(m) |');
for i = 1:length(MCS_list)
    fprintf(' MCS%-2d PRR |', MCS_list(i));
end
fprintf('\n');
fprintf('%s\n', repmat('-', 1, 12 + 11*length(MCS_list)));

% Load all results
prr_data = cell(length(MCS_list), 1);
for i = 1:length(MCS_list)
    MCS = MCS_list(i);
    fname = sprintf('Output/MCS%d/packet_reception_ratio_1_LTE.xls', MCS);
    if exist(fname, 'file')
        prr_data{i} = load(fname);
    end
end

% Print comparison at key distances
key_distances = [50, 100, 150, 200, 300];
for d = key_distances
    fprintf('%11d |', d);
    for i = 1:length(MCS_list)
        if ~isempty(prr_data{i})
            idx = find(prr_data{i}(:,1) == d);
            if ~isempty(idx)
                fprintf(' %8.2f%% |', prr_data{i}(idx, end) * 100);
            else
                fprintf(' %9s |', 'N/A');
            end
        else
            fprintf(' %9s |', 'N/A');
        end
    end
    fprintf('\n');
end

fprintf('\n============ ANALYSIS ============\n');
fprintf('Lower MCS (e.g., MCS 3) = More robust, lower throughput\n');
fprintf('Higher MCS (e.g., MCS 11) = Higher throughput, less robust\n');

fprintf('\nExperiment complete!\n');
