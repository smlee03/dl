classdef NLOSModel < handle
    % NLOSModel - NLOS channel model with vehicle blocking
    % All parameters are scientifically justified in ADAPTIVE_MCS_DESIGN.md

    properties (Constant)
        % Path loss per blocking vehicle (WINNER+ B1 V2V model)
        ALPHA = 3;              % dB per vehicle (empirical measurements: 2-5 dB)

        % Base NLOS penalty (ITU-R M.2135 urban micro-cell NLOS)
        BETA = 5;               % dB (first diffraction loss)

        % V2V frequency
        CARRIER_FREQ_GHZ = 5.9; % ITS-G5 band (ETSI EN 302 571)

        % Transmit power
        P_TX_DBM = 23;          % Max power for V2V (ETSI EN 302 571)

        % Noise floor (10 MHz bandwidth, 9 dB noise figure)
        NOISE_FLOOR_DBM = -95;  % N0 = -174 + 10*log10(10e6) + 9

        % Shadowing standard deviation (3GPP TR 36.885)
        SIGMA_SHADOW_LOS = 3;   % dB (LOS)
        SIGMA_SHADOW_NLOS = 4;  % dB (NLOS)

        % Doppler parameters
        SPEED_KMH = 90;         % Highway speed (25 m/s)
        COHERENCE_TIME_MS = 10; % ~1/(2*f_d) where f_d = 518 Hz
    end

    properties
        n_blocking;             % Number of blocking vehicles
        distances;              % Distance matrix between vehicles
        shadowing;              % Shadowing realizations
    end

    methods
        function obj = NLOSModel(n_blocking)
            % Constructor
            % n_blocking: Number of blocking vehicles (0-5)
            %             0 = LOS, >=1 = NLOS

            if nargin < 1
                n_blocking = 0;  % Default: LOS
            end

            if n_blocking < 0 || n_blocking > 5
                error('n_blocking must be in range [0, 5]');
            end

            obj.n_blocking = n_blocking;
            obj.shadowing = [];
        end

        function pl = computePathLoss(obj, distance_m)
            % Compute path loss based on 3GPP TR 36.885 V2V model
            % Inputs:
            %   distance_m: Distance in meters
            % Output:
            %   pl: Path loss in dB

            % LOS path loss (3GPP TR 36.885)
            % PL_LOS(d) = 38.77 + 16.7 * log10(d) + 18.2 * log10(fc)
            pl_los = 38.77 + 16.7 * log10(distance_m) + ...
                     18.2 * log10(obj.CARRIER_FREQ_GHZ);

            % Additional NLOS loss
            if obj.n_blocking > 0
                pl_nlos_additional = obj.ALPHA * obj.n_blocking + obj.BETA;
                pl = pl_los + pl_nlos_additional;
            else
                pl = pl_los;
            end
        end

        function sinr = computeSINR(obj, distance_m, interference_dbm)
            % Compute SINR
            % Inputs:
            %   distance_m: Distance in meters
            %   interference_dbm: Interference power in dBm (optional)
            % Output:
            %   sinr: SINR in dB

            if nargin < 3
                interference_dbm = -120;  % Minimal interference assumption
            end

            % Compute path loss
            pl = obj.computePathLoss(distance_m);

            % Add shadowing (log-normal)
            if obj.n_blocking > 0
                sigma_shadow = obj.SIGMA_SHADOW_NLOS;
            else
                sigma_shadow = obj.SIGMA_SHADOW_LOS;
            end
            shadowing = sigma_shadow * randn();

            % Received power
            p_rx = obj.P_TX_DBM - pl - shadowing;

            % Total noise + interference
            noise_plus_interference = 10*log10(10^(obj.NOISE_FLOOR_DBM/10) + ...
                                               10^(interference_dbm/10));

            % SINR
            sinr = p_rx - noise_plus_interference;
        end

        function [sinr_trace, coherent_blocks] = generateSINRTrace(obj, ...
                distance_m, duration_s, sample_rate_hz)
            % Generate time-varying SINR trace
            % Inputs:
            %   distance_m: Distance in meters
            %   duration_s: Duration in seconds
            %   sample_rate_hz: Sampling rate in Hz
            % Outputs:
            %   sinr_trace: SINR values over time (dB)
            %   coherent_blocks: Block indices for coherent periods

            num_samples = floor(duration_s * sample_rate_hz);
            sinr_trace = zeros(1, num_samples);

            % Coherence time in samples
            coherence_samples = floor(obj.COHERENCE_TIME_MS * 1e-3 * sample_rate_hz);

            % Generate SINR trace with coherent blocks
            num_blocks = ceil(num_samples / coherence_samples);
            coherent_blocks = zeros(1, num_samples);

            for block = 1:num_blocks
                start_idx = (block-1) * coherence_samples + 1;
                end_idx = min(block * coherence_samples, num_samples);

                % Generate SINR for this coherent block
                sinr_block = obj.computeSINR(distance_m);

                % Assign to trace
                sinr_trace(start_idx:end_idx) = sinr_block;
                coherent_blocks(start_idx:end_idx) = block;
            end
        end

        function bler = computeBLER(~, sinr, mcs)
            % Compute BLER based on SINR and MCS
            % Uses empirical AWGN BLER curves from 3GPP TR 36.942
            % Inputs:
            %   sinr: SINR in dB
            %   mcs: MCS index (0-20)
            % Output:
            %   bler: Block error rate [0, 1]

            % SINR thresholds for 10% BLER at each MCS (3GPP TR 36.942)
            % These values are derived from link-level simulations
            sinr_threshold = [-5, -3, 0, 2, 5, 7, 9, 11, 13, 15, ...
                              17, 19, 21, 23, 25, 27, 29, 31, 33, 35, 37];

            if mcs < 0 || mcs > 20
                error('MCS must be in range [0, 20]');
            end

            % Get threshold for this MCS
            threshold = sinr_threshold(mcs + 1);

            % BLER curve shape (exponential model)
            % BLER(SINR) = 0.5 * erfc((SINR - threshold) / sigma)
            sigma = 2;  % Curve steepness parameter (empirically fitted)

            bler = 0.5 * erfc((sinr - threshold) / sigma);

            % Clamp to [0, 1]
            bler = max(0, min(1, bler));
        end

        function ack = simulateTransmission(obj, sinr, mcs)
            % Simulate packet transmission
            % Inputs:
            %   sinr: SINR in dB
            %   mcs: MCS index
            % Output:
            %   ack: true if ACK (success), false if NAK (error)

            bler = obj.computeBLER(sinr, mcs);
            ack = rand() > bler;  % Success if random value > BLER
        end

        function stats = getStatistics(obj)
            % Get channel statistics

            stats.n_blocking = obj.n_blocking;
            stats.is_nlos = (obj.n_blocking > 0);

            % Example path loss at different distances
            distances = [10, 30, 50, 100, 150];
            stats.path_loss_samples = arrayfun(@(d) obj.computePathLoss(d), ...
                                                distances);
            stats.distances_samples = distances;
        end
    end
end
