#!/usr/bin/env python3
import json
import re
import sys

FORBIDDEN = [
	(r"\bkillall\s+(-9\s+)?(SpringBoard|backboardd|lockdownd|launchd|mediaserverd|cfprefsd)\b",
	 "killing a system daemon is a respring in all but name and forces the user to retype their passcode"),
	(r"\buicache\b",
	 "uicache resprings the device"),
	(r"\brm\s+(-[a-zA-Z]*\s+)*/Applications/Telegram\.app(/)?(\s|$)",
	 "deleting the bundle unregisters the app with SpringBoard; replace the binary only"),
	(r"\bkillall\s+-9\s+Telegram\b",
	 "a hard kill mid-binlog-write can log the user out; send SIGTERM, sleep, then escalate only if it is still alive"),
	(r"telegramdev://(send|call)\b",
	 "outward actions on the user's real account are forbidden"),
]

def main():
	try:
		payload = json.load(sys.stdin)
	except Exception:
		sys.exit(0)
	command = payload.get("tool_input", {}).get("command", "")
	if not command:
		sys.exit(0)
	for pattern, reason in FORBIDDEN:
		if re.search(pattern, command):
			print("Blocked by .claude/hooks/guard-device.py: " + reason, file=sys.stderr)
			sys.exit(2)
	sys.exit(0)

main()
