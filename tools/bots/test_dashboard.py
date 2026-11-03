#!/usr/bin/env python3
"""Smoke test for the standalone QSE Pages dashboard. No real secrets used."""
import hashlib
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class DashboardTest(unittest.TestCase):
    def test_creates_verifier_without_disclosing_credentials(self):
        with tempfile.TemporaryDirectory() as directory:
            env = {**os.environ, "QSE_DASH_USER": "demo_qa_4391", "QSE_DASH_PASSWORD": "481257"}
            script = ROOT / "tools/bots/generate_auth.py"
            result = subprocess.run([sys.executable, str(script), directory], capture_output=True, text=True, env=env)
            self.assertEqual(result.returncode, 0, result.stderr)
            content = (pathlib.Path(directory) / "auth.json").read_text()
            self.assertNotIn("demo_qa_4391", content)
            self.assertNotIn("481257", content)
            params = json.loads(content)
            self.assertGreaterEqual(params["iterations"], 100000)
            expected = hashlib.pbkdf2_hmac(
                "sha256",
                b"demo_qa_4391\x00481257",
                bytes.fromhex(params["salt"]),
                params["iterations"],
            )
            self.assertEqual(expected.hex(), params["digest"])

    def test_denies_missing_secrets(self):
        with tempfile.TemporaryDirectory() as directory:
            env = {**os.environ, "QSE_DASH_USER": "", "QSE_DASH_PASSWORD": ""}
            p = subprocess.run([sys.executable, str(ROOT / "tools/bots/generate_auth.py"), directory],capture_output=True, text=True, env=env)
            self.assertNotEqual(p.returncode, 0)
            self.assertFalse((pathlib.Path(directory) / "auth.json").exists())

    def test_bots_not_replaced_by_game_service_worker(self):
        worker = (ROOT / "web/pwa/sw.js").read_text()
        self.assertIn('startsWith("bots/")', worker)
        for asset in ("index.html", "app.js", "style.css", "building.js", "building.css"):
            self.assertTrue((ROOT / "web/bots" / asset).exists())

    def test_architectural_tower_is_connected_to_real_activity(self):
        html = (ROOT / "web/bots/index.html").read_text()
        app = (ROOT / "web/bots/app.js").read_text()
        building = (ROOT / "web/bots/building.js").read_text()
        workflow = (ROOT / ".github/workflows/deploy-web.yml").read_text()
        for selector in ('id="building-floors"', 'id="building-report"', 'building.js', 'building.css'):
            self.assertIn(selector, html)
        self.assertIn('window.QSEBuilding.render', app)
        self.assertIn('qse-select-agent', app)
        self.assertIn('state=all&sort=updated', app)
        self.assertIn('PR integrada', app)
        self.assertIn('status==="in_progress"', building)
        self.assertIn("GitHub", building)
        for asset in ("building.css", "building.js"):
            self.assertIn(asset, workflow)

    def test_editor_route_with_admin_auth_and_deploy(self):
        editor = ROOT / "web/bots/editor"
        html = (editor / "index.html").read_text()
        js = (editor / "editor.js").read_text()
        workflow = (ROOT / ".github/workflows/deploy-web.yml").read_text()
        for name in ("index.html", "editor.js", "editor.css"):
            self.assertTrue((editor / name).exists())
            self.assertIn(name, workflow)
        for term in ("qse_editor_admins", "qse_editor_content", "signInWithIdToken", "signInWithPassword", "qse-editor-media", "upsert"):
            self.assertIn(term, js)
        self.assertIn("editor.js", html)
        self.assertNotIn("service_role", js)
        self.assertNotIn("sb_secret_", js)

    def test_has_live_github_endpoints_and_no_embedded_credentials(self):
        js = (ROOT / "web/bots/app.js").read_text()
        for endpoint in ("/pulls?", "/actions/runs?", "/commits?", "/issues?"):
            self.assertIn(endpoint, js)
        self.assertIn("crypto.subtle.deriveBits", js)
        self.assertNotIn("Authorization: Bearer", js)


if __name__ == "__main__":
    unittest.main()
