#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Maurice Garcia

set -euo pipefail

# FILE: scripts/init-repo.sh
#
# Create a PyPNM/PyPNM-CMTS-style repo skeleton for a DOCSIS OFDM profile effectiveness simulator.
#
# Project name: pypnm-docsis-pma
# Python package: pypnm_docsis_pma
#
# Usage:
#   bash scripts/init-repo.sh
#   bash scripts/init-repo.sh /path/to/new/repo
#
# Notes:
# - This script creates directories and files and writes minimal stubs.
# - Re-running is safe; it will not delete existing content.

ROOT_DIR="${1:-$(pwd)}"
PROJECT_NAME="pypnm-docsis-pma"
PKG_NAME="pypnm_docsis_pma"

mkdir -p "${ROOT_DIR}"
cd "${ROOT_DIR}"

mkdir -p \
  "config" \
  "data" \
  "docs" \
  "logs" \
  "output" \
  "scripts" \
  "src/${PKG_NAME}" \
  "src/${PKG_NAME}/channel" \
  "src/${PKG_NAME}/fec" \
  "src/${PKG_NAME}/interleaver" \
  "src/${PKG_NAME}/models" \
  "src/${PKG_NAME}/ofdm" \
  "src/${PKG_NAME}/profile" \
  "src/${PKG_NAME}/qam" \
  "src/${PKG_NAME}/runner" \
  "src/${PKG_NAME}/source" \
  "src/${PKG_NAME}/tools" \
  "tests" \
  "tests/channel" \
  "tests/fec" \
  "tests/interleaver" \
  "tests/models" \
  "tests/ofdm" \
  "tests/profile" \
  "tests/qam" \
  "tests/runner" \
  "tests/source"

touch \
  ".gitignore" \
  "LICENSE" \
  "README.md" \
  "pyproject.toml" \
  "mkdocs.yml" \
  "config/system.json" \
  "docs/index.md" \
  "docs/design.md" \
  "scripts/init-repo.sh" \
  "src/${PKG_NAME}/__init__.py" \
  "src/${PKG_NAME}/__main__.py" \
  "src/${PKG_NAME}/channel/__init__.py" \
  "src/${PKG_NAME}/channel/channel_model.py" \
  "src/${PKG_NAME}/fec/__init__.py" \
  "src/${PKG_NAME}/fec/bch.py" \
  "src/${PKG_NAME}/fec/ldpc.py" \
  "src/${PKG_NAME}/fec/rate_match.py" \
  "src/${PKG_NAME}/interleaver/__init__.py" \
  "src/${PKG_NAME}/interleaver/freq_interleaver.py" \
  "src/${PKG_NAME}/interleaver/time_interleaver.py" \
  "src/${PKG_NAME}/models/__init__.py" \
  "src/${PKG_NAME}/models/config_models.py" \
  "src/${PKG_NAME}/models/result_models.py" \
  "src/${PKG_NAME}/ofdm/__init__.py" \
  "src/${PKG_NAME}/ofdm/numerology.py" \
  "src/${PKG_NAME}/ofdm/modem.py" \
  "src/${PKG_NAME}/profile/__init__.py" \
  "src/${PKG_NAME}/profile/profile_model.py" \
  "src/${PKG_NAME}/qam/__init__.py" \
  "src/${PKG_NAME}/qam/mapper.py" \
  "src/${PKG_NAME}/qam/demapper.py" \
  "src/${PKG_NAME}/runner/__init__.py" \
  "src/${PKG_NAME}/runner/sim_runner.py" \
  "src/${PKG_NAME}/source/__init__.py" \
  "src/${PKG_NAME}/source/payload.py" \
  "src/${PKG_NAME}/source/bit_packing.py" \
  "src/${PKG_NAME}/tools/__init__.py" \
  "tests/__init__.py" \
  "tests/test_smoke.py"

if [[ ! -s ".gitignore" ]]; then
  cat > ".gitignore" <<'EOF'
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Maurice Garcia

