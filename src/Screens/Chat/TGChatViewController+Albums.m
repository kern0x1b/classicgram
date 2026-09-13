#import "TGChatViewController.h"
#import "TGDayWindow.h"
#import "TGIcons.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGDayCalendarView.h"
#import "TGPopupMenu.h"
#import "TGMosaicLayout.h"
#import "TGClient+Search.h"

@implementation TGChatViewController (Albums)

- (BOOL)messageCanTile:(NSDictionary *)m {
	if ([m[@"service"] boolValue])
		return NO;
	NSString *album = m[@"albumId"];
	if (![album isKindOfClass:NSString.class] || !album.length ||
		[album isEqualToString:@"0"])
		return NO;
	if (![m[@"id"] isKindOfClass:NSNumber.class])
		return NO;
	NSString *kind = m[@"kind"];
	return [kind isEqualToString:@"messagePhoto"] ||
		[kind isEqualToString:@"messageVideo"] ||
		[kind isEqualToString:@"messageAnimation"];
}

- (NSInteger)displayRowCount {
	return (NSInteger)self.displayRows.count;
}

- (NSDictionary *)messageAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)self.displayRows.count)
		return nil;
	NSInteger index = [self.displayRows[row] unsignedIntegerValue];
	return index < self.messages.count ? self.messages[index] : nil;
}

- (NSArray *)messagesAtRow:(NSInteger)row {
	NSArray *album = [self albumAtRow:row];
	if (album)
		return album;
	NSDictionary *m = [self messageAtRow:row];
	return m ? @[ m ] : @[];
}

- (NSArray *)albumAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)self.displayRows.count)
		return nil;
	return self.albumsByRow[@(row)];
}

- (NSInteger)rowForMessageId:(int64_t)messageId {
	NSNumber *row = self.rowByMessageId[@(messageId)];
	return row ? [row integerValue] : NSNotFound;
}

- (CGSize)mosaicBoundsFor:(NSDictionary *)m {
	CGSize maxDimensions = TGChatIsPad() ? CGSizeMake(440, 440)
										 : CGSizeMake(300, 380);
	CGFloat budget = [self maxBubbleWidthFor:m] - 2 * kPadH;
	if (budget < kMosaicMinTileSide)
		budget = kMosaicMinTileSide;
	CGFloat scale = MIN(1.0f, budget / MAX(1.0f, maxDimensions.width));
	return CGSizeMake(floorf(maxDimensions.width * scale),
		floorf(maxDimensions.height * scale));
}

- (NSDictionary *)mosaicForRow:(NSInteger)row {
	NSArray *album = [self albumAtRow:row];
	if (album.count < 2)
		return nil;

	NSNumber *key = album[0][@"id"];
	if (![key isKindOfClass:NSNumber.class])
		return nil;
	NSDictionary *cached = self.mosaics[key];
	if (cached)
		return cached;

	CGSize sizes[kMosaicMaxItems];
	NSInteger count = MIN(album.count, (NSInteger)kMosaicMaxItems);
	for (NSInteger i = 0; i < count; i++) {
		CGSize declared = [self declaredPixelSizeFor:album[i]];
		if (declared.width < 1 || declared.height < 1)
			declared = CGSizeMake(256, 256);
		sizes[i] = declared;
	}

	TGMosaicTile tiles[kMosaicMaxItems];
	CGSize total = CGSizeZero;
	NSUInteger laid = TGMosaicLayoutTiles(sizes, count,
		[self mosaicBoundsFor:album[0]],
		kAlbumGap, NO,
		tiles, kMosaicMaxItems, &total);
	if (laid < 2)
		return nil;

	NSMutableArray *frames = [NSMutableArray arrayWithCapacity:laid];
	for (NSInteger i = 0; i < laid; i++) {
		[frames addObject:[NSValue valueWithCGRect:tiles[i].frame]];
		NSNumber *memberId = album[i][@"id"];
		if ([memberId isKindOfClass:NSNumber.class])
			self.tileSizes[memberId] = [NSValue valueWithCGSize:tiles[i].frame.size];
	}

	NSDictionary *mosaic = @{@"size" : [NSValue valueWithCGSize:total],
		@"frames" : frames};
	self.mosaics[key] = mosaic;
	return mosaic;
}

- (CGSize)tileSizeForMessage:(NSDictionary *)m {
	NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
	if (!messageId)
		return CGSizeZero;
	NSValue *known = self.tileSizes[messageId];
	if (known)
		return [known CGSizeValue];
	NSNumber *row = self.rowByMessageId[messageId];
	if (!row || !self.albumsByRow[row])
		return CGSizeZero;
	[self mosaicForRow:[row integerValue]];
	known = self.tileSizes[messageId];
	return known ? [known CGSizeValue] : CGSizeZero;
}

