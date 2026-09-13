#!/usr/bin/env python3
import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
if not os.path.isdir(SRC):
    raise SystemExit(f"source root not found: {SRC}")

SOURCE_EXTS = (".m", ".mm", ".h", ".c")

LAYER_RANK = {
    "Model": 0,
    "Wire/Types": 0,
    "Wire": 2,
    "Stores": 1,
    "Layout": 1,
    "Theme": 1,
    "Utilities": 1,
    "Views": 2,
    "Media": 2,
    "Storage": 2,
    "Calls": 2,
    "Services": 2,
    "Companions": 2,
    "App": 5,
}

SCREENS_RANK = 5

BOUNDARY_PACKAGE = "TDLibClient"

IMPORT_RE = re.compile(r'#\s*import\s*"([^"]+)"')

RULES = ("rank", "screen-wall", "tdlib-schema", "error-check")


def package_for(relpath):
    parts = relpath.split(os.sep)
    if parts[0] == "Wire" and len(parts) >= 2 and parts[1] == "Types":
        return "Wire/Types"
    if parts[0] == "Screens":
        if len(parts) >= 2:
            return "Screens/" + parts[1]
        return "Screens"
    return parts[0]


def is_screen(package):
    return package == "Screens" or package.startswith("Screens/")


def rank_for(package):
    if is_screen(package):
        return SCREENS_RANK
    return LAYER_RANK.get(package)


def walk_sources():
    files = []
    for dirpath, dirnames, filenames in os.walk(SRC):
        rel_dir = os.path.relpath(dirpath, SRC)
        for fn in filenames:
            if fn.endswith(SOURCE_EXTS):
                relpath = os.path.normpath(os.path.join(rel_dir, fn)) if rel_dir != "." else fn
                files.append(relpath)
    return files


def build_header_index(files):
    index = {}
    for relpath in files:
        if not relpath.endswith(".h"):
            continue
        base = os.path.basename(relpath)
        index.setdefault(base, []).append(relpath)
    return index


