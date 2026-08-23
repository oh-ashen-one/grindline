#!/usr/bin/env python3
"""Compatibility entrypoint.

Phase gating now lives in qwen_iteration.py whenever scripts/ralph/PHASE exists,
so the phased and standard runners cannot drift into different harnesses.
"""

from __future__ import annotations

import sys

from qwen_iteration import main


if __name__ == "__main__":
    sys.exit(main())
