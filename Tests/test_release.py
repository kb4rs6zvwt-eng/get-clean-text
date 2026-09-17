import hashlib
import importlib.util
import plistlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("publish_release", Path(__file__).resolve().parents[1] / "scripts/publish-release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "Resources").mkdir()
        (self.root / "Resources/Info.plist").write_bytes(plistlib.dumps({"CFBundleShortVersionString": "1.0.2"}))
        (self.root / "dist").mkdir()
        self.asset = self.root / "dist/Get-Clean-Text-1.0.2-Apple-Silicon.dmg"
        self.asset.write_bytes(b"verified-dmg")
        self.calls = []
        self.digest = "sha256:" + hashlib.sha256(self.asset.read_bytes()).hexdigest()
        self.remote_digest = self.digest
        self.tag_sha = None
        self.old = {"id": 1, "tag_name": "v1.0.0", "assets": [{"id": 3, "name": "old.pkg", "size": 3, "browser_download_url": "https://github.com/old.pkg"}]}
        self.new = {"id": 2, "tag_name": "v1.0.2", "assets": [], "upload_url": f"https://uploads.github.com/repos/{release.REPOSITORY}/releases/2/assets{{?name}}", "html_url": "https://github.com/release"}
        backup = self.root / ".build/release-backups"
        backup.mkdir(parents=True)
        (backup / "3-old.pkg").write_bytes(b"pkg")
        self.published = False

    def request(self, method, url, payload=None, asset=None, allow_missing=False):
        self.calls.append((method, url))
        if "/commits/v1.0.2" in url:
            return {"sha": self.tag_sha} if self.tag_sha else None
        if "/commits/" in url:
            return {"sha": "head"}
        if method == "POST" and "uploads.github.com" in url:
            result = {"name": self.asset.name, "state": "uploaded", "size": self.asset.stat().st_size,
                      "digest": self.remote_digest, "browser_download_url": "https://github.com/app.dmg"}
            self.new["assets"] = [result]
            return result
        if method == "POST":
            return self.new
        if method == "DELETE":
            self.assertTrue(self.published, "The replacement must be public before removing the PKG")
            self.old["assets"] = []
            return None
        if method == "PATCH" and url.endswith("/2"):
            self.published = True
            return self.new
        if method == "PATCH":
            return self.old
        if url.endswith("/latest"):
            return self.new
        raise AssertionError((method, url))

    def run_publish(self):
        def git(*args):
            if args[0] == "remote":
                return f"https://github.com/{release.REPOSITORY}"
            return "" if args[0] == "status" else "head"
        with patch.object(release, "ROOT", self.root), patch.object(release, "git", git), \
             patch.object(release, "GitHub", return_value=self), patch("sys.argv", ["publish-release.py"]):
            release.main()

    def releases(self):
        return [self.old, self.new] if self.published else [self.old]

    def test_upload_verified_and_published_before_removing_pkg(self):
        self.run_publish()
        self.assertFalse(self.old["assets"])
        self.assertTrue((self.root / ".build/release-backups/release-1.json").exists())

    def test_wrong_uploaded_digest_preserves_pkg(self):
        self.remote_digest = "sha256:incorrect"
        with self.assertRaisesRegex(RuntimeError, "ne correspond pas"):
            self.run_publish()
        self.assertFalse(self.published)
        self.assertFalse(any(method == "DELETE" for method, _ in self.calls))

    def test_existing_tag_at_other_commit_is_never_moved(self):
        self.tag_sha = "other"
        with self.assertRaisesRegex(RuntimeError, "autre commit"):
            self.run_publish()
        self.assertTrue(all(method == "GET" for method, _ in self.calls))


if __name__ == "__main__":
    unittest.main()
