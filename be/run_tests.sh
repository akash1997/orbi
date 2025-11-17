#!/bin/bash

# Test runner script for Orbi

set -e  # Exit on error

echo "================================"
echo "Running Orbi Test Suite"
echo "================================"
echo ""

# Check if pytest is available
if ! command -v uv &> /dev/null; then
    echo "Error: uv not found. Please install uv first."
    exit 1
fi

echo "Installing dev dependencies..."
uv sync --all-extras

echo ""
echo "Running unit tests..."
uv run pytest tests/ -m unit -v

echo ""
echo "Running integration tests..."
uv run pytest tests/ -m integration -v

echo ""
echo "Running all tests with coverage..."
uv run pytest tests/ -v --cov=. --cov-report=html --cov-report=term

echo ""
echo "================================"
echo "Tests completed!"
echo "Coverage report: htmlcov/index.html"
echo "================================"
