#import "TGMosaicLayout.h"

#include <string.h>
#include <math.h>
#include <float.h>

static const CGFloat kMosaicMinWidth = 68.0f;
static const CGFloat kMosaicMinHeight = 81.0f;

static CGFloat TGMosaicFloorToScreenPixels(CGFloat value) {
	CGFloat scale = [UIScreen mainScreen].scale;
	if (scale < 1.0f)
		scale = 1.0f;
	return floorf(value * scale) / scale;
}

static void TGMosaicSet(TGMosaicTile *tiles, NSUInteger index,
	CGFloat x, CGFloat y, CGFloat w, CGFloat h,
	NSUInteger position) {
	tiles[index].frame = CGRectMake(x, y, w, h);
	tiles[index].position = position;
}

static CGFloat TGMosaicMultiHeight(const CGFloat *ratios, NSUInteger count,
	CGFloat maxWidth, CGFloat spacing) {
	CGFloat sum = 0;
	for (NSInteger i = 0; i < count; i++)
		sum += ratios[i];
	if (sum < 0.0001f)
		sum = 1.0f;
	return (maxWidth - (CGFloat)(count - 1) * spacing) / sum;
}

static CGFloat TGMosaicAttemptDiff(const CGFloat *cropped,
	const NSUInteger *counts,
	NSUInteger rowCount,
	CGFloat maxWidth,
	CGFloat spacing,
	CGFloat maxHeight) {
	CGFloat totalHeight = spacing * (CGFloat)(rowCount - 1);
	CGFloat minLineHeight = FLT_MAX;
	NSInteger index = 0;
	for (NSInteger i = 0; i < rowCount; i++) {
		CGFloat rowHeight = TGMosaicMultiHeight(cropped + index, counts[i],
			maxWidth, spacing);
		CGFloat flooredRowHeight = floorf(rowHeight);
		totalHeight += flooredRowHeight;
		if (flooredRowHeight < minLineHeight)
			minLineHeight = flooredRowHeight;
		index += counts[i];
	}

	CGFloat diff = (CGFloat)fabs((double)(totalHeight - maxHeight));
	for (NSInteger i = 0; i + 1 < rowCount; i++) {
		if (counts[i] > counts[i + 1]) {
			diff *= 1.5f;
			break;
		}
	}
	if (minLineHeight < kMosaicMinWidth)
		diff *= 1.5f;
	return diff;
}

