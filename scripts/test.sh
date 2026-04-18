#!/usr/bin/env bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Running melos.nvim tests...${NC}"

if ! command -v nvim &>/dev/null; then
  echo -e "${RED}Error: Neovim is not installed or not in PATH${NC}"
  exit 1
fi

if ! command -v yq &>/dev/null; then
  echo -e "${RED}Error: yq is not installed or not in PATH${NC}"
  exit 1
fi

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES_DIR="$PLUGIN_DIR/tests/fixtures"

run_nvim_test() {
  local test_dir="$1"
  local lua_snippet="$2"
  local label="$3"

  local init_lua
  local _init_tmp
  _init_tmp=$(mktemp "${TMPDIR:-/tmp}/melos_test_init.XXXXXX")
  init_lua="${_init_tmp}.lua"
  mv "$_init_tmp" "$init_lua"

  # Expand variables now; lua_snippet is passed verbatim
  cat >"$init_lua" <<BASHEOF
vim.o.runtimepath = vim.o.runtimepath .. ',$PLUGIN_DIR'
vim.fn.chdir('$test_dir')
local ok, err = pcall(function()
$lua_snippet
end)
if not ok then
  io.stderr:write('TEST FAILED [$label]: ' .. tostring(err) .. '\n')
  vim.cmd('cquit 1')
end
vim.cmd('qall!')
BASHEOF

  local result=0
  nvim --headless --noplugin -u "$init_lua" 2>/dev/null || result=$?
  rm -f "$init_lua"
  if [ "$result" -eq 0 ]; then
    echo -e "${GREEN}✓ $label${NC}"
    return 0
  else
    echo -e "${RED}✗ $label${NC}"
    return 1
  fi
}

cleanup_code=0

# ---- basic smoke: config + parser load (no telescope) ----

BASIC_DIR=$(mktemp -d)
cat >"$BASIC_DIR/melos.yaml" <<'EOF'
name: smoke
scripts:
  hello: echo hello
EOF

run_nvim_test "$BASIC_DIR" "
local config = require('melos.config')
assert(type(config) == 'table', 'config should be table')
assert(config.options.config_file == 'auto', 'default config_file should be auto')
local parser = require('melos.parser')
assert(type(parser.get_scripts) == 'function', 'get_scripts should be function')
assert(type(parser.get_config_descriptor) == 'function', 'get_config_descriptor should be function')
" "basic: config + parser load"
if [ $? -ne 0 ]; then cleanup_code=1; fi

# ---- v6 fixture test ----

V6_DIR=$(mktemp -d)
cp "$FIXTURES_DIR/v6_melos.yaml" "$V6_DIR/melos.yaml"

