#!/usr/bin/env python3
import collections
import sys
from PIL import Image

WALL_TOLERANCE = 10
FLOOD_TOLERANCE = 30
BUBBLE_FILLS = [
	(255, 255, 255),
	(209, 249, 175),
]
FILL_MATCH_TOLERANCE = 18
MIN_BUBBLE_W = 40
MIN_BUBBLE_H = 20
TAIL_BAND = 10
TAIL_MIN_RUN = 2

AVATAR_SIDE_PT = 38.0
AVATAR_SIDE_PX_BY_SCALE = (AVATAR_SIDE_PT, AVATAR_SIDE_PT * 2.0)
AVATAR_SIDE_PX = max(AVATAR_SIDE_PX_BY_SCALE)
AVATAR_TOLERANCE_PX = 12
AVATAR_BOTTOM_TOLERANCE_PX = 12
AVATAR_OVERLAP_TOLERANCE_PX = 22
AVATAR_SEARCH_LEFT_PX = 90
HAS_AVATARS_MIN_INSET_PX = 40
CLIPPED_EDGE_SLACK_PX = 2

PLATE_MIN_W = 18
PLATE_MIN_H = 12
PLATE_MAX_H = 50
PLATE_SEARCH_PX = 60
PLATE_BAND_PX = 40


def close(a, b, tol):
	return all(abs(a[i] - b[i]) <= tol for i in range(3))


def load(path):
	img = Image.open(path).convert("RGB")
	return img, img.load()


def wallpaper_color(px, w, h, top, bottom):
	samples = {}
	for y in range(top, bottom, 2):
		for x in range(0, w, 2):
			c = px[x, y]
			samples[c] = samples.get(c, 0) + 1
	return max(samples.items(), key=lambda kv: kv[1])[0]


