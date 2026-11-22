"""Verify the public release ZIP and compare every installable byte with source."""
from hashlib import sha256
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
ADDON = ROOT / "ForeverMailFix"
FILES = ("ForeverMailFix.toc", "ForeverMailFix.lua", "Options.lua")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify():
    archive = DIST / "ForeverMailFix.zip"
    expected_hash, filename = (DIST / "SHA256SUMS.txt").read_text("ascii").split()
    digest = sha256(archive.read_bytes()).hexdigest()
    require(filename == archive.name and digest == expected_hash, "Release checksum mismatch")
    require({p.name for p in ADDON.iterdir()} == set(FILES), "Unexpected runtime source inventory")
    with ZipFile(archive) as contents:
        names = ["ForeverMailFix/" + file for file in FILES]
        require(sorted(contents.namelist()) == sorted(names), "Unexpected ZIP paths or duplicates")
        require(contents.testzip() is None, "Archive CRC failed")
        for filename, member in zip(FILES, names):
            require(contents.read(member) == (ADDON / filename).read_bytes(), f"Mismatch for {member}")

    toc = (ADDON / FILES[0]).read_text("utf-8").splitlines()
    require("## Interface: 16001" in toc and "## AllowLoadGameType: camelot" in toc, "Wrong client manifest")
    require("## SavedVariables: ForeverMailFixDB" in toc, "Wrong settings owner")
    require([line for line in toc if line and not line.startswith("#")] == list(FILES[1:]), "Wrong load order")
    print(f"Verified {len(FILES)} files and {archive.stat().st_size} ZIP bytes. SHA-256 {digest}")


if __name__ == "__main__":
    verify()
