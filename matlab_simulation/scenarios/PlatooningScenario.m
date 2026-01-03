classdef PlatooningScenario < handle
    % PlatooningScenario - Vehicle platooning scenario configuration
    % All parameters are scientifically justified in ADAPTIVE_MCS_DESIGN.md

    properties (Constant)
        % Vehicle configuration (ETSI TR 103 299)
        N_VEHICLES = 5;             % Typical platoon size in research/pilots

        % Spacing parameters
        INITIAL_SPACING_M = 15;     % Safe distance at highway speeds (SAE J3216)
                                    % Time headway ~0.6s at 25 m/s

        TARGET_SPACING_M = 5;       % Target for automated platooning
                                    % Achieves 15-20% fuel savings

        % Velocity parameters
        BASE_VELOCITY_KMH = 90;     % Typical highway cruising speed
        BASE_VELOCITY_MS = 25;      % Same in m/s

        VELOCITY_DIFFERENTIAL_MS = 0.5;  % Rear vehicles faster (m/s)
                                         % Chosen to achieve 10m spacing
                                         % reduction in 20s: Δd = Δv * t

        % Communication parameters (ETSI EN 302 637-2)
        BEACON_FREQUENCY_HZ = 10;   % CAM transmission frequency for platooning
        PACKET_SIZE_BYTES = 300;    % Typical CAM size (100-300 bytes)

        % Channel parameters (ETSI EN 302 571)
        CARRIER_FREQ_GHZ = 5.9;     % ITS-G5 band
        BANDWIDTH_MHZ = 10;         % Standard ITS channel bandwidth
    end

    properties
        n_vehicles;         % Number of vehicles in platoon
        positions;          % Current positions [m]
        velocities;         % Current velocities [m/s]
        spacings;           % Inter-vehicle spacings [m]
        time;               % Current simulation time [s]
    end

    methods
        function obj = PlatooningScenario(n_vehicles)
            % Constructor
            % n_vehicles: Number of vehicles (default: 5)

            if nargin < 1
                n_vehicles = obj.N_VEHICLES;
            end

            obj.n_vehicles = n_vehicles;
            obj.time = 0;

            % Initialize vehicle positions (leader at origin)
            obj.positions = zeros(1, n_vehicles);
            for i = 2:n_vehicles
                obj.positions(i) = obj.positions(i-1) - obj.INITIAL_SPACING_M;
            end

            % Initialize velocities (rear vehicles faster for convergence)
            obj.velocities = obj.BASE_VELOCITY_MS * ones(1, n_vehicles);
            for i = 2:n_vehicles
                % Vehicle i has additional speed to close gap
                obj.velocities(i) = obj.BASE_VELOCITY_MS + ...
                                   (i-1) * obj.VELOCITY_DIFFERENTIAL_MS;
            end

            % Calculate initial spacings
            obj.updateSpacings();
        end

        function updateSpacings(obj)
            % Update inter-vehicle spacings

            obj.spacings = zeros(1, obj.n_vehicles - 1);
            for i = 1:obj.n_vehicles-1
                obj.spacings(i) = obj.positions(i) - obj.positions(i+1);
            end
        end

        function update(obj, dt)
            % Update vehicle positions
            % dt: Time step in seconds

            % Update positions based on velocities
            obj.positions = obj.positions + obj.velocities * dt;

            % Simple platoon control: maintain target spacing
            for i = 2:obj.n_vehicles
                current_spacing = obj.positions(i-1) - obj.positions(i);
                spacing_error = current_spacing - obj.TARGET_SPACING_M;

                % Simple proportional controller
                % K_p = 0.3 chosen for stable convergence without oscillation
                K_p = 0.3;
                velocity_adjustment = K_p * spacing_error;

                % Limit velocity adjustment to prevent instability
                max_adjustment = 2;  % m/s
                velocity_adjustment = max(-max_adjustment, ...
                                          min(max_adjustment, velocity_adjustment));

                % Update velocity
                obj.velocities(i) = obj.BASE_VELOCITY_MS + velocity_adjustment;
            end

            % Update spacings
            obj.updateSpacings();

            % Update time
            obj.time = obj.time + dt;
        end

        function distance = getDistance(obj, vehicle_i, vehicle_j)
            % Get distance between two vehicles
            % Inputs:
            %   vehicle_i, vehicle_j: Vehicle indices (1-based)
            % Output:
            %   distance: Distance in meters

            distance = abs(obj.positions(vehicle_i) - obj.positions(vehicle_j));
        end

        function n_blocking = getNBlockingVehicles(obj, tx_vehicle, rx_vehicle)
            % Get number of blocking vehicles between transmitter and receiver
            % Inputs:
            %   tx_vehicle: Transmitter vehicle index
            %   rx_vehicle: Receiver vehicle index
            % Output:
            %   n_blocking: Number of vehicles blocking the LOS

            % Vehicles are in a line, so blocking vehicles are those between
            min_idx = min(tx_vehicle, rx_vehicle);
            max_idx = max(tx_vehicle, rx_vehicle);

            n_blocking = max_idx - min_idx - 1;

            % Cap at 5 (maximum considered in NLOS model)
            n_blocking = min(n_blocking, 5);
        end

        function stats = getStatistics(obj)
            % Get scenario statistics

            stats.n_vehicles = obj.n_vehicles;
            stats.current_time = obj.time;
            stats.positions = obj.positions;
            stats.velocities = obj.velocities;
            stats.spacings = obj.spacings;
            stats.avg_spacing = mean(obj.spacings);
            stats.min_spacing = min(obj.spacings);
            stats.max_spacing = max(obj.spacings);
        end

        function plotScenario(obj, figure_handle)
            % Plot current platoon configuration
            % Input:
            %   figure_handle: Figure handle (optional)

            if nargin < 2
                figure_handle = figure();
            end

            figure(figure_handle);

            % Plot 1: Vehicle positions
            subplot(3, 1, 1);
            plot(obj.positions, zeros(size(obj.positions)), 'bo', ...
                 'MarkerSize', 10, 'LineWidth', 2);
            xlabel('Position [m]');
            ylabel('Lane');
            title(sprintf('Platoon Configuration at t=%.1fs', obj.time));
            grid on;
            ylim([-1, 1]);

            % Add vehicle labels
            for i = 1:obj.n_vehicles
                text(obj.positions(i), 0.3, sprintf('V%d', i), ...
                     'HorizontalAlignment', 'center');
            end

            % Plot 2: Inter-vehicle spacings
            subplot(3, 1, 2);
            spacing_positions = zeros(1, obj.n_vehicles-1);
            for i = 1:obj.n_vehicles-1
                spacing_positions(i) = (obj.positions(i) + obj.positions(i+1)) / 2;
            end
            bar(spacing_positions, obj.spacings);
            hold on;
            yline(obj.TARGET_SPACING_M, 'r--', 'Target', 'LineWidth', 2);
            yline(obj.INITIAL_SPACING_M, 'g--', 'Initial', 'LineWidth', 2);
            hold off;
            xlabel('Position [m]');
            ylabel('Spacing [m]');
            title('Inter-Vehicle Spacings');
            grid on;

            % Plot 3: Velocities
            subplot(3, 1, 3);
            bar(obj.positions, obj.velocities * 3.6);  % Convert to km/h
            hold on;
            yline(obj.BASE_VELOCITY_KMH, 'r--', 'Target', 'LineWidth', 2);
            hold off;
            xlabel('Position [m]');
            ylabel('Velocity [km/h]');
            title('Vehicle Velocities');
            grid on;
        end
    end
end