def flood_regions(px, w, h, wallpaper, top=0, bottom=None):
	if bottom is None:
		bottom = h
	visited = [[False] * w for _ in range(h)]
	regions = []
	for y in range(top, bottom):
		for x in range(w):
			if visited[y][x]:
				continue
			c = px[x, y]
			fill_class = next((f for f in BUBBLE_FILLS if close(c, f, FILL_MATCH_TOLERANCE)), None)
			if fill_class is None:
				visited[y][x] = True
				continue
			stack = [(x, y)]
			visited[y][x] = True
			pts = []
			while stack:
				cx, cy = stack.pop()
				pts.append((cx, cy))
				for nx, ny in ((cx+1, cy), (cx-1, cy), (cx, cy+1), (cx, cy-1)):
					if top <= ny < bottom and 0 <= nx < w and not visited[ny][nx]:
						nc = px[nx, ny]
						if close(nc, fill_class, FILL_MATCH_TOLERANCE):
							visited[ny][nx] = True
							stack.append((nx, ny))
			if len(pts) > 200:
				xs = [p[0] for p in pts]
				ys = [p[1] for p in pts]
				minx, maxx = min(xs), max(xs)
				miny, maxy = min(ys), max(ys)
				if (maxx - minx) >= MIN_BUBBLE_W and (maxy - miny) >= MIN_BUBBLE_H:
					fill_samples = [px[px_x, py_y] for (px_x, py_y) in pts[:50]]
					seed = fill_samples[len(fill_samples) // 2]
					regions.append({
						"box": (minx, miny, maxx, maxy),
						"fill": seed,
						"pixels": set(pts),
					})
	return regions


def row_span(pixels, y, x0, x1):
	xs = [x for (x, yy) in pixels if yy == y and x0 <= x <= x1]
	if not xs:
		return None
	return min(xs), max(xs)


def is_wallpaper(c, wallpaper):
	return close(c, wallpaper, WALL_TOLERANCE)


def is_bubble_fill(c):
	return any(close(c, f, FILL_MATCH_TOLERANCE) for f in BUBBLE_FILLS)


EDGE_BLEND_MARGIN = 3


def is_edge_blend(c, wallpaper):
	for f in BUBBLE_FILLS:
		ok = True
		for i in range(3):
			lo, hi = sorted((wallpaper[i], f[i]))
			if not (lo - EDGE_BLEND_MARGIN <= c[i] <= hi + EDGE_BLEND_MARGIN):
				ok = False
				break
		if ok:
			return True
	return False


ERODE_KERNEL = 2


def find_foreground_blobs(px, w, h, wallpaper, x0, y0, x1, y1, exclude_bubble_fill=False, erode=False):
	x0 = max(0, x0)
	y0 = max(0, y0)
	x1 = min(w, x1)
	y1 = min(h, y1)

	def is_background(c):
		if is_wallpaper(c, wallpaper):
			return True
		if exclude_bubble_fill and (is_bubble_fill(c) or is_edge_blend(c, wallpaper)):
			return True
		return False

	fg = {}
	for y in range(y0, y1):
		for x in range(x0, x1):
			fg[(x, y)] = not is_background(px[x, y])

	if erode:
		k = ERODE_KERNEL
		eroded = {}
		for (x, y), v in fg.items():
			if not v:
				eroded[(x, y)] = False
				continue
			ok = True
			for dx in range(-k, k + 1):
				if not fg.get((x + dx, y), False):
					ok = False
					break
			if ok:
				for dy in range(-k, k + 1):
					if not fg.get((x, y + dy), False):
						ok = False
						break
			eroded[(x, y)] = ok
		fg = eroded

	visited = set()
	blobs = []
	for y in range(y0, y1):
		for x in range(x0, x1):
			if (x, y) in visited:
				continue
			if not fg.get((x, y), False):
				visited.add((x, y))
				continue
			stack = [(x, y)]
			visited.add((x, y))
			pts = []
			while stack:
				cx, cy = stack.pop()
				pts.append((cx, cy))
				for nx, ny in ((cx+1, cy), (cx-1, cy), (cx, cy+1), (cx, cy-1)):
					if x0 <= nx < x1 and y0 <= ny < y1 and (nx, ny) not in visited:
						if fg.get((nx, ny), False):
							visited.add((nx, ny))
							stack.append((nx, ny))
			xs = [p[0] for p in pts]
			ys = [p[1] for p in pts]
			blobs.append({
				"box": (min(xs), min(ys), max(xs), max(ys)),
				"pixels": pts,
			})
	return blobs


def check_avatar(px, w, h, wallpaper, bubble_box, incoming):
	minx, miny, maxx, maxy = bubble_box
	if not incoming:
		return None
	overlap_margin = int(AVATAR_SIDE_PX * 0.3)
	sx0 = max(0, minx - AVATAR_SEARCH_LEFT_PX)
	sx1 = min(w, minx + overlap_margin)
	sy0 = maxy - int(AVATAR_SIDE_PX) - AVATAR_TOLERANCE_PX
	sy1 = maxy + AVATAR_TOLERANCE_PX
	blobs = find_foreground_blobs(px, w, h, wallpaper, sx0, sy0, sx1, sy1, exclude_bubble_fill=True, erode=True)
	candidates = []
	partial_candidates = []
	for b in blobs:
		bx0, by0, bx1, by1 = b["box"]
		bw = bx1 - bx0
		bh = by1 - by0
		sides = [side for side in AVATAR_SIDE_PX_BY_SCALE
				 if bh >= side - AVATAR_TOLERANCE_PX * 2]
		if not sides:
			continue
		side = max(sides)
		if bw < side - AVATAR_TOLERANCE_PX * 2:
			if bx1 >= minx - 1:
				partial_candidates.append(b)
			continue
		if len(b["pixels"]) < 0.4 * bw * bh:
			continue
		candidates.append(b)

	if not candidates and not partial_candidates:
		return {"found": False}

	if not candidates:
		avatar = max(partial_candidates, key=lambda b: len(b["pixels"]))
		ax0, ay0, ax1, ay1 = avatar["box"]
		return {
			"found": True,
			"box": avatar["box"],
			"aligned": False,
			"bottom_diff": None,
			"overlaps_bubble": True,
			"indented": False,
		}

	avatar = max(candidates, key=lambda b: len(b["pixels"]))
	ax0, ay0, ax1, ay1 = avatar["box"]
	bottom_diff = abs(ay1 - maxy)
	aligned = bottom_diff <= AVATAR_BOTTOM_TOLERANCE_PX
	indented = ax1 <= minx + AVATAR_OVERLAP_TOLERANCE_PX
	overlaps_bubble = not indented
	return {
		"found": True,
		"box": avatar["box"],
		"aligned": aligned,
		"bottom_diff": bottom_diff,
		"overlaps_bubble": overlaps_bubble,
		"indented": indented,
	}


PLATE_EDGE_GAP = 4
PLATE_MIN_BRIGHTNESS = 180


PLATE_MOAT_PX = 8


def find_plate_blob_outside(px, w, h, wallpaper, x0, y0, x1, y1, touching_x):
	x0 = max(0, x0)
	y0 = max(0, y0)
	x1 = min(w, x1)
	y1 = min(h, y1)

	def in_moat(x):
		return abs(x - touching_x) <= PLATE_MOAT_PX

	def is_background(x, y):
		c = px[x, y]
		if is_wallpaper(c, wallpaper):
			return True
		if in_moat(x) and is_bubble_fill(c):
			return True
		return False

	visited = set()
	blobs = []
	for y in range(y0, y1):
		for x in range(x0, x1):
			if (x, y) in visited:
				continue
			if is_background(x, y):
				visited.add((x, y))
				continue
			stack = [(x, y)]
			visited.add((x, y))
			pts = []
			while stack:
				cx, cy = stack.pop()
				pts.append((cx, cy))
				for nx, ny in ((cx+1, cy), (cx-1, cy), (cx, cy+1), (cx, cy-1)):
					if x0 <= nx < x1 and y0 <= ny < y1 and (nx, ny) not in visited:
						if not is_background(nx, ny):
							visited.add((nx, ny))
							stack.append((nx, ny))
			xs = [p[0] for p in pts]
			ys = [p[1] for p in pts]
			blobs.append({"box": (min(xs), min(ys), max(xs), max(ys)), "pixels": pts})

	for b in blobs:
		bx0, by0b, bx1, by1b = b["box"]
		bw = bx1 - bx0
		bh = by1b - by0b
		if bw < PLATE_MIN_W or bh < PLATE_MIN_H or bh > PLATE_MAX_H:
			continue
		return b
	return None


def find_plate_blob_inside(px, w, h, wallpaper, x0, y0, x1, y1):
	blobs = find_foreground_blobs(px, w, h, wallpaper, x0, y0, x1, y1, exclude_bubble_fill=True)
	for b in blobs:
		bx0, by0b, bx1, by1b = b["box"]
		bw = bx1 - bx0
		bh = by1b - by0b
		if bw < PLATE_MIN_W or bh < PLATE_MIN_H or bh > PLATE_MAX_H:
			continue
		pts = b["pixels"]
		sample = list(pts)[:100]
		avg = tuple(sum(px[sx, sy][i] for (sx, sy) in sample) / len(sample) for i in range(3))
		if min(avg) < PLATE_MIN_BRIGHTNESS:
			continue
		return b
	return None


def check_plate(px, w, h, wallpaper, bubble_box, incoming):
	minx, miny, maxx, maxy = bubble_box
	by0 = maxy - PLATE_BAND_PX
	by1 = maxy + 8

	if incoming:
		sx0, sx1 = maxx, maxx + PLATE_SEARCH_PX
		touching_x = maxx
	else:
		sx0, sx1 = minx - PLATE_SEARCH_PX, minx
		touching_x = minx

	outside_plate = find_plate_blob_outside(px, w, h, wallpaper, sx0, by0, sx1, by1, touching_x)

	inside_x0, inside_x1 = (maxx - PLATE_SEARCH_PX, maxx) if incoming else (minx, minx + PLATE_SEARCH_PX)
	inside_x0 = max(minx, inside_x0)
	inside_x1 = min(maxx, inside_x1)
	inside_y0 = max(miny, maxy - PLATE_BAND_PX)
	inside_y1 = maxy
	inside_plate = find_plate_blob_inside(px, w, h, wallpaper, inside_x0, inside_y0, inside_x1, inside_y1)

	return {
		"outside_found": outside_plate is not None,
		"outside_box": outside_plate["box"] if outside_plate else None,
		"inside_found": inside_plate is not None,
		"inside_box": inside_plate["box"] if inside_plate else None,
	}


def check_bubble(region, w, h):
	minx, miny, maxx, maxy = region["box"]
	pixels = region["pixels"]
	bw = maxx - minx
	bh = maxy - miny

	body_top = miny
	body_bottom = maxy - TAIL_BAND
	if body_bottom <= body_top:
		body_bottom = miny + int(bh * 0.6)

	left_edges = []
	right_edges = []
	for y in range(body_top, max(body_top + 1, body_bottom)):
		span = row_span(pixels, y, minx - 5, maxx + 5)
		if span:
			left_edges.append(span[0])
			right_edges.append(span[1])

	if not left_edges:
		return {"tail": False, "side": None, "bottom_curve": False, "box": region["box"]}

	body_left = min(left_edges)
	body_right = max(right_edges)

	tail_rows = range(max(body_bottom, miny), maxy + 1)
	left_spur = 0
	right_spur = 0
	for y in tail_rows:
		span = row_span(pixels, y, minx - 8, maxx + 8)
		if not span:
			continue
		lo, hi = span
		if lo < body_left - 1:
			left_spur += 1
		if hi > body_right + 1:
			right_spur += 1

	tail_present = left_spur >= TAIL_MIN_RUN or right_spur >= TAIL_MIN_RUN
	side = None
	if left_spur >= TAIL_MIN_RUN and left_spur >= right_spur:
		side = "left"
	elif right_spur >= TAIL_MIN_RUN:
		side = "right"

	bottom_widths = []
	for y in range(max(miny, maxy - 3), maxy + 1):
		span = row_span(pixels, y, minx - 8, maxx + 8)
		if span:
			bottom_widths.append(span[1] - span[0])
	good_widths = [bw2 for bw2 in bottom_widths if bw2 > 4]
	bottom_curve = len(good_widths) >= 2 and len(good_widths) >= len(bottom_widths) - 1

	return {
		"tail": tail_present,
		"side": side,
		"bottom_curve": bottom_curve,
		"box": region["box"],
	}


def drop_nested(regions):
	kept = []
	for region in regions:
		x0, y0, x1, y1 = region["box"]
		inside_another = False
		for other in regions:
			if other is region:
				continue
			ox0, oy0, ox1, oy1 = other["box"]
			area = (x1 - x0) * (y1 - y0)
			other_area = (ox1 - ox0) * (oy1 - oy0)
			if other_area <= area:
				continue
			if ox0 <= x0 and oy0 <= y0 and ox1 >= x1 and oy1 >= y1:
				inside_another = True
				break
		if not inside_another:
			kept.append(region)
	return kept


def main():
	if len(sys.argv) < 2:
		print("usage: check-bubble-geometry.py <screenshot.png> [--from-x <pixels>]")
		sys.exit(2)
	path = sys.argv[1]
	strict = True
	img = Image.open(path).convert("RGB")
	if "--from-x" in sys.argv:
		left = int(sys.argv[sys.argv.index("--from-x") + 1])
		img = img.crop((left, 0, img.size[0], img.size[1]))
	px = img.load()
	w, h = img.size
	top = int(h * 0.11)
	bottom = int(h * 0.90)
	wallpaper = wallpaper_color(px, w, h, top, bottom)
	regions = flood_regions(px, w, h, wallpaper, top=top, bottom=bottom)
	regions = [r for r in regions if (r["box"][2] - r["box"][0]) < w * 0.97]
	regions = [r for r in regions
			if (r["box"][3] - r["box"][1]) >= h * 0.035]
	regions = drop_nested(regions)

	if not regions:
		print("no bubbles found")
		sys.exit(1)

	incoming_left_edges = [
		r["box"][0] for r in regions
		if r["fill"] and close(r["fill"], BUBBLE_FILLS[0], FILL_MATCH_TOLERANCE)
	]
	has_avatars = bool(incoming_left_edges) and min(incoming_left_edges) >= HAS_AVATARS_MIN_INSET_PX
	if strict:
		print(f"chat shows avatars: {has_avatars} "
			  f"(min incoming bubble left edge = {min(incoming_left_edges) if incoming_left_edges else None})")

	ok = True
	for i, r in enumerate(sorted(regions, key=lambda r: r["box"][1])):
		res = check_bubble(r, w, h)
		minx, miny, maxx, maxy = res["box"]
		bh = maxy - miny
		clipped = maxy >= bottom - CLIPPED_EDGE_SLACK_PX
		status = "OK" if (res["tail"] and res["bottom_curve"]) else "FAIL"
		if clipped:
			status = "CLIPPED"
		if status == "FAIL":
			ok = False
		print(f"bubble {i}: box=({minx},{miny})-({maxx},{maxy}) height={bh} "
			  f"tail={res['tail']} side={res['side']} bottom_curve={res['bottom_curve']} [{status}]")

		if not strict or clipped:
			continue

		incoming = r["fill"] and close(r["fill"], BUBBLE_FILLS[0], FILL_MATCH_TOLERANCE)
		avatar = check_avatar(px, w, h, wallpaper, r["box"], incoming) if has_avatars else None
		if incoming and not has_avatars:
			print(f"  avatar: chat shows no avatars [SKIP]")
		if avatar is not None:
			if not avatar["found"]:
				print(f"  avatar: none found in search band [SKIP]")
			else:
				ax0, ay0, ax1, ay1 = avatar["box"]
				a_status = "OK" if (avatar["aligned"] and not avatar["overlaps_bubble"]) else "FAIL"
				if a_status == "FAIL":
					ok = False
				print(f"  avatar: box=({ax0},{ay0})-({ax1},{ay1}) "
					  f"bottom_diff={avatar['bottom_diff']} aligned={avatar['aligned']} "
					  f"overlaps_bubble={avatar['overlaps_bubble']} [{a_status}]")

				indent_status = "OK" if (avatar["indented"] and not avatar["overlaps_bubble"]) else "FAIL"
				if indent_status == "FAIL":
					ok = False
				print(f"  indent: bubble_left={minx} avatar_right={ax1} "
					  f"indented={avatar['indented']} [{indent_status}]")

		plate = check_plate(px, w, h, wallpaper, r["box"], incoming)
		p_status = "OK" if (plate["outside_found"] and not plate["inside_found"]) else "FAIL"
		if p_status == "FAIL":
			ok = False
		print(f"  plate: outside={plate['outside_found']} box={plate['outside_box']} "
			  f"inside_bubble={plate['inside_found']} box={plate['inside_box']} [{p_status}]")

	sys.exit(0 if ok else 1)


if __name__ == "__main__":
	main()
