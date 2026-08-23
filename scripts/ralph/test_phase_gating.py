#!/usr/bin/env python3
"""Regression tests for the manager-controlled PHASE checkpoint."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))

import qwen_iteration


class PhaseGatingTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.phase_path = Path(self.temp.name) / "PHASE"
        self.prd = {
            "userStories": [
                {"id": "US-1", "phase": 1, "priority": 10, "passes": False},
                {"id": "US-2", "phase": 2, "priority": 1, "passes": False},
            ]
        }

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_legacy_project_without_phase_uses_priority(self) -> None:
        with patch.object(qwen_iteration, "PHASE_PATH", self.phase_path):
            self.assertEqual("US-2", qwen_iteration.next_story(self.prd)["id"])

    def test_phase_file_fences_later_work(self) -> None:
        self.phase_path.write_text("1\n", encoding="utf-8")
        with patch.object(qwen_iteration, "PHASE_PATH", self.phase_path):
            self.assertEqual("US-1", qwen_iteration.next_story(self.prd)["id"])

    def test_green_phase_halts_before_later_phase(self) -> None:
        self.phase_path.write_text("1\n", encoding="utf-8")
        self.prd["userStories"][0]["passes"] = True
        with patch.object(qwen_iteration, "PHASE_PATH", self.phase_path):
            self.assertIsNone(qwen_iteration.next_story(self.prd))
            self.assertTrue(qwen_iteration.phase_complete(self.prd))
            self.assertFalse(qwen_iteration.all_passed(self.prd))

    def test_phase_is_not_complete_when_current_story_is_blocked(self) -> None:
        self.phase_path.write_text("1\n", encoding="utf-8")
        self.prd["userStories"][0]["blocked"] = True
        with patch.object(qwen_iteration, "PHASE_PATH", self.phase_path):
            self.assertIsNone(qwen_iteration.next_story(self.prd))
            self.assertFalse(qwen_iteration.phase_complete(self.prd))


if __name__ == "__main__":
    unittest.main()