- (CGSize)imageSizeForRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	return m ? [self imageSizeFor:m] : CGSizeZero;
}

- (BOOL)scrollToMessageId:(int64_t)messageId {
	NSInteger row = [self rowForMessageId:messageId];
	if (row == NSNotFound)
		return NO;

	NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:0];
	[self.table scrollToRowAtIndexPath:path
					  atScrollPosition:UITableViewScrollPositionMiddle
							  animated:YES];
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf || strongSelf.actionsSheet)
				return;
			[strongSelf setPressedRow:row];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.65 * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{
					TGChatViewController *innerSelf = weakSelf;
					if (innerSelf && innerSelf.pressedRow == row)
						[innerSelf setPressedRow:-1];
				});
		});
	return YES;
}

- (BOOL)dayHeadersOpenTheCalendar {
	return self.chatId != 0 && self.threadId == 0 && self.savedTopicId == 0 &&
		self.directMessagesTopicId == 0 &&
		!self.selecting && self.messagesBeforePinnedList == nil;
}

- (void)openDayCalendarAroundDate:(NSTimeInterval)date {
	if (![self dayHeadersOpenTheCalendar] || date <= 0)
		return;

	[self touchedMessageBackground];

	NSMutableArray *loadedDates = [NSMutableArray arrayWithCapacity:self.messages.count];
	for (NSDictionary *m in self.messages) {
		if (![m isKindOfClass:NSDictionary.class])
			continue;
		NSNumber *when = [m[@"date"] isKindOfClass:NSNumber.class] ? m[@"date"] : nil;
		if (when)
			[loadedDates addObject:when];
	}

	__weak typeof(self) weakSelf = self;
	[TGDayCalendarView showForChat:self.chatId
						aroundDate:date
					   loadedDates:loadedDates
					reachesPresent:[self historyWindowHoldsTheNewest]
						 onPickDay:^(NSTimeInterval seek, NSTimeInterval dayStart) {
							 [weakSelf jumpToDayFrom:seek dayStart:dayStart];
						 }];
}

- (void)jumpToDayFrom:(NSTimeInterval)seek dayStart:(NSTimeInterval)dayStart {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] messageInChat:self.chatId
					   closestToDate:(NSInteger)seek
						  completion:^(int64_t messageId) {
							  TGChatViewController *strongSelf = weakSelf;
							  if (!strongSelf)
								  return;
							  if (messageId == 0)
								  return;
							  [strongSelf landOnDatedMessage:messageId dayStart:dayStart];
						  }];
}

- (int64_t)firstLoadedMessageOnDayStartingAt:(NSTimeInterval)dayStart {
	for (NSDictionary *m in self.messages) {
		if (![m isKindOfClass:NSDictionary.class])
			continue;
		if (!TGTimestampFallsOnDayStartingAt([m[@"date"] doubleValue], dayStart))
			continue;
		return [m[@"id"] longLongValue];
	}
	return 0;
}

- (BOOL)scrollToDayStartingAt:(NSTimeInterval)dayStart orMessage:(int64_t)messageId {
	int64_t opener = [self firstLoadedMessageOnDayStartingAt:dayStart];
	if (opener != 0 && [self scrollToMessageId:opener])
		return YES;
	return [self scrollToMessageId:messageId];
}

- (void)landOnDatedMessage:(int64_t)messageId dayStart:(NSTimeInterval)dayStart {
	if ([self scrollToDayStartingAt:dayStart orMessage:messageId])
		return;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] historyForChat:self.chatId
							   thread:self.threadId
						aroundMessage:messageId
								newer:kDayJumpContextRows
								limit:kHistoryPageLimit
							onlyLocal:NO
							 progress:nil
						   completion:^(NSArray *messages) {
							   TGChatViewController *strongSelf = weakSelf;
							   if (!strongSelf)
								   return;
							   if (messages.count) {
								   strongSelf.messages = [strongSelf messagesMerging:messages];
								   strongSelf.anchorToBottom = NO;
								   [strongSelf.table reloadData];
								   [strongSelf fetchMissingImages];
								   [strongSelf resolveUnknownSenders];
								   [strongSelf resolveUnknownForwardOrigins];
								   [strongSelf fetchMissingQuotes];
							   }
							   if ([strongSelf scrollToDayStartingAt:dayStart orMessage:messageId])
								   return;
							   [strongSelf loadDeeperHistoryAndScrollTo:messageId];
						   }];
}

@end
