import tempfile
import unittest
from pathlib import Path
from tools.preservation import expected_blob


class PreservationTests(unittest.TestCase):
    def test_only_exact_reviewed_blob_is_authorized(self):
        root = Path(__file__).resolve().parents[1]
        expected = expected_blob(root, '16d7823', 'scripts/lobby/character_slot.gd', 'old')
        self.assertNotEqual(expected, 'old')
        self.assertEqual(len(expected), 40)
        self.assertNotEqual(expected, '0' * 40)

    def test_unlisted_change_is_not_authorized(self):
        root = Path(__file__).resolve().parents[1]
        self.assertEqual(expected_blob(root, '16d7823', 'assets/unreviewed.obj', 'original'), 'original')

    def test_unknown_baseline_has_no_exceptions(self):
        root = Path(__file__).resolve().parents[1]
        self.assertEqual(expected_blob(root, 'unknown', 'scripts/lobby/character_slot.gd', 'original'), 'original')
