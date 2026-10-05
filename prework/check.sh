#!/usr/bin/env bash
# Kubernetes Playground — pre-work PASS/FAIL check.
# Install-only: verifies your machine is ready for session 1. Does not
# install or change anything.

set -uo pipefail

FAIL=0

pass() { printf '  [PASS] %s\n' "$1"; }
fail() { printf '  [FAIL] %s\n' "$1"; FAIL=1; }

echo "Kubernetes Playground — pre-work check"
echo "========================================"

# --- Linux command line basics -----------------------------------------
echo ""
echo "Shell basics:"
for cmd in bash curl git; do
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "$cmd found"
  else
    fail "$cmd not found — install it before session 1"
  fi
done

# --- Docker ---------------------------------------------------------------
echo ""
echo "Docker:"
if command -v docker >/dev/null 2>&1; then
  pass "docker CLI found ($(docker --version 2>/dev/null))"
else
  fail "docker not found — install Docker Desktop (or Docker Engine on Linux)"
fi

if docker info >/dev/null 2>&1; then
  pass "docker daemon is running"
else
  fail "docker daemon is NOT running — start Docker Desktop and re-run this check"
fi

# --- Summary ---------------------------------------------------------------
echo ""
echo "========================================"
if [[ "$FAIL" -eq 0 ]]; then
  echo "Result: PASS — you're ready for session 1."
  exit 0
else
  echo "Result: FAIL — fix the items above and re-run this script."
  exit 1
fi