static NSUInteger TGMosaicSolve(const CGFloat *ratios,
	NSUInteger count,
	CGFloat averageAspectRatio,
	CGSize maxSize,
	CGFloat spacing,
	TGMosaicTile *tiles) {
	CGFloat cropped[kMosaicMaxItems];
	for (NSInteger i = 0; i < count; i++) {
		CGFloat ratio = (averageAspectRatio > 1.1f)
			? MAX(1.0f, ratios[i])
			: MIN(1.0f, ratios[i]);
		cropped[i] = MAX(0.66667f, MIN(1.7f, ratio));
	}

	CGFloat maxHeight = floorf(maxSize.width / 3.0f * 4.0f);
	NSInteger secondRowCap = (averageAspectRatio < 0.85f) ? 4 : 3;

	NSUInteger bestCounts[4] = {0, 0, 0, 0};
	NSInteger bestRows = 0;
	CGFloat bestDiff = FLT_MAX;
	NSUInteger attempt[4];

	for (NSInteger first = 1; first + 1 <= count; first++) {
		attempt[0] = first;
		attempt[1] = count - first;
		if (attempt[0] <= 3 && attempt[1] <= 3) {
			CGFloat diff = TGMosaicAttemptDiff(cropped, attempt, 2,
				maxSize.width, spacing, maxHeight);
			if (diff < bestDiff) {
				bestDiff = diff;
				bestRows = 2;
				memcpy(bestCounts, attempt, 2 * sizeof(NSUInteger));
			}
		}
	}

	for (NSInteger first = 1; first + 2 <= count; first++) {
		for (NSInteger second = 1; first + second + 1 <= count; second++) {
			attempt[0] = first;
			attempt[1] = second;
			attempt[2] = count - first - second;
			if (attempt[0] > 3 || attempt[1] > secondRowCap || attempt[2] > 3)
				continue;
			CGFloat diff = TGMosaicAttemptDiff(cropped, attempt, 3,
				maxSize.width, spacing, maxHeight);
			if (diff < bestDiff) {
				bestDiff = diff;
				bestRows = 3;
				memcpy(bestCounts, attempt, 3 * sizeof(NSUInteger));
			}
		}
	}

	for (NSInteger first = 1; first + 3 <= count; first++) {
		for (NSInteger second = 1; first + second + 2 <= count; second++) {
			for (NSInteger third = 1; first + second + third + 1 <= count; third++) {
				attempt[0] = first;
				attempt[1] = second;
				attempt[2] = third;
				attempt[3] = count - first - second - third;
				if (attempt[0] > 3 || attempt[1] > 3 ||
					attempt[2] > 3 || attempt[3] > 3)
					continue;
				CGFloat diff = TGMosaicAttemptDiff(cropped, attempt, 4,
					maxSize.width, spacing, maxHeight);
				if (diff < bestDiff) {
					bestDiff = diff;
					bestRows = 4;
					memcpy(bestCounts, attempt, 4 * sizeof(NSUInteger));
				}
			}
		}
	}

	if (bestRows == 0) {
		CGFloat y = 0;
		for (NSInteger i = 0; i < count; i++) {
			CGFloat height = ceilf(maxSize.width / MAX(0.66667f, cropped[i]));
			NSUInteger position = TGMosaicPositionLeft | TGMosaicPositionRight |
				(i == 0 ? TGMosaicPositionTop : 0) |
				(i + 1 == count ? TGMosaicPositionBottom : 0);
			TGMosaicSet(tiles, i, 0, y, maxSize.width, height, position);
			y += height + spacing;
		}
		return count;
	}

	CGFloat y = 0;
	NSInteger index = 0;
	for (NSInteger row = 0; row < bestRows; row++) {
		CGFloat rowHeight = TGMosaicMultiHeight(cropped + index, bestCounts[row],
			maxSize.width, spacing);
		CGFloat lineHeight = ceilf(rowHeight);
		CGFloat x = 0;
		NSUInteger rowFlags = (row == 0 ? TGMosaicPositionTop : 0) |
			(row + 1 == bestRows ? TGMosaicPositionBottom : 0);

		for (NSInteger k = 0; k < bestCounts[row]; k++) {
			NSUInteger flags = rowFlags |
				(k == 0 ? TGMosaicPositionLeft : 0) |
				(k + 1 == bestCounts[row] ? TGMosaicPositionRight : 0);
			if (rowFlags == 0)
				flags = TGMosaicPositionInside;

			CGFloat width = ceilf(cropped[index] * lineHeight);
			TGMosaicSet(tiles, index, x, y, width, lineHeight, flags);
			x += width + spacing;
			index++;
		}
		y += lineHeight + spacing;
	}

	CGFloat maxX = 0;
	index = 0;
	for (NSInteger row = 0; row < bestRows; row++) {
		index += bestCounts[row];
		CGFloat edge = CGRectGetMaxX(tiles[index - 1].frame);
		if (edge > maxX)
			maxX = edge;
	}
	index = 0;
	for (NSInteger row = 0; row < bestRows; row++) {
		index += bestCounts[row];
		CGRect frame = tiles[index - 1].frame;
		frame.size.width = MAX(frame.size.width, maxX - frame.origin.x);
		tiles[index - 1].frame = frame;
	}
	return count;
}

