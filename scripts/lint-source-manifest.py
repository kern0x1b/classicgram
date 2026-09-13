#!/usr/bin/env python3
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_DIR = os.path.join(ROOT, "src")
RESOURCES_DIR = os.path.join(APP_DIR, "Resources")
MANIFEST_PATH = os.path.join(APP_DIR, "sources.manifest")
GENERATED_EXTS = (".m", ".c")


def is_under(path, directory):
    return os.path.commonpath([path, directory]) == directory


def found_on_disk():
    found = []
    for root, _, names in os.walk(APP_DIR):
        if is_under(os.path.abspath(root), RESOURCES_DIR):
            continue
        for name in names:
            if name.endswith(GENERATED_EXTS):
                full = os.path.join(root, name)
                found.append(os.path.relpath(full, ROOT))
    return sorted(found)


def read_manifest():
    if not os.path.isfile(MANIFEST_PATH):
        return None
    with open(MANIFEST_PATH) as handle:
        return sorted(line.strip() for line in handle if line.strip())


def main():
    manifest = read_manifest()
    if manifest is None:
        print("missing src/sources.manifest — run scripts/gen-source-manifest.sh")
        return 1

    disk = found_on_disk()
    disk_set = set(disk)
    manifest_set = set(manifest)

    missing_from_manifest = sorted(disk_set - manifest_set)
    missing_from_disk = sorted(manifest_set - disk_set)

    if not missing_from_manifest and not missing_from_disk:
        print(f"src/sources.manifest matches disk: {len(disk)} entries")
        return 0

    for path in missing_from_manifest:
        print(f"on disk, not in manifest: {path}")
    for path in missing_from_disk:
        print(f"in manifest, not on disk: {path}")
    print("run scripts/gen-source-manifest.sh and commit the result")
    return 1


if __name__ == "__main__":
    sys.exit(main())
