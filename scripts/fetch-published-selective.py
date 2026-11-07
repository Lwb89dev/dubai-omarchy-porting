#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Fetch only dubai's signed Omarchy Mobile packages, with parallel downloads."""

import concurrent.futures
import gzip
import os
import pathlib
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = pathlib.Path(sys.argv[1]).resolve()
BASE = os.environ.get("OMAMOBILE_PKGS_URL", "https://pkgs.omamobile.org") + "/development/aarch64"
KEYRING = ROOT / "sources/omarchy-mobile/packages/omamobile-keyring"
LOCAL = {"omamobile-device-dubai", "omamobile-ucm-dubai"}
EXCLUDE = {
    "mesa", "vulkan-panfrost", "vulkan-mesa-implicit-layers", "hyprland", "hyprpm",
    "libcamera", "libcamera-ipa", "gst-plugin-libcamera", "python-libcamera", "libfprint",
    "linux-omamobile", "omamobile-boot-update", "omamobile-audio", "omamobile-sensors",
    "omamobile-gnss", "omamobile-fingerprint", "omamobile-modem", "omamobile-modem-sit",
    "omamobile-mmd", "omamobile-speaker-tuning", "omamobile-waydroid",
}


def download(url, dest):
    temporary = dest.with_name(dest.name + ".part")
    for attempt in range(3):
        offset = temporary.stat().st_size if temporary.exists() else 0
        request = urllib.request.Request(url, headers={"Range": f"bytes={offset}-"} if offset else {})
        try:
            with urllib.request.urlopen(request, timeout=180) as response:
                append = bool(offset and response.status == 206)
                with temporary.open("ab" if append else "wb") as output:
                    shutil.copyfileobj(response, output)
            temporary.replace(dest)
            return
        except Exception:
            # Keep a partial download for a later HTTP Range resume.
            if attempt == 2:
                raise
            time.sleep(2 ** attempt)


def signature_status(gnupg, keyring, signature, document):
    result = subprocess.run(
        ["gpgv", "--keyring", str(keyring), "--status-fd", "1", str(signature), str(document)],
        check=False, capture_output=True, text=True,
    )
    if result.returncode:
        raise RuntimeError(f"bad signature: {document.name}")
    return [line.split()[-1] for line in result.stdout.splitlines() if " VALIDSIG " in line]


def main():
    if not (KEYRING / "omamobile.gpg").is_file():
        raise SystemExit("Run scripts/fetch-sources.sh first")
    OUT.mkdir(parents=True, exist_ok=True)
    trusted = {
        line.split(":", 1)[0] for line in (KEYRING / "omamobile-trusted").read_text().splitlines()
        if len(line.split(":", 1)[0]) == 40 and all(c in "0123456789ABCDEF" for c in line.split(":", 1)[0])
    }
    revoked = set()
    revoked_file = KEYRING / "omamobile-revoked"
    if revoked_file.exists():
        revoked = {token for line in revoked_file.read_text().splitlines() for token in line.split()
                   if len(token) == 40 and all(c in "0123456789ABCDEF" for c in token)}
    with tempfile.TemporaryDirectory() as temporary:
        tmp = pathlib.Path(temporary)
        gnupg = tmp / "gnupg"
        gnupg.mkdir(mode=0o700)
        env = dict(os.environ, GNUPGHOME=str(gnupg))
        keyring = ROOT / "work/fetch-published-keyring.kbx"
        keyring.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["gpg", "--batch", "--quiet", "--no-default-keyring", "--keyring",
                        str(keyring), "--import", str(KEYRING / "omamobile.gpg")],
                       check=True, env=env, capture_output=True)
        download(BASE + "/omamobile.db", tmp / "omamobile.db")
        download(BASE + "/omamobile.db.sig", tmp / "omamobile.db.sig")
        signers = signature_status(gnupg, keyring, tmp / "omamobile.db.sig", tmp / "omamobile.db")
        if not signers or not set(signers).issubset(trusted - revoked):
            raise SystemExit("The package index is not signed by a trusted, non-revoked key")
        packages = {}
        with tarfile.open(tmp / "omamobile.db") as archive:
            for member in archive.getmembers():
                if not member.name.endswith("/desc"):
                    continue
                lines = archive.extractfile(member).read().decode().splitlines()
                fields = {}
                for key in ("%NAME%", "%FILENAME%", "%SHA256SUM%"):
                    fields[key] = lines[lines.index(key) + 1]
                packages[fields["%NAME%"]] = fields

    required = {
        line.split("#", 1)[0].strip() for line in (ROOT / "rootfs/packages.omamobile").read_text().splitlines()
        if line.split("#", 1)[0].strip()
    }
    missing = required - packages.keys() - LOCAL
    if missing:
        raise SystemExit("Required packages absent from signed index: " + " ".join(sorted(missing)))
    selected = {
        name: fields for name, fields in packages.items()
        if name not in EXCLUDE and not name.startswith("omamobile-device-")
    }
    keep = {fields["%FILENAME%"] for fields in selected.values()}
    keep.update({name + ".sig" for name in keep})
    for path in OUT.glob("*.pkg.tar.*"):
        if path.name not in keep:
            path.unlink()

    def fetch_package(item):
        name, fields = item
        filename = fields["%FILENAME%"]
        expected = fields["%SHA256SUM%"]
        package = OUT / filename
        signature = OUT / (filename + ".sig")
        if not (package.exists() and signature.exists()):
            download(BASE + "/" + filename, package)
            download(BASE + "/" + filename + ".sig", signature)
        import hashlib
        if hashlib.sha256(package.read_bytes()).hexdigest() != expected:
            raise RuntimeError(f"SHA-256 mismatch: {filename}")
        with tempfile.TemporaryDirectory() as temporary:
            # The already verified public keyring is read-only and safe to share.
            keyring = ROOT / "work/fetch-published-keyring.kbx"
            signers = signature_status(None, keyring, signature, package)
        if not signers or not set(signers).issubset(trusted - revoked):
            raise RuntimeError(f"Untrusted package signature: {filename}")
        return f"verified {filename}"

    keyring = ROOT / "work/fetch-published-keyring.kbx"
    if not keyring.exists():
        raise SystemExit(f"Internal error: missing {keyring}")
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
        for result in executor.map(fetch_package, sorted(selected.items())):
            print(result)
    print(f"{len(selected)} selected packages verified in {OUT}")


if __name__ == "__main__":
    main()
