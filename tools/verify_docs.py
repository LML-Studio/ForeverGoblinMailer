"""Check player-facing local links and the download against the runtime TOC."""
from html.parser import HTMLParser
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "docs/index.html"
README = ROOT / "README.md"
TOC = ROOT / "ForeverGoblinMailer/ForeverGoblinMailer.toc"


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.targets = []
        self.ids = set()
        self.images = []

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if "id" in values:
            self.ids.add(values["id"])
        if tag == "img":
            self.images.append((values.get("src", ""), values.get("alt")))
        for key in ("href", "src"):
            if values.get(key):
                self.targets.append(values[key])


def check_target(page, value, ids=None):
    url = urlsplit(value)
    if url.scheme or url.netloc:
        return
    if url.path and not (page.parent / unquote(url.path)).exists():
        raise ValueError(f"{page.name}: missing local target {value}")
    if ids is not None and not url.path and url.fragment and unquote(url.fragment) not in ids:
        raise ValueError(f"{page.name}: missing HTML anchor {value}")


def main():
    version_line = next(line for line in TOC.read_text().splitlines() if line.startswith("## Version:"))
    version = version_line.split(":", 1)[1].strip()
    archive = f"https://github.com/LML-Studio/ForeverGoblinMailer/releases/download/v{version}/ForeverGoblinMailer.zip"
    for page in (README, SITE, ROOT / "handbook/Home.md", ROOT / "handbook/Install-and-first-use.md"):
        if archive not in page.read_text(encoding="utf-8"):
            raise ValueError(f"{page.name}: missing direct download for {version}")

    pages = [README, *sorted((ROOT / "handbook").glob("*.md")), ROOT / "docs/assets/Credits.md"]
    for page in pages:
        markup = page.read_text(encoding="utf-8")
        prose = re.sub(r"```[^\n]*\n.*?\n```", "", markup, flags=re.S)
        links = Links()
        links.feed(prose)
        for target in links.targets + re.findall(r"\]\(([^)\s]+)\)", prose):
            check_target(page, target)
        for source, alt in links.images:
            if not alt:
                raise ValueError(f"{page.name}: missing text alternative for {source}")

    site = Links()
    site.feed(SITE.read_text(encoding="utf-8"))
    for target in site.targets:
        check_target(SITE, target, site.ids)
    for source, alt in site.images:
        if alt is None:
            raise ValueError(f"{SITE.name}: missing alt attribute for {source}")
    for target in re.findall(r"https://lml-studio\.github\.io/ForeverGoblinMailer/#([\w-]+)", README.read_text(encoding="utf-8")):
        if target not in site.ids:
            raise ValueError(f"README: missing public tour or calculator anchor #{target}")
    print(f"Verified {len(pages)} Markdown pages, site links and versioned download for {version}.")


if __name__ == "__main__":
    main()
