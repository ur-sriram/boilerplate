#!/usr/bin/env python3
"""
Lightweight hook wrapper delegating to the canonical planning-with-files
session-catchup.py script in .agents/skills/automation/planning-with-files/scripts/.
"""
import os
import runpy
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TARGET = os.path.join(
    ROOT, ".agents", "skills", "automation", "planning-with-files", "scripts", "session-catchup.py"
)

if not os.path.exists(TARGET):
    print(f"[WARN] Canonical session-catchup.py not found at {TARGET}")
    sys.exit(0)

sys.argv[0] = TARGET
runpy.run_path(TARGET, run_name="__main__")
