#!/bin/bash
# Quick launcher for MATLAB simulation

set -e

echo "=== Adaptive MCS Platooning Simulation (MATLAB) ==="
echo ""

# Check if MATLAB is available
if ! command -v matlab &> /dev/null; then
    echo "ERROR: MATLAB not found in PATH"
    echo ""
    echo "Options:"
    echo "  1. Add MATLAB to PATH (e.g., export PATH=/usr/local/MATLAB/R2023b/bin:\$PATH)"
    echo "  2. Run MATLAB GUI and execute: cd matlab_simulation; main_platooning_adaptive_mcs"
    echo "  3. Use Python version instead: ./run_python.sh"
    exit 1
fi

matlab_version=$(matlab -batch "version" 2>/dev/null | head -1 || echo "Unknown")
echo "MATLAB version: $matlab_version"
echo ""
echo "Starting simulation..."
echo ""

# Run MATLAB in batch mode
matlab -batch "cd matlab_simulation; main_platooning_adaptive_mcs; exit"

echo ""
echo "=== Simulation Complete ==="
echo "Results saved in matlab_simulation/results/"
echo ""
echo "To view plots:"
echo "  - Linux: xdg-open matlab_simulation/results/comparison_vs_nlos_*.png"
echo "  - macOS: open matlab_simulation/results/comparison_vs_nlos_*.png"
echo "  - Windows: start matlab_simulation/results/comparison_vs_nlos_*.png"
