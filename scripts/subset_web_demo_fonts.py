#!/usr/bin/env python3
"""Keep only characters used by the English-only fictional demo bundle.

The mobile font assets are left untouched. Flutter Web eagerly fetches every
registered font at startup, including three 16+ MB CJK fonts; without subsetting
it can remain blank on a slow connection for minutes.
"""
from pathlib import Path
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

FONTS = (
    "BabyNotoSans-VF.ttf",
    "NotoSansCJKsc-Regular.otf",
    "NotoSansCJKsc-Bold.otf",
)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: subset_web_demo_fonts.py <web-build-dir>")
    root = Path(sys.argv[1])
    directory = root / "assets/assets/fonts"
    # Include every literal in the App sources, plus Latin, common punctuation,
    # symbols and CJK punctuation so scripted copy and English demo inputs work.
    codepoints = set(range(0x20, 0x250))
    codepoints.update(range(0x1E00, 0x1F00))
    codepoints.update(range(0x2000, 0x2150))
    codepoints.update(range(0x2190, 0x2200))
    codepoints.update(range(0x2600, 0x27C0))
    codepoints.update(range(0x3000, 0x3040))
    for source in sorted(Path("lib").rglob("*.dart")):
        codepoints.update(map(ord, source.read_text(encoding="utf-8")))
    codepoints.update(map(ord, Path("web_demo/index.html").read_text(encoding="utf-8")))

    for name in FONTS:
        path = directory / name
        if not path.is_file():
            raise SystemExit(f"Expected bundled font missing: {path}")
        before = path.stat().st_size
        font = TTFont(path)
        options = subset.Options()
        options.layout_features = ["*"]
        options.name_IDs = ["*"]
        subsetter = subset.Subsetter(options=options)
        subsetter.populate(unicodes=codepoints)
        subsetter.subset(font)
        font.save(path)
        font.close()
        after = path.stat().st_size
        if after >= before or after > 1_000_000:
            raise SystemExit(f"Font subset is unexpectedly large: {path} ({after} bytes)")
        print(f"Web-only font: {name} {before} -> {after} bytes")


if __name__ == "__main__":
    main()
