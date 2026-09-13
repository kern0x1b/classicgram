#!/usr/bin/env python3
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")

if not os.path.isdir(SRC):
    raise SystemExit(f"source root not found: {SRC}")

TINT_RECEIVER_OK = re.compile(
    r"(navigationBar|toolbar|tabBar|searchBar|navigationController|barTintColor"
    r"|tg_setTintColor|UISearchBar|UINavigationBar|UIToolbar|UITabBar)"
)

BANNED = [
    ("UICollectionView", re.compile(r"\bUICollectionView\w*\b"),
     "iOS 6 has no UICollectionView; every list here is a UITableView"),
    ("UIAlertController", re.compile(r"\bUIAlertController\b"),
     "iOS 8; use UIAlertView or UIActionSheet"),
    ("WKWebView", re.compile(r"\bWKWebView\b"),
     "iOS 8; use UIWebView"),
    ("UNUserNotificationCenter", re.compile(r"\bUNUserNotificationCenter\b"),
     "iOS 10; use UILocalNotification"),
    ("NSLayoutConstraint", re.compile(r"\bNSLayoutConstraint\b|\bNSLayoutAnchor\b"),
     "Auto Layout is not used on this target; compute frames"),
    ("estimatedRowHeight", re.compile(r"\bestimatedRowHeight\b"),
     "iOS 7; the table asks for every row height here"),
    ("UITableViewAutomaticDimension", re.compile(r"\bUITableViewAutomaticDimension\b"),
     "iOS 8 self-sizing; it is -1 on this target, so return a real height (1 for a hairline footer)"),
    ("tintAdjustmentMode", re.compile(r"\btintAdjustmentMode\b"),
     "iOS 7"),
    ("base64 NSData category", re.compile(
        r"\bbase64EncodedStringWithOptions\b|\bbase64EncodedDataWithOptions\b"
        r"|\binitWithBase64EncodedString\b|\binitWithBase64EncodedData\b"),
     "iOS 7; use TGBase64Encode/TGBase64Decode - the iOS 7 category throws "
     "unrecognized selector on this target, which crashed the first launch on a fresh database"),
    ("UIBlurEffect", re.compile(r"\bUIBlurEffect\b|\bUIVisualEffectView\b"),
     "iOS 8"),
    ("CallKit", re.compile(r"\bCXProvider\b|\bCXCallController\b|<CallKit/"),
     "iOS 10; the SpringBoard tweak provides the call UI instead"),
    ("PushKit", re.compile(r"\bPKPushRegistry\b|<PushKit/"),
     "iOS 8"),
    ("LocalAuthentication", re.compile(r"\bLAContext\b|<LocalAuthentication/"),
     "iOS 8, and the supported hardware has no sensor"),
    ("VideoToolbox", re.compile(r"\bVTCompressionSession\w*\b|\bVTDecompressionSession\w*\b|<VideoToolbox/"),
     "iOS 8; the vendored VP8 codec is the encode and decode path"),
    ("UIView.tintColor", re.compile(r"(?<![A-Za-z0-9_])\w*\.tintColor\b"),
     "UIView.tintColor is iOS 7; use tg_setTintColor: or a theme colour"),
]


def inside_string_literal(line, start):
    quotes = 0
    index = 0
    while index < start:
        character = line[index]
        if character == "\\":
            index += 2
            continue
        if character == '"':
            quotes += 1
        index += 1
    return quotes % 2 == 1


def offenders():
    found = []
    for base, _dirs, files in os.walk(SRC):
        for name in files:
            if not name.endswith((".m", ".mm", ".h", ".c")):
                continue
            path = os.path.join(base, name)
            with open(path, encoding="utf-8", errors="replace") as handle:
                for number, line in enumerate(handle, 1):
                    for label, pattern, why in BANNED:
                        match = pattern.search(line)
                        if not match:
                            continue
                        if inside_string_literal(line, match.start()):
                            continue
                        if label == "UIView.tintColor" and TINT_RECEIVER_OK.search(line):
                            continue
                        found.append((os.path.relpath(path, ROOT), number, label, why,
                                      line.strip()))
    return found


def main():
    found = offenders()
    if not found:
        print("lint-sdk-ceiling: no API above the iOS 6 SDK ceiling in src/")
        return 0
    for path, number, label, why, text in found:
        print(f"{path}:{number}: {label} — {why}")
        print(f"    {text}")
    print(f"lint-sdk-ceiling: {len(found)} use(s) of API the iOS 6 SDK does not have")
    return 1


if __name__ == "__main__":
    sys.exit(main())
