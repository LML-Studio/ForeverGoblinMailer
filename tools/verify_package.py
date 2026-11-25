"""Build or verify the reproducible, source-only Forever Goblin Mailer ZIP."""
import argparse
from hashlib import sha256
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
NAME = "ForeverGoblinMailer"
ADDON = ROOT / NAME
DIST = ROOT / "dist"
FILES = [NAME + ".toc", "Roster.lua", "Recipes.lua", "Routing.lua", "Mailbox.lua", "Dispatch.lua", "Panel.lua"]
ZIP = DIST / (NAME + ".zip")
SUMS = DIST / "SHA256SUMS.txt"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def build():
    DIST.mkdir(exist_ok=True)
    with ZipFile(ZIP, "w") as archive:
        for filename in FILES:
            entry = ZipInfo(f"{NAME}/{filename}", (2026, 1, 1, 0, 0, 0))
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, (ADDON / filename).read_bytes(), compress_type=ZIP_DEFLATED, compresslevel=9)
    SUMS.write_bytes(f"{sha256(ZIP.read_bytes()).hexdigest()}  {ZIP.name}\n".encode("ascii"))


def verify():
    digest = sha256(ZIP.read_bytes()).hexdigest()
    require(SUMS.read_text("ascii").split() == [digest, ZIP.name], "Release checksum mismatch")
    require({p.name for p in ADDON.iterdir()} == set(FILES), "Unexpected runtime files")
    with ZipFile(ZIP) as archive:
        require(archive.namelist() == [f"{NAME}/{f}" for f in FILES], "Unexpected ZIP paths or order")
        require(archive.testzip() is None, "ZIP CRC failed")
        for filename in FILES:
            require(archive.read(f"{NAME}/{filename}") == (ADDON / filename).read_bytes(), filename)
    toc = (ADDON / FILES[0]).read_text("utf-8").splitlines()
    require("## Interface: 16001" in toc and "## AllowLoadGameType: camelot" in toc, "Wrong client")
    require("## SavedVariables: ForeverGoblinMailerDB" in toc, "Wrong settings owner")
    require([s for s in toc if s and not s.startswith("#")] == FILES[1:], "Wrong load order")
    print(f"Verified {len(FILES)} runtime files, {ZIP.stat().st_size} bytes. SHA-256 {digest}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", action="store_true", help="rebuild the archive before verifying")
    if parser.parse_args().build:
        build()
    verify()
