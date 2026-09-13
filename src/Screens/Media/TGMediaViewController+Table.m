#import "TGMediaViewControllerInternal.h"
#import "TGChatViewController.h"
#import "TGClient+Files.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGProgressIndicatorView.h"
#import "TGMediaFullscreenController.h"
#import "TGStickersViewController.h"

@implementation TGMediaViewController (Table)

- (NSInteger)numberOfRowsForItems {
	if (!TGMediaScopeIsGrid(self.scope))
		return (NSInteger)self.items.count;
	NSInteger perRow = self.itemsPerRow < 1 ? 1 : self.itemsPerRow;
	return ((NSInteger)self.items.count + perRow - 1) / perRow;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSInteger rows = [self numberOfRowsForItems];
	return self.canLoadMore ? rows + 1 : rows;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row >= [self numberOfRowsForItems])
		return 50.0f;
	return TGMediaScopeIsGrid(self.scope) ? kMediaRowHeight : kMediaListRowHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row >= [self numberOfRowsForItems])
		return [self loadingCellForTableView:tableView];
	if (!TGMediaScopeIsGrid(self.scope))
		return [self listCellForTableView:tableView atRow:indexPath.row];
	return [self gridCellForTableView:tableView atRow:indexPath.row];
}

- (UITableViewCell *)loadingCellForTableView:(UITableView *)tableView {
	static NSString *loadingIdentifier = @"TGMediaLoading";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:loadingIdentifier];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:loadingIdentifier];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.backgroundColor = [UIColor clearColor];
		UIActivityIndicatorView *spinner = [[TGProgressIndicatorView alloc]
			initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		spinner.tag = 401;
		spinner.frame = CGRectMake(
			(CGFloat)(int)((tableView.bounds.size.width - spinner.frame.size.width) / 2), 14,
			spinner.frame.size.width, spinner.frame.size.height);
		spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		[cell.contentView addSubview:spinner];
	}
	UIActivityIndicatorView *spinner = (UIActivityIndicatorView *)[cell.contentView viewWithTag:401];
	[spinner startAnimating];
	return cell;
}

- (UITableViewCell *)listCellForTableView:(UITableView *)tableView atRow:(NSInteger)row {
	static NSString *listIdentifier = @"TGMediaList";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:listIdentifier];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:listIdentifier];
		cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
	}
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.accessoryType = UITableViewCellAccessoryNone;

	if (row < (NSInteger)self.items.count) {
		NSDictionary *item = self.items[row];
		cell.textLabel.text = item[@"title"];
		NSString *detail = item[@"detail"];
		NSString *mime = item[@"mime"];
		if (self.scope == TGMediaScopeFiles && [mime isKindOfClass:NSString.class] && mime.length) {
			NSString *known = self.extensionCache[mime];
			if (known.length)
				detail = [NSString stringWithFormat:@"%@ · %@",
					[known uppercaseString], detail];
			else if (!known)
				[self loadExtensionForMime:mime];
		}
		cell.detailTextLabel.text = detail;
	}
	return cell;
}

UIImage *TGMediaMinithumbImage(NSDictionary *item) {
	NSDictionary *minithumb = item[@"minithumb"];
	if (![minithumb isKindOfClass:NSDictionary.class])
		return nil;

	NSString *key = minithumb[@"data"];
	if (![key isKindOfClass:NSString.class] || key.length == 0)
		return nil;

	static NSCache *cache = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		cache = [[NSCache alloc] init];
		cache.countLimit = 64;
		[[NSNotificationCenter defaultCenter]
			addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
						object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *__unused note) {
						[cache removeAllObjects];
					}];
	});

	UIImage *image = [cache objectForKey:key];
	if (image)
		return image;

	NSData *bytes = [[TGClient shared] minithumbnailData:minithumb];
	if (bytes.length == 0)
		return nil;
	image = [UIImage imageWithData:bytes];
	if (!image)
		return nil;

	[cache setObject:image forKey:key];
	return image;
}

