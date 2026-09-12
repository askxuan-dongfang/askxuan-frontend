#!/usr/bin/env python3
"""Build lossless, Unicode-ranged web subsets of the shared 600-weight font.

Requires fonttools[woff] (tested with fontTools 4.64.0 / brotli 1.2.0).
Run from any directory; --check verifies committed outputs without rebuilding.
The original WOFF2 and native TTF remain untouched. No network is used.
"""
from __future__ import annotations

import argparse
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
import hashlib
import json
from pathlib import Path
import shutil
import tempfile

try:
    import brotli
    import fontTools
    from fontTools import subset
    from fontTools.ttLib import TTFont
    from fontTools.unicodedata import script
except ImportError as error:
    raise SystemExit("Install fonttools[woff] in a separate Python tool environment.") from error

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "packages/design-tokens/fonts/AskXuanSerif-Semibold.woff2"
OUTPUT = ROOT / "packages/design-tokens/fonts/web"
H5_OUTPUT = ROOT / "apps/web-h5/src/theme/fonts/web"
SOURCE_DIRS = ["apps/web-h5/src", "apps/web-platform-admin/src",
               "apps/web-shop-admin/src", "apps/web-temple-admin/src", "packages/admin-ui"]
SOURCE_SUFFIXES = {".ts", ".tsx", ".js", ".jsx", ".vue", ".html", ".css", ".json"}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def unicode_map(font):
    result = {}
    for table in font["cmap"].tables:
        if table.isUnicode() and table.format != 14:
            for point, glyph in table.cmap.items():
                if point in result and result[point] != glyph:
                    raise ValueError(f"Conflicting Unicode cmap at U+{point:04X}")
                result[point] = glyph
    return result


def variation_map(font):
    return {(base, selector): glyph for table in font["cmap"].tables
            if table.format == 14 for selector, pairs in table.uvsDict.items()
            for base, glyph in pairs}


def ranges(points):
    groups = []
    for point in sorted(points):
        if groups and point == groups[-1][1] + 1:
            groups[-1][1] = point
        else:
            groups.append([point, point])
    return ",".join(f"U+{a:X}" + (f"-{b:X}" if a != b else "") for a, b in groups)


def expand_ranges(value):
    result = set()
    for item in value.split(","):
        ends = item.removeprefix("U+").split("-")
        result.update(range(int(ends[0], 16), int(ends[-1], 16) + 1))
    return result


def source_counts():
    counts = Counter()
    for name in SOURCE_DIRS:
        for path in sorted((ROOT / name).rglob("*")):
            if path.is_file() and path.suffix in SOURCE_SUFFIXES and "fonts" not in path.parts:
                counts.update(ord(char) for char in path.read_text(encoding="utf-8"))
    return counts


def font_metrics(font):
    fields = {
        "head": ["unitsPerEm", "xMin", "yMin", "xMax", "yMax"],
        "hhea": ["ascent", "descent", "lineGap", "caretSlopeRise", "caretSlopeRun", "caretOffset"],
        "vhea": ["ascent", "descent", "lineGap", "caretSlopeRise", "caretSlopeRun", "caretOffset"],
        "OS/2": ["sTypoAscender", "sTypoDescender", "sTypoLineGap", "usWinAscent",
                 "usWinDescent", "sxHeight", "sCapHeight", "xAvgCharWidth", "usWeightClass"],
    }
    return {table: {name: getattr(font[table], name) for name in names if hasattr(font[table], name)}
            for table, names in fields.items() if table in font}


def glyph_digest(font, name):
    glyph = font["glyf"][name]
    coordinates, endpoints, flags = glyph.getCoordinates(font["glyf"])
    # Decomposed outlines also verify composite geometry without depending on GIDs.
    values = (list(coordinates), list(endpoints), list(flags),
              font["hmtx"][name], font["vmtx"][name] if "vmtx" in font else None,
              [getattr(glyph, field, None) for field in ["xMin", "yMin", "xMax", "yMax"]],
              list(glyph.program.getBytecode()) if hasattr(glyph, "program") else [])
    return sha(repr(values).encode())


def build_piece(job):
    source, destination, points, selectors, extra_glyphs = job
    font = TTFont(source, recalcBBoxes=False, recalcTimestamp=False)
    options = subset.Options()
    options.layout_features = ["*"]
    options.layout_scripts = ["*"]
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.name_legacy = True
    options.glyph_names = True
    options.notdef_outline = True
    options.recommended_glyphs = True
    # All non-Han characters share the core, including paired punctuation.
    # Do not add standard cmap points outside this face's exact Unicode range.
    options.bidi_closure = False
    options.hinting = True
    options.legacy_cmap = True
    # The source's post 3.0 has no names. Keep stable names in generated files
    # so verification also covers every unencoded/layout glyph after reopening.
    font["post"].formatType = 2.0
    font["post"].extraNames = []
    font["post"].mapping = {}
    worker = subset.Subsetter(options=options)
    worker.populate(unicodes=set(points) | set(selectors), glyphs=extra_glyphs)
    worker.subset(font)
    font.flavor = "woff2"
    font.save(destination)
    return Path(destination).name