def parse_imports(abspath):
    imports = []
    try:
        with open(abspath, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                m = IMPORT_RE.search(line)
                if m:
                    imports.append(m.group(1))
    except OSError:
        pass
    return imports


def resolve_import_targets(relpath, header_index):
    abspath = os.path.join(SRC, relpath)
    targets = []
    own_dir = os.path.dirname(relpath)
    for imported_header in parse_imports(abspath):
        imported_base = os.path.basename(imported_header)
        cands = header_index.get(imported_base, [])
        same_dir = [c for c in cands if os.path.dirname(c) == own_dir]
        for cand in (same_dir or cands):
            targets.append((imported_header, cand))
    return targets


def load_baseline(path):
    entries = set()
    if not path:
        return entries
    if not os.path.exists(path):
        return entries
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            entries.add(line)
    return entries


def check_rank(files, header_index):
    violations = []
    for relpath in files:
        importer_pkg = package_for(relpath)
        importer_rank = rank_for(importer_pkg)
        if importer_rank is None:
            continue
        for imported_header, cand in resolve_import_targets(relpath, header_index):
            imported_pkg = package_for(cand)
            if imported_pkg == importer_pkg:
                continue
            imported_rank = rank_for(imported_pkg)
            if imported_rank is None:
                continue
            if imported_rank > importer_rank:
                line = "%s -> %s" % (relpath, imported_header)
                violations.append((line, "%s [rank %d] imports %s [rank %d]" %
                                    (importer_pkg, importer_rank, imported_pkg, imported_rank)))
    return violations


def is_private_header(header):
    name = os.path.basename(header)
    return "+" in name or name.endswith("Internal.h")


def check_screen_wall(files, header_index):
    violations = []
    for relpath in files:
        importer_pkg = package_for(relpath)
        if not is_screen(importer_pkg):
            continue
        for imported_header, cand in resolve_import_targets(relpath, header_index):
            imported_pkg = package_for(cand)
            if not is_screen(imported_pkg) or imported_pkg == importer_pkg:
                continue
            if not is_private_header(imported_header):
                continue
            line = "%s -> %s" % (relpath, imported_header)
            violations.append((line, "%s reaches into %s's private header" %
                                (importer_pkg, imported_pkg)))
    return violations


SCHEMA_MARKERS = (
    ('@"@type"', "names TDLib's own type discriminator"),
    ("td_json_client", "reaches tdjson directly"),
    ("td_json", "reaches tdjson directly"),
)

SCHEMA_ALLOWED_PACKAGES = (BOUNDARY_PACKAGE, "Wire")


def check_private_error_checks(files, header_index):
    violations = []
    marker = re.compile(r'static\s+BOOL\s+(TG\w*IsError)\s*\(')
    for relpath in files:
        if not relpath.endswith((".m", ".mm")):
            continue
        try:
            with open(os.path.join(SRC, relpath), encoding="utf-8", errors="replace") as handle:
                text = handle.read()
        except OSError:
            continue
        for match in marker.finditer(text):
            violations.append(("%s -> %s" % (relpath, match.group(1)),
                               "declares its own copy of the TDLib error check instead of "
                               "TGResultIsError"))
    return violations


def check_tdlib_schema(files, header_index):
    violations = []
    for relpath in files:
        package = package_for(relpath)
        if package in SCHEMA_ALLOWED_PACKAGES:
            continue
        try:
            with open(os.path.join(SRC, relpath), encoding="utf-8", errors="replace") as handle:
                text = handle.read()
        except OSError:
            continue
        for marker, why in SCHEMA_MARKERS:
            if marker in text:
                violations.append(("%s -> %s" % (relpath, marker),
                                   "%s %s" % (package, why)))
                break
    return violations


CHECKS = {
    "rank": check_rank,
    "screen-wall": check_screen_wall,
    "tdlib-schema": check_tdlib_schema,
    "error-check": check_private_error_checks,
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--baseline-rank", default=None,
                     help="Baseline file for the rank rule (a lower layer must not import a "
                          "strictly higher-ranked one).")
    ap.add_argument("--baseline-screen-wall", default=None,
                     help="Baseline file for the screen-wall rule (a screen must not import a "
                          "sibling screen's private header).")
    ap.add_argument("--baseline-tdlib-schema", default=None,
                    help="baseline file for the tdlib-schema rule")
    ap.add_argument("--rule", action="append", choices=RULES, default=None,
                     help="Restrict the run to one or more rules (default: all three).")
    ap.add_argument("--structural-package", action="append", default=[], metavar="RULE:PACKAGE",
                     help="Mark PACKAGE as a structural, permanent source of violations under "
                          "RULE, for reporting only. Every violation still prints and still "
                          "gates on [NEW] exactly as without this flag; this only splits the "
                          "summary line's count into a structural share (packages whose entire "
                          "job is to sit at the boundary, e.g. Services and Companions for "
                          "tdlib-boundary) and the rest, so a floor that can never reach zero "
                          "says so in the script's own output instead of a baseline nobody reads. "
                          "Repeatable, e.g. --structural-package tdlib-boundary:Services.")
    args = ap.parse_args()

    baseline_paths = {
        "rank": args.baseline_rank,
        "screen-wall": args.baseline_screen_wall,
        "tdlib-schema": args.baseline_tdlib_schema,
        "error-check": None,
    }

    structural_packages = {}
    for entry in args.structural_package:
        rule, _, package = entry.partition(":")
        structural_packages.setdefault(rule, set()).add(package)

    rules_to_run = args.rule or list(RULES)

    files = walk_sources()
    header_index = build_header_index(files)

    total_new = 0
    for rule in rules_to_run:
        violations = CHECKS[rule](files, header_index)
        baseline = load_baseline(baseline_paths[rule])
        new_count = sum(1 for line, detail in violations if line not in baseline)

        structural_set = structural_packages.get(rule)
        floor_note = ""
        if structural_set:
            structural_count = sum(1 for line, detail in violations
                                    if package_for(line.split(" -> ", 1)[0]) in structural_set)
            floor_note = (", floor: %d structural (%s), %d convertible" %
                          (structural_count, "/".join(sorted(structural_set)),
                           len(violations) - structural_count))

        print("[%s] violations found: %d (new: %d, baselined: %d%s)" %
              (rule, len(violations), new_count, len(violations) - new_count, floor_note))
        for line, detail in violations:
            marker = "" if line in baseline else "  [NEW]"
            print("  %s  (%s)%s" % (line, detail, marker))
        print()

        total_new += new_count

    if total_new:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
