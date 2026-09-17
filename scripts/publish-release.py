#!/usr/bin/env python3
"""Publish the current DMG, then remove legacy PKG assets from GitHub releases."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
from urllib.parse import quote, urlparse

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)
REPOSITORY = "kb4rs6zvwt-eng/get-clean-text"
API = f"https://api.github.com/repos/{REPOSITORY}"


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def credentials():
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if not token:
        result = subprocess.run(
            ["git", "-c", "credential.interactive=false", "credential", "fill"],
            input=f"protocol=https\nhost=github.com\npath={REPOSITORY}.git\n\n",
            text=True, capture_output=True,
            env={**os.environ, "GIT_TERMINAL_PROMPT": "0"},
        )
        fields = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
        token = fields.get("password") if result.returncode == 0 else None
    if not token or any(character in token for character in '\r\n"\\'):
        raise RuntimeError("Authentification GitHub absente. Configurer Git ou GH_TOKEN.")
    return token


class GitHub:
    def __init__(self):
        self.token = credentials()

    def request(self, method, url, payload=None, asset=None, allow_missing=False):
        parsed = urlparse(url)
        if parsed.scheme != "https" or parsed.netloc not in {"api.github.com", "uploads.github.com"}:
            raise RuntimeError("Destination GitHub inattendue.")
        if not parsed.path.startswith(f"/repos/{REPOSITORY}/"):
            raise RuntimeError("Requête hors du dépôt autorisé.")
        # Keep the token off the process command line and out of logs/files.
        config = f'header = "Authorization: Bearer {self.token}"\n'
        config += 'header = "Accept: application/vnd.github+json"\n'
        config += 'header = "X-GitHub-Api-Version: 2022-11-28"\n'
        with tempfile.TemporaryDirectory(prefix="get-clean-text-release-") as temporary:
            response = Path(temporary) / "response.json"
            command = ["/usr/bin/curl", "--silent", "--show-error", "--connect-timeout", "20",
                       "--max-time", "300", "--config", "-", "--request", method,
                       "--output", str(response), "--write-out", "%{http_code}", url]
            if asset:
                command += ["--header", "Content-Type: application/octet-stream", "--data-binary", f"@{asset}"]
            elif payload is not None:
                body = Path(temporary) / "body.json"
                body.write_text(json.dumps(payload))
                command += ["--header", "Content-Type: application/json", "--data-binary", f"@{body}"]
            result = subprocess.run(command, input=config, text=True, capture_output=True)
            if result.returncode:
                raise RuntimeError("Échec réseau GitHub ; relancer la commande pour reprendre.")
            status = int(result.stdout)
            data = json.loads(response.read_text()) if response.stat().st_size else None
            if allow_missing and status == 404:
                return None
            if not 200 <= status < 300:
                message = data.get("message", "requête refusée") if isinstance(data, dict) else "requête refusée"
                raise RuntimeError(f"GitHub HTTP {status}: {message}")
            return data

    def releases(self):
        releases = []
        page = 1
        while True:
            batch = self.request("GET", f"{API}/releases?per_page=100&page={page}")
            releases.extend(batch)
            if len(batch) < 100:
                return releases
            page += 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--notes-file", type=Path, help="Notes Markdown facultatives pour cette version")
    parser.add_argument("--keep-legacy-assets", action="store_true", help="Conserver les anciennes pièces jointes des releases")
    args = parser.parse_args()
    remote = git("remote", "get-url", "origin")
    if remote.removesuffix(".git") not in {f"https://github.com/{REPOSITORY}", f"git@github.com:{REPOSITORY}"}:
        raise RuntimeError("Le remote origin ne correspond pas au dépôt de publication.")
    if git("status", "--porcelain"):
        raise RuntimeError("Commiter les modifications avant de publier une release.")
    with (ROOT / "Resources/Info.plist").open("rb") as source:
        version = plistlib.load(source)["CFBundleShortVersionString"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise RuntimeError("Version attendue : majeure.mineure.correctif.")
    tag = f"v{version}"
    asset = ROOT / "dist" / f"Get-Clean-Text-{version}-Apple-Silicon.dmg"
    if not asset.is_file():
        raise RuntimeError("DMG absent : exécuter ./scripts/build.sh avant de publier.")
    digest = "sha256:" + hashlib.sha256(asset.read_bytes()).hexdigest()
    sha = git("rev-parse", "HEAD")
    github = GitHub()
    github.request("GET", f"{API}/commits/{sha}")  # Require the release source to be pushed first.
    tagged_ref = github.request("GET", f"{API}/git/ref/tags/{tag}", allow_missing=True)
    tagged_commit = github.request("GET", f"{API}/commits/{tag}") if tagged_ref else None
    if tagged_commit and tagged_commit["sha"] != sha:
        raise RuntimeError(f"{tag} pointe déjà vers un autre commit. Augmenter la version avant publication.")
    notes = args.notes_file.read_text() if args.notes_file else (
        f"## Installation\n\nTélécharger **{asset.name}**, ouvrir le DMG et glisser "
        "**Get Clean Text** dans **Applications**, puis éjecter le disque.\n\n"
        "Quitter l’app avant de remplacer une version précédente. Pour migrer depuis Texte brut, "
        "retirer les anciennes copies de ce nom après installation ; les préférences sont conservées.\n\n"
        "## Utilisation\n\nCopier le texte, utiliser **⇧⌘K**, puis coller avec **⌘V**. "
        "Le raccourci est personnalisable depuis **Aa → Réglages**.\n\n"
        "**Compatibilité :** Apple Silicon, macOS 13 ou ultérieur.\n\n"
        "**Signature :** application signée localement ad hoc, sans notarisation Apple.\n"
    )
    releases = github.releases()
    release = next((item for item in releases if item["tag_name"] == tag), None)
    if release is None:
        release = github.request("POST", f"{API}/releases", {
            "tag_name": tag, "target_commitish": sha, "name": f"Get Clean Text {version}",
            "body": notes, "draft": True, "prerelease": False,
        })
    existing = next((item for item in release["assets"] if item["name"] == asset.name), None)
    if existing and existing.get("digest") != digest:
        raise RuntimeError("Un DMG différent existe pour cette version. Augmenter la version pour le remplacer.")
    if existing is None:
        upload = release["upload_url"].split("{")[0] + "?name=" + quote(asset.name)
        existing = github.request("POST", upload, asset=asset)
    if existing["state"] != "uploaded" or existing["size"] != asset.stat().st_size or existing.get("digest") != digest:
        raise RuntimeError("Le DMG publié ne correspond pas au fichier local ; aucun PKG supprimé.")
    release = github.request("PATCH", f"{API}/releases/{release['id']}", {
        "name": f"Get Clean Text {version}", "body": notes, "draft": False,
        "prerelease": False, "make_latest": "true",
    })
    published_asset = next(item for item in release["assets"] if item["name"] == asset.name)
    print(f"DMG publié et SHA-256 vérifié : {published_asset['browser_download_url']}")

    if args.keep_legacy_assets:
        final = github.request("GET", f"{API}/releases/latest")
        if final["id"] != release["id"]:
            raise RuntimeError("La vérification de la dernière release a échoué.")
        print(f"Dernière release : {final['html_url']}")
        return

    # Only remove the obsolete format once the replacement is public and verified.
    backup = ROOT / ".build/release-backups"
    backup.mkdir(parents=True, exist_ok=True)
    for old in github.releases():
        packages = [item for item in old["assets"] if item["name"].lower().endswith(".pkg")]
        if not packages:
            continue
        (backup / f"release-{old['id']}.json").write_text(json.dumps(old, ensure_ascii=False, indent=2))
        for package in packages:
            # Keep a local copy for recovery, including assets from old releases.
            saved = backup / f"{package['id']}-{Path(package['name']).name}"
            if not saved.exists():
                subprocess.run(["/usr/bin/curl", "--fail", "--location", "--silent", "--show-error",
                                "--output", str(saved), package["browser_download_url"]], check=True)
            if saved.stat().st_size != package["size"]:
                raise RuntimeError("Sauvegarde du PKG incomplète ; suppression annulée.")
            github.request("DELETE", f"{API}/releases/assets/{package['id']}")
            print(f"Ancien PKG retiré : {package['name']}")
        if old["id"] != release["id"]:
            github.request("PATCH", f"{API}/releases/{old['id']}", {"body": (
                "Cette ancienne version a été remplacée. Le format PKG n’est plus distribué.\n\n"
                f"Télécharger le dernier **Get Clean Text au format DMG** depuis "
                f"[la dernière release](https://github.com/{REPOSITORY}/releases/latest).\n\n"
                "Ouvrir le DMG, puis glisser l’app dans **Applications**.\n"
            )})
    final = github.request("GET", f"{API}/releases/latest")
    if final["id"] != release["id"] or any(a["name"].lower().endswith(".pkg") for r in github.releases() for a in r["assets"]):
        raise RuntimeError("La vérification finale des releases a échoué.")
    print(f"Dernière release : {final['html_url']}")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from None
