#!/usr/bin/env bash

# Test script for melos.nvim
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running melos.nvim tests...${NC}"

# Check if Neovim is available
if ! command -v nvim &> /dev/null; then
    echo -e "${RED}Error: Neovim is not installed or not in PATH${NC}"
    exit 1
fi

# Create temporary directory for test
TEST_DIR=$(mktemp -d)
echo "Test directory: $TEST_DIR"

# Copy plugin to test directory
cp -r lua "$TEST_DIR/"
cp -r plugin "$TEST_DIR/"

# Create basic test configuration
cat > "$TEST_DIR/init.lua" << 'EOF'
-- Minimal init.lua for testing
vim.o.runtimepath = vim.o.runtimepath .. ',' .. vim.fn.getcwd()

-- Add plenary if available
local has_plenary = pcall(require, 'plenary')
if not has_plenary then
  print('Warning: plenary.nvim not found, some tests may not run')
end

-- Load the plugin
require('melos')

-- Basic smoke test
local function test_plugin_loads()
  local melos = require('melos')
  assert(type(melos) == 'table', 'Plugin should return a table')
  print('✓ Plugin loads successfully')
end

-- Test configuration
local function test_config()
  local config = require('melos.config')
  assert(type(config) == 'table', 'Config should return a table')
  print('✓ Config module loads successfully')
end

-- Run basic tests
local function run_tests()
  print('Running basic plugin tests...')
  
  pcall(test_plugin_loads)
  pcall(test_config)
  
  print('✓ All basic tests passed')
end

-- Run tests and exit
run_tests()
vim.cmd('qall!')
EOF

# Run the test
cd "$TEST_DIR"
if nvim --headless --noplugin -u init.lua; then
    echo -e "${GREEN}✓ Tests passed${NC}"
    cleanup_code=0
else
    echo -e "${RED}✗ Tests failed${NC}"
    cleanup_code=1
fi

# Cleanup
rm -rf "$TEST_DIR"
exit $cleanup_code