__pycache__/
*.py[cod]
*.egg-info/
dist/
build/
.pytest_cache/
.coverage
.coverage.*
htmlcov/
.mypy_cache/
.ruff_cache/
.venv/
.env

logs/
output/
data/
EOF
fi

if [[ ! -s "README.md" ]]; then
  cat > "README.md" <<EOF
<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 Maurice Garcia -->

# ${PROJECT_NAME}

This repository scaffolds a CMTS → noise/plant → CM simulation pipeline for evaluating DOCSIS downstream OFDM profiles (bit-loading up to 16KQAM) against RxMER-driven conditions.

## Layout

- \`src/${PKG_NAME}/\` : simulator package
- \`tests/\` : unit tests
- \`docs/\` : MkDocs documentation
- \`config/\` : run/config defaults
- \`scripts/\` : repo utilities

EOF
fi

if [[ ! -s "pyproject.toml" ]]; then
  cat > "pyproject.toml" <<EOF
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Maurice Garcia

[build-system]
requires = ["setuptools>=68", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "${PROJECT_NAME}"
version = "0.0.0"
description = "DOCSIS OFDM profile effectiveness simulator (CMTS -> noise -> CM)."
readme = "README.md"
requires-python = ">=3.11"
license = { text = "Apache-2.0" }
authors = [{ name = "Maurice Garcia" }]

dependencies = [
  "numpy>=1.26",
  "scipy>=1.11",
  "numba>=0.59",
  "pydantic>=2.7",
]

[project.optional-dependencies]
dev = [
  "pytest>=8.0",
  "ruff>=0.5",
  "mypy>=1.8",
  "matplotlib>=3.8",
  "pandas>=2.2",
  "mkdocs>=1.6",
  "mkdocs-material>=9.5",
]

[tool.pytest.ini_options]
testpaths = ["tests"]

[tool.ruff]
line-length = 132
EOF
fi

if [[ ! -s "mkdocs.yml" ]]; then
  cat > "mkdocs.yml" <<EOF
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Maurice Garcia

site_name: ${PROJECT_NAME}
theme:
  name: material
nav:
  - Home: index.md
  - Design: design.md
EOF
fi

if [[ ! -s "docs/index.md" ]]; then
  cat > "docs/index.md" <<'EOF'
<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 Maurice Garcia -->

# Overview

This documentation covers the simulator pipeline and development plan.

EOF
fi

if [[ ! -s "docs/design.md" ]]; then
  cat > "docs/design.md" <<'EOF'
<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 Maurice Garcia -->

# Design

See the simulator flow and phased development plan in the project notes.

EOF
fi

if [[ ! -s "config/system.json" ]]; then
  cat > "config/system.json" <<'EOF'
{
  "SimulatorDefaults": {
    "seed": 51966,
    "payload_bytes": 2048,
    "symbols": 4
  }
}
EOF
fi

if [[ ! -s "src/${PKG_NAME}/__init__.py" ]]; then
  cat > "src/${PKG_NAME}/__init__.py" <<'EOF'
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Maurice Garcia

__all__ = [
  "__version__",
]

__version__ = "0.0.0"
EOF
fi

if [[ ! -s "src/${PKG_NAME}/__main__.py" ]]; then
  cat > "src/${PKG_NAME}/__main__.py" <<'EOF'
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Maurice Garcia

def main() -> int:
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
EOF
fi

if [[ ! -s "tests/test_smoke.py" ]]; then
  cat > "tests/test_smoke.py" <<'EOF'
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Maurice Garcia

def test_smoke() -> None:
    assert True
EOF
fi

printf "Scaffold created under: %s\n" "${ROOT_DIR}"
printf "Project: %s\n" "${PROJECT_NAME}"
printf "Package: %s\n" "${PKG_NAME}"
printf "Next:\n"
printf "  python -m venv .venv && source .venv/bin/activate\n"
printf "  python -m pip install -e '.[dev]'\n"
printf "  pytest\n"
