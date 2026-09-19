import os
import sys

from tglint import tree

IMAGES = os.path.join(tree.SRC, "Resources", "images")
LAUNCH_PREFIXES = ("Default", "LaunchImage")


def main(args):
    if not os.path.isdir(IMAGES):
        print("lint-image-scales: %s is missing" % IMAGES, file=sys.stderr)
        return 1

    names = os.listdir(IMAGES)
    missing = []
    for name in sorted(names):
        if not name.endswith("@2x.png"):
            continue
        base = name[: -len("@2x.png")]
        if base.startswith(LAUNCH_PREFIXES):
            continue
        if base + ".png" not in names:
            missing.append(base)

    if missing:
        print("lint-image-scales: no @1x artwork for %d image(s); "
              "an iPad 2 draws at scale 1 and imageNamed: returns nil for these"
              % len(missing))
        for base in missing:
            print("  %s@2x.png without %s.png" % (base, base))
        return 1

    print("lint-image-scales: every image ships @1x and @2x")
    return 0
