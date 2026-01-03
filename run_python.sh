#!/bin/bash
# Quick launcher for Python simulation

set -e

echo "=== Adaptive MCS Platooning Simulation (Python) ==="
echo ""

# Check Python version
python_version=$(python3 --version 2>&1 | awk '{print $2}')
echo "Python version: $python_version"

# Check if requirements are installed
echo "Checking dependencies..."
if ! python3 -c "import numpy, scipy, matplotlib" 2>/dev/null; then
    echo "Installing dependencies..."
    pip install -r python_simulation/requirements.txt
else
    echo "Dependencies OK"
fi

echo ""
echo "Starting simulation..."
echo ""

cd python_simulation
python3 run_simulation.py

echo ""
echo "=== Simulation Complete ==="
echo "Results saved in python_simulation/results_*/"
echo ""
echo "To view plots:"
echo "  - Linux: xdg-open results_*/comparison_vs_nlos.png"
echo "  - macOS: open results_*/comparison_vs_nlos.png"
echo "  - Windows: start results_*/comparison_vs_nlos.png"
