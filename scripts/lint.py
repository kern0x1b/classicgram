#!/usr/bin/env python3
import importlib
import os
import pkgutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import tglint

HELPERS = ("tree", "grouped_classes")


def checks():
    names = []
    for module in pkgutil.iter_modules(tglint.__path__):
        if module.name not in HELPERS:
            names.append(module.name.replace("_", "-"))
    return sorted(names)


def load(name):
    return importlib.import_module("tglint." + name.replace("-", "_"))


def self_test_all():
    failed = 0
    for name in ["grouped-classes"] + checks():
        module = load(name)
        if hasattr(module, "self_test"):
            failed |= module.self_test()
    return failed


def main(argv):
    if not argv or argv[0] in ("-h", "--help", "--list"):
        print("usage: lint.py CHECK [ARGS...] | lint.py --self-test")
        print("checks: " + " ".join(checks()))
        return 0 if argv else 2
    if argv[0] == "--self-test":
        return self_test_all()
    if argv[0] not in checks():
        print("lint.py: no check named %s; checks: %s" % (argv[0], " ".join(checks())),
              file=sys.stderr)
        return 2
    return load(argv[0]).main(argv[1:])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
