classdef AdaptiveMCS < handle
    % AdaptiveMCS - Adaptive MCS adjustment algorithms for V2V groupcast
    % All parameters are scientifically justified in ADAPTIVE_MCS_DESIGN.md

    properties (Constant)
        % BLER thresholds (3GPP TS 22.186)
        BLER_HIGH_THRESHOLD = 0.1;   % 10% - Target BLER for V2V
        BLER_LOW_THRESHOLD = 0.01;   % 1% - Excellent channel with safety margin

        % MCS adjustment steps (IEEE 802.11p rate adaptation)
        MCS_STEP_DOWN = 2;           % Aggressive reduction for degrading channel
        MCS_STEP_UP = 1;             % Conservative increase to avoid oscillation

        % MCS range (3GPP TS 36.213)
        MCS_MIN = 0;                 % QPSK 1/5 - Most robust
        MCS_MAX = 20;                % 64-QAM 3/4 - Maximum for high SINR

        % Window sizes
        BLER_WINDOW_SIZE = 100;      % 100 packets = 10s at 10 Hz (ETSI EN 302 637-2)
        SINR_WINDOW_SIZE = 50;       % 50ms at 1ms sampling = multiple fading periods

        % Hybrid algorithm penalty
        PENALTY = 3;                 % MCS reduction when SINR prediction fails
    end

    properties
        algorithm_type;      % 'fixed', 'bler', 'sinr', 'hybrid'
        current_mcs;         % Current MCS value
        bler_window;         % Sliding window for BLER calculation
        sinr_window;         % Sliding window for SINR averaging
        mcs_history;         % History of MCS changes for analysis
        time_history;        % Timestamps for MCS changes
    end

    methods
        function obj = AdaptiveMCS(algorithm_type, initial_mcs)
            % Constructor
            % algorithm_type: 'fixed', 'bler', 'sinr', 'hybrid'
            % initial_mcs: Initial MCS value (default: 9 - 16-QAM 1/2)

            if nargin < 2
                % MCS 9: balanced throughput and reliability (3GPP TS 36.213)
                initial_mcs = 9;  % 16-QAM, code rate 1/2
            end

            obj.algorithm_type = algorithm_type;
            obj.current_mcs = initial_mcs;
            obj.bler_window = [];
            obj.sinr_window = [];
            obj.mcs_history = initial_mcs;
            obj.time_history = 0;
        end

        function mcs = update(obj, time, sinr, ack_received)
            % Update MCS based on algorithm type
            % Inputs:
            %   time: Current simulation time (s)
            %   sinr: Measured SINR (dB)
            %   ack_received: Boolean - true if ACK, false if NAK
            % Output:
            %   mcs: Updated MCS value

            switch obj.algorithm_type
                case 'fixed'
                    mcs = obj.updateFixed();
                case 'bler'
                    mcs = obj.updateBLER(time, ack_received);
                case 'sinr'
                    mcs = obj.updateSINR(time, sinr);
                case 'hybrid'
                    mcs = obj.updateHybrid(time, sinr, ack_received);
                otherwise
                    error('Unknown algorithm type: %s', obj.algorithm_type);
            end

            obj.current_mcs = mcs;
        end

        function mcs = updateFixed(obj)
            % Fixed MCS - baseline
            mcs = obj.current_mcs;
        end

        function mcs = updateBLER(obj, time, ack_received)
            % BLER-based adaptive MCS

            % Update BLER window
            obj.bler_window = [obj.bler_window, ~ack_received];  % 1 for error
            if length(obj.bler_window) > obj.BLER_WINDOW_SIZE
                obj.bler_window = obj.bler_window(end-obj.BLER_WINDOW_SIZE+1:end);
            end

            % Calculate current BLER
            if length(obj.bler_window) >= 10  % Minimum samples for stability
                current_bler = sum(obj.bler_window) / length(obj.bler_window);

                % Adjust MCS based on BLER
                if current_bler > obj.BLER_HIGH_THRESHOLD
                    % High error rate - decrease MCS
                    new_mcs = max(obj.current_mcs - obj.MCS_STEP_DOWN, obj.MCS_MIN);
                elseif current_bler < obj.BLER_LOW_THRESHOLD
                    % Low error rate - increase MCS
                    new_mcs = min(obj.current_mcs + obj.MCS_STEP_UP, obj.MCS_MAX);
                else
                    % Acceptable BLER - maintain MCS
                    new_mcs = obj.current_mcs;
                end

                % Record MCS change
                if new_mcs ~= obj.current_mcs
                    obj.mcs_history = [obj.mcs_history, new_mcs];
                    obj.time_history = [obj.time_history, time];
                end

                mcs = new_mcs;
            else
                mcs = obj.current_mcs;
            end
        end

        function mcs = updateSINR(obj, time, sinr)
            % SINR-based adaptive MCS

            % Update SINR window
            obj.sinr_window = [obj.sinr_window, sinr];
            if length(obj.sinr_window) > obj.SINR_WINDOW_SIZE
                obj.sinr_window = obj.sinr_window(end-obj.SINR_WINDOW_SIZE+1:end);
            end

            % Calculate average SINR
            avg_sinr = mean(obj.sinr_window);

            % Map SINR to MCS (based on 3GPP TR 36.942)
            % Target BLER = 10% at each SINR point
            new_mcs = obj.sinrToMCS(avg_sinr);

            % Record MCS change
            if new_mcs ~= obj.current_mcs
                obj.mcs_history = [obj.mcs_history, new_mcs];
                obj.time_history = [obj.time_history, time];
            end

            mcs = new_mcs;
        end

        function mcs = updateHybrid(obj, time, sinr, ack_received)
            % Hybrid adaptive MCS - combines SINR prediction with BLER feedback

            % Update windows
            obj.sinr_window = [obj.sinr_window, sinr];
            if length(obj.sinr_window) > obj.SINR_WINDOW_SIZE
                obj.sinr_window = obj.sinr_window(end-obj.SINR_WINDOW_SIZE+1:end);
            end

            obj.bler_window = [obj.bler_window, ~ack_received];
            if length(obj.bler_window) > obj.BLER_WINDOW_SIZE
                obj.bler_window = obj.bler_window(end-obj.BLER_WINDOW_SIZE+1:end);
            end

            % Get SINR-predicted MCS
            avg_sinr = mean(obj.sinr_window);
            mcs_predicted = obj.sinrToMCS(avg_sinr);

            % Adjust based on BLER feedback
            if length(obj.bler_window) >= 10
                current_bler = sum(obj.bler_window) / length(obj.bler_window);

                if current_bler > obj.BLER_HIGH_THRESHOLD
                    % SINR prediction failed - apply penalty
                    new_mcs = max(mcs_predicted - obj.PENALTY, obj.MCS_MIN);
                elseif current_bler < obj.BLER_LOW_THRESHOLD && ...
                       obj.current_mcs < mcs_predicted
                    % Gradually increase toward predicted MCS
                    new_mcs = min(obj.current_mcs + 1, mcs_predicted);
                else
                    % Use predicted MCS
                    new_mcs = mcs_predicted;
                end
            else
                new_mcs = mcs_predicted;
            end

            % Record MCS change
            if new_mcs ~= obj.current_mcs
                obj.mcs_history = [obj.mcs_history, new_mcs];
                obj.time_history = [obj.time_history, time];
            end

            mcs = new_mcs;
        end

        function mcs = sinrToMCS(~, sinr)
            % Map SINR to MCS based on 3GPP TR 36.942 link-level simulations
            % Target BLER = 10% at each SINR point

            if sinr < -5
                mcs = 0;   % QPSK 1/5 - Minimum sensitivity
            elseif sinr < 0
                mcs = 2;   % QPSK 1/3 - Low SINR region
            elseif sinr < 5
                mcs = 5;   % QPSK 2/3 - Moderate SINR
            elseif sinr < 10
                mcs = 9;   % 16-QAM 1/2 - Good SINR
            elseif sinr < 15
                mcs = 14;  % 16-QAM 3/4 - High SINR
            elseif sinr < 20
                mcs = 17;  % 64-QAM 1/2 - Very high SINR
            else
                mcs = 20;  % 64-QAM 3/4 - Excellent SINR
            end
        end

        function stats = getStatistics(obj)
            % Get performance statistics

            stats.algorithm = obj.algorithm_type;
            stats.final_mcs = obj.current_mcs;
            stats.mcs_history = obj.mcs_history;
            stats.time_history = obj.time_history;
            stats.num_changes = length(obj.mcs_history) - 1;

            if stats.num_changes > 0
                % MCS change frequency (changes per second)
                total_time = obj.time_history(end) - obj.time_history(1);
                stats.change_frequency = stats.num_changes / total_time;
            else
                stats.change_frequency = 0;
            end
        end
    end
end
