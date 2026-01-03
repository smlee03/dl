function plotComparison(results, algorithms, n_blocking_values, ...
                       results_dir, timestamp)
    % plotComparison - Generate comparison plots for different algorithms
    %
    % Inputs:
    %   results: Struct containing simulation results
    %   algorithms: Cell array of algorithm names
    %   n_blocking_values: Array of N_blocking values tested
    %   results_dir: Directory to save plots
    %   timestamp: Timestamp string for filenames

    %% Extract data for plotting
    n_algorithms = length(algorithms);
    n_nlos = length(n_blocking_values);

    % Initialize matrices
    prr_matrix = zeros(n_algorithms, n_nlos);
    prr_std_matrix = zeros(n_algorithms, n_nlos);
    throughput_matrix = zeros(n_algorithms, n_nlos);
    throughput_std_matrix = zeros(n_algorithms, n_nlos);
    mcs_changes_matrix = zeros(n_algorithms, n_nlos);
    avg_mcs_matrix = zeros(n_algorithms, n_nlos);

    for alg_idx = 1:n_algorithms
        for nlos_idx = 1:n_nlos
            key = sprintf('%s_nlos%d', algorithms{alg_idx}, ...
                         n_blocking_values(nlos_idx));

            prr_matrix(alg_idx, nlos_idx) = results.(key).prr_mean;
            prr_std_matrix(alg_idx, nlos_idx) = results.(key).prr_std;
            throughput_matrix(alg_idx, nlos_idx) = results.(key).throughput_mean;
            throughput_std_matrix(alg_idx, nlos_idx) = results.(key).throughput_std;
            mcs_changes_matrix(alg_idx, nlos_idx) = results.(key).mcs_changes_mean;
            avg_mcs_matrix(alg_idx, nlos_idx) = results.(key).avg_mcs_mean;
        end
    end

    %% Figure 1: PRR vs N_blocking
    fig1 = figure('Position', [100, 100, 1200, 400]);

    subplot(1, 3, 1);
    hold on;
    colors = {'b', 'r', 'g', 'm'};
    markers = {'o', 's', '^', 'd'};

    for alg_idx = 1:n_algorithms
        errorbar(n_blocking_values, prr_matrix(alg_idx, :) * 100, ...
                 prr_std_matrix(alg_idx, :) * 100, ...
                 [colors{alg_idx} markers{alg_idx} '-'], 'LineWidth', 2, ...
                 'DisplayName', upper(algorithms{alg_idx}));
    end

    % Target PRR line (90% - 3GPP TS 22.186 requirement)
    yline(90, 'k--', 'Target (90%)', 'LineWidth', 1.5);

    hold off;
    xlabel('Number of Blocking Vehicles');
    ylabel('Packet Reception Ratio (%)');
    title('PRR vs NLOS Severity');
    legend('Location', 'best');
    grid on;
    ylim([0, 105]);

    % Subplot 2: Throughput
    subplot(1, 3, 2);
    hold on;

    for alg_idx = 1:n_algorithms
        errorbar(n_blocking_values, throughput_matrix(alg_idx, :), ...
                 throughput_std_matrix(alg_idx, :), ...
                 [colors{alg_idx} markers{alg_idx} '-'], 'LineWidth', 2, ...
                 'DisplayName', upper(algorithms{alg_idx}));
    end

    hold off;
    xlabel('Number of Blocking Vehicles');
    ylabel('Throughput (kbps)');
    title('Throughput vs NLOS Severity');
    legend('Location', 'best');
    grid on;

    % Subplot 3: MCS Changes (Stability)
    subplot(1, 3, 3);
    hold on;

    for alg_idx = 1:n_algorithms
        plot(n_blocking_values, mcs_changes_matrix(alg_idx, :), ...
             [colors{alg_idx} markers{alg_idx} '-'], 'LineWidth', 2, ...
             'DisplayName', upper(algorithms{alg_idx}));
    end

    hold off;
    xlabel('Number of Blocking Vehicles');
    ylabel('Number of MCS Changes');
    title('MCS Stability');
    legend('Location', 'best');
    grid on;

    % Save figure
    saveas(fig1, sprintf('%s/comparison_vs_nlos_%s.png', results_dir, timestamp));
    saveas(fig1, sprintf('%s/comparison_vs_nlos_%s.fig', results_dir, timestamp));

    %% Figure 2: Algorithm Comparison Bar Charts
    fig2 = figure('Position', [100, 100, 1200, 800]);

    % For each NLOS scenario, create comparison bars
    for nlos_idx = 1:n_nlos
        n_blocking = n_blocking_values(nlos_idx);

        % PRR
        subplot(n_nlos, 3, (nlos_idx-1)*3 + 1);
        bar_data = prr_matrix(:, nlos_idx) * 100;
        bar(bar_data);
        hold on;
        yline(90, 'r--', 'Target', 'LineWidth', 1.5);
        hold off;
        set(gca, 'XTickLabel', upper(algorithms));
        ylabel('PRR (%)');
        title(sprintf('N_{blocking}=%d', n_blocking));
        grid on;
        ylim([0, 105]);

        % Throughput
        subplot(n_nlos, 3, (nlos_idx-1)*3 + 2);
        bar(throughput_matrix(:, nlos_idx));
        set(gca, 'XTickLabel', upper(algorithms));
        ylabel('Throughput (kbps)');
        title(sprintf('N_{blocking}=%d', n_blocking));
        grid on;

        % Average MCS
        subplot(n_nlos, 3, (nlos_idx-1)*3 + 3);
        bar(avg_mcs_matrix(:, nlos_idx));
        set(gca, 'XTickLabel', upper(algorithms));
        ylabel('Average MCS');
        title(sprintf('N_{blocking}=%d', n_blocking));
        grid on;
        ylim([0, 20]);
    end

    % Save figure
    saveas(fig2, sprintf('%s/comparison_bars_%s.png', results_dir, timestamp));
    saveas(fig2, sprintf('%s/comparison_bars_%s.fig', results_dir, timestamp));

    %% Figure 3: Heatmaps
    fig3 = figure('Position', [100, 100, 1200, 400]);

    % PRR Heatmap
    subplot(1, 3, 1);
    imagesc(n_blocking_values, 1:n_algorithms, prr_matrix * 100);
    colorbar;
    colormap(jet);
    caxis([0, 100]);
    set(gca, 'YTick', 1:n_algorithms, 'YTickLabel', upper(algorithms));
    xlabel('Number of Blocking Vehicles');
    ylabel('Algorithm');
    title('PRR (%) Heatmap');

    % Add text annotations
    for i = 1:n_algorithms
        for j = 1:n_nlos
            text(n_blocking_values(j), i, ...
                 sprintf('%.1f', prr_matrix(i, j) * 100), ...
                 'HorizontalAlignment', 'center', ...
                 'Color', 'white', 'FontWeight', 'bold');
        end
    end

    % Throughput Heatmap
    subplot(1, 3, 2);
    imagesc(n_blocking_values, 1:n_algorithms, throughput_matrix);
    colorbar;
    colormap(jet);
    set(gca, 'YTick', 1:n_algorithms, 'YTickLabel', upper(algorithms));
    xlabel('Number of Blocking Vehicles');
    ylabel('Algorithm');
    title('Throughput (kbps) Heatmap');

    % Add text annotations
    for i = 1:n_algorithms
        for j = 1:n_nlos
            text(n_blocking_values(j), i, ...
                 sprintf('%.0f', throughput_matrix(i, j)), ...
                 'HorizontalAlignment', 'center', ...
                 'Color', 'white', 'FontWeight', 'bold');
        end
    end

    % MCS Changes Heatmap
    subplot(1, 3, 3);
    imagesc(n_blocking_values, 1:n_algorithms, mcs_changes_matrix);
    colorbar;
    colormap(jet);
    set(gca, 'YTick', 1:n_algorithms, 'YTickLabel', upper(algorithms));
    xlabel('Number of Blocking Vehicles');
    ylabel('Algorithm');
    title('MCS Changes Heatmap');

    % Add text annotations
    for i = 1:n_algorithms
        for j = 1:n_nlos
            text(n_blocking_values(j), i, ...
                 sprintf('%.0f', mcs_changes_matrix(i, j)), ...
                 'HorizontalAlignment', 'center', ...
                 'Color', 'white', 'FontWeight', 'bold');
        end
    end

    % Save figure
    saveas(fig3, sprintf('%s/heatmaps_%s.png', results_dir, timestamp));
    saveas(fig3, sprintf('%s/heatmaps_%s.fig', results_dir, timestamp));

    fprintf('Plots saved to %s/\n', results_dir);
end