NSUInteger TGMosaicLayoutTiles(const CGSize *sizes,
	NSUInteger count,
	CGSize maxSize,
	CGFloat spacing,
	BOOL fillWidth,
	TGMosaicTile *outTiles,
	NSUInteger capacity,
	CGSize *outTotal) {
	if (outTotal)
		*outTotal = CGSizeZero;
	if (!sizes || !outTiles || count < 2 || count > capacity ||
		count > kMosaicMaxItems)
		return 0;
	if (maxSize.width < 1 || maxSize.height < 1)
		return 0;

	char proportions[kMosaicMaxItems + 1];
	CGFloat ratios[kMosaicMaxItems];
	BOOL forceCalc = NO;
	CGFloat averageAspectRatio = 1.0f;

	for (NSInteger i = 0; i < count; i++) {
		CGFloat ratio = (sizes[i].height == 0)
			? 1.0f
			: (sizes[i].width / sizes[i].height);
		ratios[i] = ratio;
		if (ratio > 1.2f)
			proportions[i] = 'w';
		else if (ratio < 0.8f)
			proportions[i] = 'n';
		else
			proportions[i] = 'q';
		if (ratio > 2.0f)
			forceCalc = YES;
		averageAspectRatio += ratio;
	}
	proportions[count] = '\0';
	averageAspectRatio /= (CGFloat)count;

	CGFloat maxAspectRatio = maxSize.height > 0
		? (maxSize.width / maxSize.height)
		: 1.0f;
	CGFloat s = spacing;

	if (!forceCalc && count == 2) {
		CGFloat A0 = ratios[0], A1 = ratios[1];
		if (strcmp(proportions, "ww") == 0 &&
			averageAspectRatio > 1.4f * maxAspectRatio && (A1 - A0) < 0.2f) {
			CGFloat width = maxSize.width;
			CGFloat height = floorf(MIN(MIN(width / A0, width / A1),
				(maxSize.height - s) / 2.0f));
			TGMosaicSet(outTiles, 0, 0, 0, width, height,
				TGMosaicPositionTop | TGMosaicPositionLeft | TGMosaicPositionRight);
			TGMosaicSet(outTiles, 1, 0, height + s, width, height,
				TGMosaicPositionBottom | TGMosaicPositionLeft | TGMosaicPositionRight);
		} else if (strcmp(proportions, "ww") == 0 ||
			strcmp(proportions, "qq") == 0) {
			CGFloat width = (maxSize.width - s) / 2.0f;
			CGFloat height = floorf(MIN(MIN(width / A0, width / A1), maxSize.height));
			TGMosaicSet(outTiles, 0, 0, 0, width, height,
				TGMosaicPositionTop | TGMosaicPositionLeft | TGMosaicPositionBottom);
			TGMosaicSet(outTiles, 1, width + s, 0, width, height,
				TGMosaicPositionTop | TGMosaicPositionRight | TGMosaicPositionBottom);
		} else {
			CGFloat secondWidth = floorf(MIN(0.5f * (maxSize.width - s),
				roundf((maxSize.width - s) / A0 / (1.0f / A0 + 1.0f / A1))));
			CGFloat firstWidth = maxSize.width - secondWidth - s;
			CGFloat height = floorf(MIN(maxSize.height,
				roundf(MIN(firstWidth / A0, secondWidth / A1))));
			TGMosaicSet(outTiles, 0, 0, 0, firstWidth, height,
				TGMosaicPositionTop | TGMosaicPositionLeft | TGMosaicPositionBottom);
			TGMosaicSet(outTiles, 1, firstWidth + s, 0, secondWidth, height,
				TGMosaicPositionTop | TGMosaicPositionRight | TGMosaicPositionBottom);
		}
	} else if (!forceCalc && count == 3) {
		CGFloat A0 = ratios[0], A1 = ratios[1], A2 = ratios[2];
		if (proportions[0] == 'n') {
			CGFloat firstHeight = maxSize.height;
			CGFloat thirdHeight = MIN((maxSize.height - s) * 0.5f,
				roundf(A1 * (maxSize.width - s) / (A2 + A1)));
			CGFloat secondHeight = maxSize.height - thirdHeight - s;
			CGFloat rightWidth = MAX(kMosaicMinWidth,
				MIN((maxSize.width - s) * 0.5f,
					roundf(MIN(thirdHeight * A2, secondHeight * A1))));
			if (fillWidth)
				rightWidth = TGMosaicFloorToScreenPixels(maxSize.width / 2.0f);
			CGFloat leftWidth = roundf(MIN(firstHeight * A0,
				maxSize.width - s - rightWidth));
			if (fillWidth)
				leftWidth = maxSize.width - s - rightWidth;

			TGMosaicSet(outTiles, 0, 0, 0, leftWidth, firstHeight,
				TGMosaicPositionTop | TGMosaicPositionLeft | TGMosaicPositionBottom);
			TGMosaicSet(outTiles, 1, leftWidth + s, 0, rightWidth, secondHeight,
				TGMosaicPositionRight | TGMosaicPositionTop);
			TGMosaicSet(outTiles, 2, leftWidth + s, secondHeight + s,
				rightWidth, thirdHeight,
				TGMosaicPositionRight | TGMosaicPositionBottom);
		} else {
			CGFloat width = maxSize.width;
			CGFloat firstHeight = floorf(MIN(width / A0,
				(maxSize.height - s) * 0.66f));
			TGMosaicSet(outTiles, 0, 0, 0, width, firstHeight,
				TGMosaicPositionTop | TGMosaicPositionLeft | TGMosaicPositionRight);

			width = (maxSize.width - s) / 2.0f;
			CGFloat secondHeight = MIN(maxSize.height - firstHeight - s,
				roundf(MIN(width / A1, width / A2)));
			TGMosaicSet(outTiles, 1, 0, firstHeight + s, width, secondHeight,
				TGMosaicPositionLeft | TGMosaicPositionBottom);
			TGMosaicSet(outTiles, 2, width + s, firstHeight + s, width, secondHeight,
				TGMosaicPositionRight | TGMosaicPositionBottom);
		}
	} else if (!forceCalc && count == 4) {
		CGFloat A0 = ratios[0], A1 = ratios[1], A2 = ratios[2], A3 = ratios[3];
		if (strcmp(proportions, "wwww") == 0 || proportions[0] == 'w') {
			CGFloat w = maxSize.width;
			CGFloat h0 = roundf(MIN(w / A0, (maxSize.height - s) * 0.66f));
			TGMosaicSet(outTiles, 0, 0, 0, w, h0,
				TGMosaicPositionTop | TGMosaicPositionLeft | TGMosaicPositionRight);

			CGFloat h = roundf((maxSize.width - 2 * s) / (A1 + A2 + A3));
			CGFloat w0 = MAX(kMosaicMinWidth,
				MIN((maxSize.width - 2 * s) * 0.4f, h * A1));
			CGFloat w2 = MAX(MAX(kMosaicMinWidth, (maxSize.width - 2 * s) * 0.33f),
				h * A3);
			CGFloat w1 = w - w0 - w2 - 2 * s;
			h = MAX(kMosaicMinHeight, MIN(maxSize.height - h0 - s, h));

			TGMosaicSet(outTiles, 1, 0, h0 + s, w0, h,
				TGMosaicPositionLeft | TGMosaicPositionBottom);
			TGMosaicSet(outTiles, 2, w0 + s, h0 + s, w1, h,
				TGMosaicPositionBottom);
			TGMosaicSet(outTiles, 3, w0 + w1 + 2 * s, h0 + s, w2, h,
				TGMosaicPositionRight | TGMosaicPositionBottom);
		} else {
			CGFloat h = maxSize.height;
			CGFloat w0 = roundf(MIN(h * A0, (maxSize.width - s) * 0.6f));
			TGMosaicSet(outTiles, 0, 0, 0, w0, h,
				TGMosaicPositionTop | TGMosaicPositionLeft | TGMosaicPositionBottom);

			CGFloat w = roundf((maxSize.height - 2 * s) /
				(1.0f / A1 + 1.0f / A2 + 1.0f / A3));
			CGFloat h0 = floorf(w / A1);
			CGFloat h1 = floorf(w / A2);
			CGFloat h2 = h - h0 - h1 - 2 * s;
			w = MAX(kMosaicMinWidth, MIN(maxSize.width - w0 - s, w));

			TGMosaicSet(outTiles, 1, w0 + s, 0, w, h0,
				TGMosaicPositionRight | TGMosaicPositionTop);
			TGMosaicSet(outTiles, 2, w0 + s, h0 + s, w, h1,
				TGMosaicPositionRight);
			TGMosaicSet(outTiles, 3, w0 + s, h0 + h1 + 2 * s, w, h2,
				TGMosaicPositionRight | TGMosaicPositionBottom);
		}
	} else {
		TGMosaicSolve(ratios, count, averageAspectRatio, maxSize, s, outTiles);
	}

	CGFloat width = 0, height = 0;
	for (NSInteger i = 0; i < count; i++) {
		if (outTiles[i].frame.size.width < 1)
			outTiles[i].frame.size.width = 1;
		if (outTiles[i].frame.size.height < 1)
			outTiles[i].frame.size.height = 1;
		width = MAX(width, roundf(CGRectGetMaxX(outTiles[i].frame)));
		height = MAX(height, roundf(CGRectGetMaxY(outTiles[i].frame)));
	}
	if (outTotal)
		*outTotal = CGSizeMake(width, height);
	return count;
}