def faces_css(faces):
    lines = ["/* Generated by scripts/build-web-fonts.py. All original characters are retained. */"]
    for face in faces:
        lines.extend(["@font-face {", '  font-family: "AskXuan Serif";',
                      f'  src: url("./{face["file"]}") format("woff2");',
                      "  font-weight: 600;", "  font-style: normal;", "  font-display: swap;",
                      f'  unicode-range: {face["unicodeRange"]};', "}"])
    return "\n".join(lines) + "\n"


def verify(directory, source_font):
    manifest = json.loads((directory / "manifest.json").read_text())
    assert manifest["sourceSha256"] == sha(SOURCE.read_bytes()), "Source font changed"
    expected_map = unicode_map(source_font)
    expected_uvs = variation_map(source_font)
    expected_glyphs = set(source_font.getGlyphOrder())
    expected_metrics = font_metrics(source_font)
    glyph_cache = {}
    seen_points, seen_uvs, seen_glyphs = set(), {}, set()
    comparisons = 0
    for face in manifest["faces"]:
        path = directory / face["file"]
        assert path.stat().st_size == face["bytes"], f"Size changed: {path.name}"
        assert sha(path.read_bytes()) == face["sha256"], f"Hash changed: {path.name}"
        font = TTFont(path, recalcBBoxes=False, recalcTimestamp=False)
        actual = unicode_map(font)
        points = expand_ranges(face["codepointRange"])
        assert set(actual) == points, f"Unexpected cmap in {path.name}"
        assert not (seen_points & points), f"Overlapping standard cmap: {path.name}"
        assert all(expected_map[point] == glyph for point, glyph in actual.items()), f"Remapped glyph: {path.name}"
        seen_points.update(points)
        actual_uvs = variation_map(font)
        assert actual_uvs == {pair: glyph for pair, glyph in expected_uvs.items() if pair[0] in points}, f"UVS changed: {path.name}"
        assert not (seen_uvs.keys() & actual_uvs.keys()), f"Overlapping UVS: {path.name}"
        seen_uvs.update(actual_uvs)
        assert expand_ranges(face["unicodeRange"]) == points | {pair[1] for pair in actual_uvs}, f"CSS coverage mismatch: {path.name}"
        assert font_metrics(font) == expected_metrics, f"Font metrics changed: {path.name}"
        for glyph in font.getGlyphOrder():
            assert glyph in expected_glyphs, f"Unexpected glyph: {glyph}"
            if glyph not in glyph_cache:
                glyph_cache[glyph] = glyph_digest(source_font, glyph)
            assert glyph_digest(font, glyph) == glyph_cache[glyph], f"Outline, hinting or metrics changed: {path.name}/{glyph}"
            comparisons += 1
            seen_glyphs.add(glyph)
        font.close()
    assert seen_points == set(expected_map), "Original Unicode characters missing"
    assert seen_uvs == expected_uvs, "Original Unicode variation mappings missing"
    assert seen_glyphs == expected_glyphs, "Original encoded or unencoded glyphs missing"
    assert (directory / "faces.css").read_text() == faces_css(manifest["faces"]), "Font-face declarations drifted"
    assert (directory / "OFL.txt").read_bytes() == (SOURCE.parent / "OFL.txt").read_bytes(), "Font license changed"
    result = {"standardCodepoints": len(seen_points), "variationSequences": len(seen_uvs),
              "originalGlyphs": len(expected_glyphs), "coveredGlyphs": len(seen_glyphs),
              "glyphComparisons": comparisons, "globalMetricsMatch": True,
              "outlinesHintingAndMetricsMatch": True, "disjointStandardCodepoints": True}
    if "verification" in manifest:
        assert manifest["verification"] == result, "Verification manifest drifted"
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--chunk-size", type=int, default=512)
    args = parser.parse_args()
    if args.workers < 1 or args.chunk_size < 1:
        parser.error("workers and chunk-size must be positive")
    source_font = TTFont(SOURCE, recalcBBoxes=False, recalcTimestamp=False)
    if args.check:
        print(json.dumps(verify(OUTPUT, source_font), indent=2))
        if H5_OUTPUT.parent.exists():
            expected_files = {p.name for p in OUTPUT.iterdir() if p.is_file()}
            assert expected_files == {p.name for p in H5_OUTPUT.iterdir() if p.is_file()}, "H5 font file list drifted"
            for name in expected_files:
                assert (OUTPUT / name).read_bytes() == (H5_OUTPUT / name).read_bytes(), f"H5 copy drifted: {name}"
        print("Web font assets and H5 copy verified.")
        return

    cmap, uvs = unicode_map(source_font), variation_map(source_font)
    points = set(cmap)
    counts = source_counts()
    # Keep entire non-Han scripts together to preserve Latin/Greek/Cyrillic,
    # kana, Hangul, bopomofo and combining sequences within one physical font.
    core = {point for point in points if script(point) != "Hani" or counts[point] > 0}
    remaining = sorted(points - core)
    chunks = [sorted(core)] + [remaining[index:index + args.chunk_size]
                              for index in range(0, len(remaining), args.chunk_size)]
    unencoded = sorted(set(source_font.getGlyphOrder()) - set(cmap.values()))
    faces = []
    with tempfile.TemporaryDirectory(prefix="askxuan-web-fonts-") as temporary:
        temporary = Path(temporary)
        staged = temporary / "web"
        staged.mkdir()
        # Decompress once; workers read the same temporary TTF, never native TTF.
        original_flavor = source_font.flavor
        source_font.flavor = None
        source_font.save(temporary / "source.ttf")
        source_font.flavor = original_flavor
        jobs = []
        for index, chunk in enumerate(chunks):
            filename = "AskXuanSerif-Semibold-core.woff2" if index == 0 else f"AskXuanSerif-Semibold-han-{index:02d}.woff2"
            selectors = {selector for base, selector in uvs if base in chunk}
            # Also retain every unencoded source glyph, including uncommon
            # layout alternates. These only increase the final rare-Han face.
            extra = unencoded if index == len(chunks) - 1 else []
            jobs.append((str(temporary / "source.ttf"), str(staged / filename), chunk, selectors, extra))
            faces.append({"file": filename, "codepoints": len(chunk), "codepointRange": ranges(chunk),
                          "unicodeRange": ranges(set(chunk) | selectors)})
        with ProcessPoolExecutor(max_workers=args.workers) as pool:
            for completed in pool.map(build_piece, jobs):
                print(f"Generated {completed}", flush=True)
        for face in faces:
            data = (staged / face["file"]).read_bytes()
            face.update({"bytes": len(data), "sha256": sha(data)})
        (staged / "faces.css").write_text(faces_css(faces))
        shutil.copyfile(SOURCE.parent / "OFL.txt", staged / "OFL.txt")
        manifest = {"schemaVersion": 1, "source": SOURCE.relative_to(ROOT).as_posix(),
                    "sourceSha256": sha(SOURCE.read_bytes()), "sourceBytes": SOURCE.stat().st_size,
                    "fontToolsVersion": fontTools.__version__, "brotliVersion": brotli.__version__,
                    "chunkSize": args.chunk_size,
                    "coreStrategy": "All supported non-Han characters plus every Han character in web application sources",
                    "coreBytes": faces[0]["bytes"], "totalFontBytes": sum(face["bytes"] for face in faces),
                    "faces": faces}
        (staged / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
        manifest["verification"] = verify(staged, source_font)
        (staged / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
        (staged / "README.md").write_text(
            "# Web font subsets\n\nGenerated by `scripts/build-web-fonts.py`; do not edit the binaries or faces.css.\n\n"
            "Import `faces.css` from the application typography entry. Remove the old unrestricted @font-face from the loaded CSS; keep the original WOFF2 as the generator source. Do not preload every face.\n\n"
            "All source Unicode codepoints, Unicode variation sequences and encoded/unencoded glyphs are retained across these faces. Standard Unicode ranges are disjoint; variation selectors are declared alongside their base characters. All non-Han scripts share the core to preserve shaping. Glyph outlines, hinting, horizontal/vertical dimensions and global font metrics are checked after WOFF2 serialization. Layout features and scripts retain the fontTools glyph closure.\n\n"
            "The core contains current web application characters. Other Han characters, including dynamic server content, load the appropriate fallback face. Original native TTF and full WOFF2 are not modified.\n\n"
            "Regenerate: `python3 scripts/build-web-fonts.py`; verify: `python3 scripts/build-web-fonts.py --check`. Requires `fonttools[woff]` in a Python tool environment; exact versions and output hashes are recorded in manifest.json. Browser loading and visual behavior still need application acceptance.\n")
        for target in [OUTPUT] + ([H5_OUTPUT] if H5_OUTPUT.parent.exists() else []):
            target.mkdir(parents=True, exist_ok=True)
            for old in target.glob("AskXuanSerif-Semibold-*.woff2"):
                old.unlink()
            for path in staged.iterdir():
                shutil.copyfile(path, target / path.name)
        print(json.dumps({"coreBytes": manifest["coreBytes"], "totalFontBytes": manifest["totalFontBytes"],
                          "faces": len(faces), "verification": manifest["verification"]}, indent=2))


if __name__ == "__main__":
    main()
