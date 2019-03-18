#!/usr/bin/env python3
"""
Verification script: Ensures no em dashes (Unicode U+2014) exist anywhere in the repository.
"""

import os
import sys

EM_DASH = "\u2014"
VIOLATIONS = []

IGNORE_DIRS = {".git", "target", "build", ".venv", "__pycache__"}

def scan_file(filepath):
    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            for line_no, line in enumerate(f, start=1):
                if EM_DASH in line:
                    VIOLATIONS.append((filepath, line_no, line.strip()))
    except Exception as e:
        print(f"Error reading {filepath}: {e}", file=sys.stderr)

def main():
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for root, dirs, files in os.walk(root_dir):
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
        for file in files:
            ext = os.path.splitext(file)[1].lower()
            if ext in {".dm", ".dme", ".rs", ".toml", ".py", ".md", ".sh", ".json", ".yaml", ".yml", ".txt"}:
                scan_file(os.path.join(root, file))

    if VIOLATIONS:
        print(f"FAILED: Found {len(VIOLATIONS)} em dash occurrences:")
        for path, line_no, text in VIOLATIONS:
            rel = os.path.relpath(path, root_dir)
            print(f"  {rel}:{line_no}: {text}")
        sys.exit(1)
    else:
        print("PASSED: Zero em dashes detected in codebase.")

if __name__ == "__main__":
    main()