- (UITableViewCell *)gridCellForTableView:(UITableView *)tableView atRow:(NSInteger)row {
	static NSString *gridIdentifier = @"TGMediaGrid";
	TGMediaGridCell *cell = (TGMediaGridCell *)[tableView dequeueReusableCellWithIdentifier:gridIdentifier];
	if (!cell) {
		cell = [[TGMediaGridCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:gridIdentifier];
	}
	cell.recycler = self.recycler;
	cell.gridDelegate = self;
	cell.instantThumbnailProvider = ^UIImage *(NSDictionary *item) {
		return TGMediaMinithumbImage(item);
	};

	NSInteger perRow = self.itemsPerRow < 1 ? 1 : self.itemsPerRow;
	NSInteger base = row * perRow;
	NSInteger end = MIN(base + perRow, (NSInteger)self.items.count);
	NSArray *slice = base < end
		? [self.items subarrayWithRange:NSMakeRange(base, end - base)]
		: @[];

	[cell configureWithItems:slice baseIndex:base];
	return cell;
}

- (void)tableView:(UITableView *)tableView
	  willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!self.canLoadMore || self.loading)
		return;
	if (indexPath.row + 4 >= [self numberOfRowsForItems])
		[self loadNextPage];
}

- (void)tableView:(UITableView *)tableView
	didEndDisplayingCell:(UITableViewCell *)cell
	   forRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([cell isKindOfClass:[TGMediaGridCell class]])
		[(TGMediaGridCell *)cell releaseTiles];
}

- (void)gridCell:(TGMediaGridCell *)cell tappedItemAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.items.count)
		return;

	TGMediaFullscreenController *viewer = [[TGMediaFullscreenController alloc]
		initWithItems:[self.items copy]
				index:index];
	viewer.chatId = self.chatId;

	__weak typeof(self) weakSelf = self;
	viewer.onMessageDeleted = ^(int64_t messageId) {
		[weakSelf removeItemWithMessageId:messageId];
	};
	viewer.onShowInChat = ^(int64_t messageId) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf dismissViewControllerAnimated:YES completion:^{
			[strongSelf openChatFocusingMessage:messageId];
		}];
	};
	viewer.onOpenStickerSet = ^(int64_t setId) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || setId == 0)
			return;
		TGStickersViewController *pack = [[TGStickersViewController alloc] init];
		pack.page = TGStickersPageSet;
		pack.setId = setId;
		[strongSelf.navigationController pushViewController:pack animated:YES];
	};

	[self presentViewController:viewer animated:YES completion:nil];
}

- (void)openChatFocusingMessage:(int64_t)messageId {
	for (UIViewController *existing in self.navigationController.viewControllers) {
		if (![existing isKindOfClass:[TGChatViewController class]])
			continue;
		TGChatViewController *chat = (TGChatViewController *)existing;
		if (chat.chatId != self.chatId)
			continue;
		[self.navigationController popToViewController:existing animated:YES];
		[chat scrollToMessageId:messageId];
		return;
	}

	if (self.chatId == 0 || !self.navigationController)
		return;
	TGChatViewController *controller = [[TGChatViewController alloc] init];
	controller.chatId = self.chatId;
	controller.chatTitle = self.chatTitle.length ? self.chatTitle : TGL(@"ChatList.UnnamedChat", @"Chat");
	controller.focusMessageId = messageId;
	[self.navigationController pushViewController:controller animated:YES];
}

- (void)removeItemWithMessageId:(int64_t)messageId {
	for (NSInteger i = 0; i < (NSInteger)self.items.count; i++) {
		if ([self.items[i][@"messageId"] longLongValue] != messageId)
			continue;
		[self.items removeObjectAtIndex:i];
		[self.tableView reloadData];
		[self setEmptyVisible:(self.items.count == 0 && !self.canLoadMore) animated:YES];
		return;
	}
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView != self.tableView || self.items.count == 0)
		return;
	if (!scrollView.isDragging && !scrollView.isDecelerating)
		return;

	NSArray *visible = [self.tableView indexPathsForVisibleRows];
	if (visible.count == 0)
		return;

	NSIndexPath *top = visible[0];
	NSInteger perRow = TGMediaScopeIsGrid(self.scope)
		? (self.itemsPerRow < 1 ? 1 : self.itemsPerRow)
		: 1;
	NSInteger index = top.row * perRow;
	if (index >= (NSInteger)self.items.count)
		index = (NSInteger)self.items.count - 1;

	NSString *month = TGMediaMonthForDate([self.items[index][@"date"] integerValue]);
	if (month.length == 0)
		return;

	self.dateIndicator.text = month;
	if (self.dateIndicator.alpha < 1.0f) {
		[UIView animateWithDuration:0.15 animations:^{
			self.dateIndicator.alpha = 1.0f;
		}];
	}
}

- (void)hideDateIndicator {
	if (self.dateIndicator.alpha == 0.0f)
		return;
	[UIView animateWithDuration:0.25 animations:^{
		self.dateIndicator.alpha = 0.0f;
	}];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	[self hideDateIndicator];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	if (!decelerate)
		[self hideDateIndicator];
}

@end