run_nvim_test "$V6_DIR" "
local parser = require('melos.parser')
local desc = parser.get_config_descriptor()
assert(desc ~= nil, 'descriptor should not be nil')
assert(desc.flavor == 'v6', 'flavor should be v6, got: ' .. tostring(desc.flavor))
local scripts = parser.get_scripts()
assert(#scripts > 0, 'scripts should not be empty')
local names = {}
for _, s in ipairs(scripts) do names[s.name] = true end
assert(names['build'], 'build script missing')
assert(names['test'], 'test script missing')
assert(names['lint'], 'lint script missing')
" "v6 fixture: descriptor + scripts"
if [ $? -ne 0 ]; then cleanup_code=1; fi

# ---- v7 fixture test (names + line numbers) ----
# Expected line numbers from tests/fixtures/v7_pubspec.yaml:
#   build=7, check=10, format=14, build_runner=18, parallel_format=23

V7_DIR=$(mktemp -d)
cp "$FIXTURES_DIR/v7_pubspec.yaml" "$V7_DIR/pubspec.yaml"

run_nvim_test "$V7_DIR" "
local parser = require('melos.parser')
local desc = parser.get_config_descriptor()
assert(desc ~= nil, 'descriptor should not be nil')
assert(desc.flavor == 'v7', 'flavor should be v7, got: ' .. tostring(desc.flavor))
local scripts = parser.get_scripts()
assert(#scripts > 0, 'scripts should not be empty')
local by_name = {}
for _, s in ipairs(scripts) do by_name[s.name] = s end
assert(by_name['build'], 'build script missing')
assert(by_name['check'], 'check script missing')
assert(by_name['format'], 'format script missing')
assert(by_name['build_runner'], 'build_runner script missing')
assert(by_name['parallel_format'], 'parallel_format script missing')
-- line number assertions (MelosEdit acceptance criterion)
assert(by_name['build'].line == 7, 'build line should be 7, got: ' .. tostring(by_name['build'].line))
assert(by_name['check'].line == 10, 'check line should be 10, got: ' .. tostring(by_name['check'].line))
assert(by_name['format'].line == 14, 'format line should be 14, got: ' .. tostring(by_name['format'].line))
assert(by_name['build_runner'].line == 18, 'build_runner line should be 18, got: ' .. tostring(by_name['build_runner'].line))
assert(by_name['parallel_format'].line == 23, 'parallel_format line should be 23, got: ' .. tostring(by_name['parallel_format'].line))
" "v7 fixture: descriptor + scripts + line numbers"
if [ $? -ne 0 ]; then cleanup_code=1; fi

# ---- v7 group exclusion test ----

V7G_DIR=$(mktemp -d)
cp "$FIXTURES_DIR/v7_pubspec_with_group.yaml" "$V7G_DIR/pubspec.yaml"

run_nvim_test "$V7G_DIR" "
local parser = require('melos.parser')
local scripts = parser.get_scripts()
assert(#scripts > 0, 'scripts should not be empty')
local names = {}
for _, s in ipairs(scripts) do names[s.name] = true end
assert(names['build'], 'build script should be present')
assert(not names['ci'], 'ci group should be excluded')
" "v7 group fixture: group excluded, build present"
if [ $? -ne 0 ]; then cleanup_code=1; fi

# ---- v7 minimal (null scripts) test ----

V7M_DIR=$(mktemp -d)
cp "$FIXTURES_DIR/v7_pubspec_minimal.yaml" "$V7M_DIR/pubspec.yaml"

run_nvim_test "$V7M_DIR" "
local parser = require('melos.parser')
local scripts = parser.get_scripts()
assert(type(scripts) == 'table', 'scripts should be a table')
assert(#scripts == 0, 'scripts should be empty for null scripts section')
" "v7 minimal fixture: empty scripts"
if [ $? -ne 0 ]; then cleanup_code=1; fi

# ---- both files exist: v6 priority (auto mode) ----

BOTH_DIR=$(mktemp -d)
cp "$FIXTURES_DIR/both_melos.yaml" "$BOTH_DIR/melos.yaml"
cp "$FIXTURES_DIR/both_pubspec.yaml" "$BOTH_DIR/pubspec.yaml"

run_nvim_test "$BOTH_DIR" "
local parser = require('melos.parser')
local desc = parser.get_config_descriptor()
assert(desc ~= nil, 'descriptor should not be nil')
assert(desc.flavor == 'v6', 'both present: flavor should be v6 (melos.yaml priority), got: ' .. tostring(desc.flavor))
" "both files: auto mode uses v6 (melos.yaml priority)"
if [ $? -ne 0 ]; then cleanup_code=1; fi

# ---- both files exist: pubspec.yaml forced via config_file ----

BOTH_V7_DIR=$(mktemp -d)
cp "$FIXTURES_DIR/both_melos.yaml" "$BOTH_V7_DIR/melos.yaml"
cp "$FIXTURES_DIR/both_pubspec.yaml" "$BOTH_V7_DIR/pubspec.yaml"

run_nvim_test "$BOTH_V7_DIR" "
local config = require('melos.config')
config.setup({ config_file = 'pubspec.yaml' })
local parser = require('melos.parser')
local desc = parser.get_config_descriptor()
assert(desc ~= nil, 'descriptor should not be nil')
assert(desc.flavor == 'v7', 'forced pubspec.yaml: flavor should be v7, got: ' .. tostring(desc.flavor))
" "both files: config_file=pubspec.yaml forces v7"
if [ $? -ne 0 ]; then cleanup_code=1; fi

# ---- config_file validation test ----

CFG_DIR=$(mktemp -d)
cp "$FIXTURES_DIR/v6_melos.yaml" "$CFG_DIR/melos.yaml"

run_nvim_test "$CFG_DIR" "
local config = require('melos.config')
config.setup({ config_file = 'invalid_value' })
assert(config.options.config_file == 'auto', 'invalid config_file should fall back to auto')
" "config_file validation: fallback to auto"
if [ $? -ne 0 ]; then cleanup_code=1; fi

# ---- v6 kind + description assertions ----

V6_KIND_DIR=$(mktemp -d)
cp "$FIXTURES_DIR/v6_melos.yaml" "$V6_KIND_DIR/melos.yaml"

run_nvim_test "$V6_KIND_DIR" "
local parser = require('melos.parser')
local scripts = parser.get_scripts()
local by_name = {}
for _, s in ipairs(scripts) do by_name[s.name] = s end
-- string kind: bare string value
assert(by_name['test'].kind == 'string', 'test kind should be string, got: ' .. tostring(by_name['test'].kind))
assert(by_name['test'].description ~= '', 'test description should be non-empty fallback')
-- run kind
assert(by_name['build'].kind == 'run', 'build kind should be run, got: ' .. tostring(by_name['build'].kind))
assert(by_name['build'].description == 'Build APK', 'build description mismatch')
assert(by_name['lint'].kind == 'run', 'lint kind should be run, got: ' .. tostring(by_name['lint'].kind))
-- command/id/name fields present
assert(by_name['build'].command == 'build', 'command should equal name')
assert(by_name['build'].id == 'build', 'id should equal name')
assert(by_name['build'].name == 'build', 'name field missing')
" "v6 fixture: kind + description + object shape"
if [ $? -ne 0 ]; then cleanup_code=1; fi

# ---- v7 kind + description assertions ----

V7_KIND_DIR=$(mktemp -d)
cp "$FIXTURES_DIR/v7_pubspec.yaml" "$V7_KIND_DIR/pubspec.yaml"

run_nvim_test "$V7_KIND_DIR" "
local parser = require('melos.parser')
local scripts = parser.get_scripts()
local by_name = {}
for _, s in ipairs(scripts) do by_name[s.name] = s end
-- run kind with description
assert(by_name['build'].kind == 'run', 'build kind should be run')
assert(by_name['build'].description == 'Build APK', 'build description mismatch')
-- run kind with description (build_runner)
assert(by_name['build_runner'].kind == 'run', 'build_runner kind should be run')
assert(by_name['build_runner'].description == 'Codegen', 'build_runner description mismatch')
-- steps kind: fallback description
assert(by_name['check'].kind == 'steps', 'check kind should be steps')
assert(by_name['check'].description:find('^%[steps%]'), 'check desc should start with [steps]')
-- exec kind (string): fallback description
assert(by_name['format'].kind == 'exec', 'format kind should be exec')
assert(by_name['format'].description:find('^%[exec%]'), 'format desc should start with [exec]')
-- exec kind (object): fallback uses exec.run
assert(by_name['parallel_format'].kind == 'exec', 'parallel_format kind should be exec')
assert(by_name['parallel_format'].description:find('^%[exec%]'), 'parallel_format desc should start with [exec]')
-- all objects have required fields
for _, s in ipairs(scripts) do
  assert(type(s.name) == 'string', 'name missing for entry')
  assert(type(s.description) == 'string', 'description missing for: ' .. tostring(s.name))
  assert(s.command == s.name, 'command != name for: ' .. tostring(s.name))
  assert(s.id == s.name, 'id != name for: ' .. tostring(s.name))
  assert(type(s.line) == 'number', 'line not number for: ' .. tostring(s.name))
  assert(type(s.kind) == 'string', 'kind missing for: ' .. tostring(s.name))
end
" "v7 fixture: kind + description + object shape"
if [ $? -ne 0 ]; then cleanup_code=1; fi

# ---- descriptor shape assertions ----

DESC_DIR=$(mktemp -d)
cp "$FIXTURES_DIR/v6_melos.yaml" "$DESC_DIR/melos.yaml"

run_nvim_test "$DESC_DIR" "
local parser = require('melos.parser')
local desc = parser.get_config_descriptor()
assert(desc ~= nil, 'descriptor should not be nil')
assert(type(desc.path) == 'string' and desc.path ~= '', 'path missing')
assert(desc.flavor == 'v6', 'flavor should be v6')
assert(desc.yq_scripts_query == '.scripts', 'yq_scripts_query wrong for v6')
assert(desc.scripts_anchor == 'scripts', 'scripts_anchor wrong for v6')
assert(desc.nested_key == nil, 'nested_key should be nil for v6')
" "v6 descriptor: shape validation"
if [ $? -ne 0 ]; then cleanup_code=1; fi

DESC_V7_DIR=$(mktemp -d)
cp "$FIXTURES_DIR/v7_pubspec.yaml" "$DESC_V7_DIR/pubspec.yaml"

run_nvim_test "$DESC_V7_DIR" "
local parser = require('melos.parser')
local desc = parser.get_config_descriptor()
assert(desc ~= nil, 'descriptor should not be nil')
assert(type(desc.path) == 'string' and desc.path ~= '', 'path missing')
assert(desc.flavor == 'v7', 'flavor should be v7')
assert(desc.yq_scripts_query == '.melos.scripts', 'yq_scripts_query wrong for v7')
assert(desc.scripts_anchor == 'melos', 'scripts_anchor wrong for v7')
assert(desc.nested_key == 'scripts', 'nested_key should be scripts for v7')
" "v7 descriptor: shape validation"
if [ $? -ne 0 ]; then cleanup_code=1; fi

# ---- edge case: script names colliding with YAML field keys (run/steps/exec) ----
# Verifies that script_key_indent prevents false hits on sub-fields.

EDGE_DIR=$(mktemp -d)
cp "$FIXTURES_DIR/v7_pubspec_edge.yaml" "$EDGE_DIR/pubspec.yaml"

run_nvim_test "$EDGE_DIR" "
local parser = require('melos.parser')
local scripts = parser.get_scripts()
local by_name = {}
for _, s in ipairs(scripts) do by_name[s.name] = s end
-- Script named 'run' must match at line 7 (script-key indent), NOT sub-field .run
assert(by_name['run'] ~= nil, 'script named run should exist')
assert(by_name['run'].line == 7, 'run line should be 7, got: ' .. tostring(by_name['run'] and by_name['run'].line))
assert(by_name['run'].kind == 'run', 'run kind should be run')
assert(by_name['run'].description == 'Script named run', 'run description mismatch')
-- Script named 'steps'
assert(by_name['steps'] ~= nil, 'script named steps should exist')
assert(by_name['steps'].line == 10, 'steps line should be 10, got: ' .. tostring(by_name['steps'] and by_name['steps'].line))
assert(by_name['steps'].kind == 'steps', 'steps kind should be steps')
-- Script named 'exec'
assert(by_name['exec'] ~= nil, 'script named exec should exist')
assert(by_name['exec'].line == 14, 'exec line should be 14, got: ' .. tostring(by_name['exec'] and by_name['exec'].line))
assert(by_name['exec'].kind == 'exec', 'exec kind should be exec')
-- desc_only: {description} only => kind=unknown
assert(by_name['desc_only'] ~= nil, 'desc_only should exist')
assert(by_name['desc_only'].kind == 'unknown', 'desc_only kind should be unknown, got: ' .. tostring(by_name['desc_only'] and by_name['desc_only'].kind))
assert(by_name['desc_only'].description == 'Only description, no run/steps/exec', 'desc_only description mismatch')
-- hyphen in script name: Lua pattern "-" must be escaped correctly
assert(by_name['my-script'] ~= nil, 'my-script should exist in parsed scripts')
assert(by_name['my-script'].line == 18, 'my-script line should be 18, got: ' .. tostring(by_name['my-script'] and by_name['my-script'].line))
assert(by_name['my_script'] ~= nil, 'my_script should exist')
assert(by_name['my_script'].line == 20, 'my_script line should be 20, got: ' .. tostring(by_name['my_script'] and by_name['my_script'].line))
" "edge: collision names (run/steps/exec) + unknown kind + special chars"
if [ $? -ne 0 ]; then cleanup_code=1; fi

# ---- hyphen in v6 script name: line number must be non-zero ----
# build-apk=line 4, run-tests=line 7 in v6_melos_hyphen.yaml

V6H_DIR=$(mktemp -d)
cp "$FIXTURES_DIR/v6_melos_hyphen.yaml" "$V6H_DIR/melos.yaml"

run_nvim_test "$V6H_DIR" "
local parser = require('melos.parser')
local scripts = parser.get_scripts()
local by_name = {}
for _, s in ipairs(scripts) do by_name[s.name] = s end
assert(by_name['build-apk'] ~= nil, 'build-apk should exist')
assert(by_name['build-apk'].line == 4, 'build-apk line should be 4, got: ' .. tostring(by_name['build-apk'] and by_name['build-apk'].line))
assert(by_name['run-tests'] ~= nil, 'run-tests should exist')
assert(by_name['run-tests'].line == 7, 'run-tests line should be 7, got: ' .. tostring(by_name['run-tests'] and by_name['run-tests'].line))
" "v6 hyphen script names: line numbers correct"
if [ $? -ne 0 ]; then cleanup_code=1; fi

# ---- edge case: pubspec.yaml without melos key (no melos.yaml present) ----
# Verifies pubspec without melos: is not misidentified as v7.

NO_MELOS_DIR=$(mktemp -d)
cp "$FIXTURES_DIR/pubspec_no_melos.yaml" "$NO_MELOS_DIR/pubspec.yaml"

run_nvim_test "$NO_MELOS_DIR" "
local parser = require('melos.parser')
local desc = parser.get_config_descriptor()
assert(desc == nil, 'descriptor should be nil when no melos config exists')
local scripts = parser.get_scripts()
assert(type(scripts) == 'table', 'get_scripts should return table')
assert(#scripts == 0, 'scripts should be empty when no config found')
" "edge: pubspec without melos key => nil descriptor"
if [ $? -ne 0 ]; then cleanup_code=1; fi

# ---- edge case: pubspec without melos key, melos.yaml present => v6 fallback ----

NO_MELOS_V6_DIR=$(mktemp -d)
cp "$FIXTURES_DIR/pubspec_no_melos.yaml" "$NO_MELOS_V6_DIR/pubspec.yaml"
cp "$FIXTURES_DIR/v6_melos.yaml" "$NO_MELOS_V6_DIR/melos.yaml"

run_nvim_test "$NO_MELOS_V6_DIR" "
local parser = require('melos.parser')
local desc = parser.get_config_descriptor()
assert(desc ~= nil, 'descriptor should not be nil')
assert(desc.flavor == 'v6', 'with melos.yaml present, flavor should be v6')
" "edge: pubspec without melos key + melos.yaml => v6"
if [ $? -ne 0 ]; then cleanup_code=1; fi

# ---- CI workflow syntax check ----

run_nvim_test "$PLUGIN_DIR" "
local ok = vim.fn.filereadable('$PLUGIN_DIR/.github/workflows/test.yml') == 1
assert(ok, '.github/workflows/test.yml should exist')
" "CI: test.yml exists"
if [ $? -ne 0 ]; then cleanup_code=1; fi

# ---- CI workflow YAML validity ----

if command -v yq &>/dev/null; then
  if yq e '.' "$PLUGIN_DIR/.github/workflows/test.yml" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ CI: test.yml is valid YAML${NC}"
  else
    echo -e "${RED}✗ CI: test.yml is invalid YAML${NC}"
    cleanup_code=1
  fi
fi

# ---- result ----

if [ $cleanup_code -eq 0 ]; then
  echo -e "${GREEN}✓ All tests passed${NC}"
else
  echo -e "${RED}✗ Some tests failed${NC}"
fi

exit $cleanup_code
