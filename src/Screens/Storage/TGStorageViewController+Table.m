#import "TGStorageViewController.h"
#import "TGStorageInternal.h"
#import "TGStorageChatViewController.h"
#import "TGLocalization.h"
#import "TGStorageService.h"
#import "TGTheme.h"
#import "TGActionSheet.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGDevice.h"
#import "TGByteFormat.h"
#import "TGHexColour.h"

@implementation TGStorageViewController (Table)

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return TGStorageSectionCount;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	if (section == TGStorageSectionChats && self.detailLoaded && self.chatRows.count == 0)
		return 1;
	if (section == TGStorageSectionEverything)
		return 14;
	if (section == TGStorageSectionSummary && [self diskBarIsAvailable])
		return 64;
	return 46;
}

- (BOOL)diskBarIsAvailable {
	return TGStorageDiskTotalBytes() > 0 && TGStorageDiskFreeBytes() > 0;
}

- (long long)telegramBytesOnDisk {
	long long total = [[self.overview objectForKey:@"total"] longLongValue];
	if (total > 0)
		return total + self.localThumbnailBytes;
	return (self.bytes > 0 ? self.bytes : 0) + self.localThumbnailBytes;
}

- (UIView *)diskBarWithWidth:(CGFloat)width {
	long long total = TGStorageDiskTotalBytes();
	long long freeBytes = TGStorageDiskFreeBytes();
	long long mine = [self telegramBytesOnDisk];
	if (total <= 0)
		return nil;
	if (mine > total - freeBytes)
		mine = total - freeBytes;
	if (mine < 0)
		mine = 0;

	CGFloat barWidth = width - 42;
	if (barWidth < 40)
		barWidth = 40;
	UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(21, 44, barWidth, 8)];
	bar.backgroundColor = TGColourFromHex(0xd7dce3);
	bar.layer.cornerRadius = 4;
	bar.clipsToBounds = YES;

	CGFloat usedFraction = (CGFloat)((double)(total - freeBytes) / (double)total);
	CGFloat mineFraction = (CGFloat)((double)mine / (double)total);
	if (usedFraction > 1.0f)
		usedFraction = 1.0f;
	if (mineFraction > usedFraction)
		mineFraction = usedFraction;
	if (mine > 0 && mineFraction < 0.02f)
		mineFraction = 0.02f;

	UIView *used = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, barWidth * usedFraction, 8)];
	used.backgroundColor = TGColourFromHex(0xa9b0bb);
	[bar addSubview:used];

	UIView *ours = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, barWidth * mineFraction, 8)];
	ours.backgroundColor = [[TGTheme shared] accentColour];
	[bar addSubview:ours];
	return bar;
}

- (NSString *)titleForSection:(NSInteger)section {
	switch (section) {
		case TGStorageSectionSummary:
			return TGL(@"Cache.Title", @"Storage");
		case TGStorageSectionTypes:
			return TGL(@"Cache.ByTypeHeader", @"By media type");
		case TGStorageSectionChats:
			return TGL(@"Cache.ByChatHeader", @"By chat");
		case TGStorageSectionPolicy:
			return TGL(@"Cache.LimitsHeader", @"Cache limits");
		case TGStorageSectionDownloads:
			return TGL(@"Cache.DownloadsHeader", @"Downloads");
		case TGStorageSectionClear:
			return TGL(@"Cache.ClearNone", @"Clear");
		default:
			return @"";
	}
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self titleForSection:section];
	if (!title.length)
		return nil;
	if (section == TGStorageSectionChats && self.detailLoaded && self.chatRows.count == 0)
		return nil;

	BOOL withBar = (section == TGStorageSectionSummary && [self diskBarIsAvailable]);
	CGFloat width = tableView.bounds.size.width;
	UIView *header = [[TGTheme shared] groupedHeaderViewWithTitle:title width:width];
	TGApplyRTLHeaderMirroring(header);
	if (!withBar)
		return header;

	UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 64)];
	container.backgroundColor = [UIColor clearColor];
	UIView *bar = [self diskBarWithWidth:width];
	if (bar) {
		bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[container addSubview:bar];
	}
	if (header)
		[container addSubview:header];
	return container;
}

- (NSString *)footerText {
	return TGL(@"Cache.ClearedMediaFooter", @"Cleared media is downloaded again when you open the message. "
		@"Nothing is deleted from Telegram.");
}

- (CGFloat)footerHeightForWidth:(CGFloat)width {
	return [[TGTheme shared] groupedCommentHeightForText:[self footerText] width:width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	return section == TGStorageSectionEverything
		? [self footerHeightForWidth:tableView.bounds.size.width]
		: 1;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	if (section != TGStorageSectionEverything)
		return nil;
	CGFloat footerWidth = tableView.bounds.size.width;
	UIView *footer = [[TGTheme shared] groupedCommentViewWithText:[self footerText] width:footerWidth];
	TGApplyRTLHeaderMirroring(footer);
	return footer;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == TGStorageSectionEverything)
		return 45;
	return 44;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case TGStorageSectionSummary:
			return [self summaryBaseRows];
		case TGStorageSectionTypes:
			if (!self.detailLoaded)
				return 1;
			return self.typeRows.count ? (NSInteger)self.typeRows.count : 1;
		case TGStorageSectionChats:
			if (!self.detailLoaded)
				return 1;
			return (NSInteger)self.chatRows.count;
		case TGStorageSectionPolicy:
			return 2;
		case TGStorageSectionDownloads:
			return 1;
		case TGStorageSectionClear:
			return 4;
		default:
			return 1;
	}
}

- (UITableViewCell *)plainCellInTable:(UITableView *)tableView {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"row"];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.textLabel.highlightedTextColor = [UIColor whiteColor];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.detailTextLabel.highlightedTextColor = [UIColor whiteColor];
	cell.textLabel.text = @"";
	cell.detailTextLabel.text = @"";
	cell.accessoryView = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	return cell;
}

- (NSInteger)policyTTLSeconds {
	NSDictionary *policy = [TGStorageService cachePolicy];
	id value = [policy objectForKey:@"ttlSeconds"];
	return value ? [value integerValue] : -1;
}

- (long long)policyMaxBytes {
	NSDictionary *policy = [TGStorageService cachePolicy];
	id value = [policy objectForKey:@"maxBytes"];
	return value ? [value longLongValue] : -1;
}

- (NSArray *)policyExcludedChatIds {
	NSDictionary *policy = [TGStorageService cachePolicy];
	NSArray *excluded = [policy objectForKey:@"excludedChatIds"];
	return [excluded isKindOfClass:[NSArray class]] ? excluded : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == TGStorageSectionEverything)
		return [self clearEverythingCellInTable:tableView];

	UITableViewCell *cell = [self plainCellInTable:tableView];

	if (indexPath.section == TGStorageSectionSummary) {
		BOOL busy = self.working || !self.loaded;
		if (indexPath.row == (self.overview ? 3 : 2)) {
			cell.textLabel.text = TGL(@"ClearCache.StorageFree", @"Free on device");
			long long freeBytes = TGStorageDiskFreeBytes();
			long long total = TGStorageDiskTotalBytes();
			if (freeBytes > 0 && total > 0)
				cell.detailTextLabel.text = [NSString stringWithFormat:
						TGL(@"Storage.SizeProgress", @"%@ of %@"),
					TGMediaFormatBytes(freeBytes), TGMediaFormatBytes(total)];
			else if (freeBytes > 0)
				cell.detailTextLabel.text = TGMediaFormatBytes(freeBytes);
			return cell;
		}
		switch (indexPath.row) {
			case 0:
				cell.textLabel.text = TGL(@"Storage.SizeOnDisk", @"Size on disk");
				if (busy)
					cell.accessoryView = [self spinner];
				else
					cell.detailTextLabel.text = [self cacheIsEmpty] ? TGL(@"Cache.ClearEmpty", @"Empty") : TGMediaFormatBytes(self.bytes);
				break;
			case 1:
				cell.textLabel.text = TGL(@"PeerInfo.PaneFiles", @"Files");
				if (busy)
					cell.accessoryView = [self spinner];
				else
					cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)self.files];
				break;
			default:
				cell.textLabel.text = TGL(@"Checkout.TotalAmount", @"Total");
				cell.detailTextLabel.text = TGMediaFormatBytes(
					[[self.overview objectForKey:@"total"] longLongValue]);
				break;
		}
		return cell;
	}

	if (indexPath.section == TGStorageSectionTypes) {
		if (!self.detailLoaded) {
			cell.textLabel.text = TGL(@"Cache.Indexing", @"Telegram is calculating current cache size.\nThis can take a few minutes.");
			cell.textLabel.textColor = [[TGTheme shared] groupedDisabledColour];
			cell.accessoryView = [self spinner];
			return cell;
		}
		if (!self.typeRows.count) {
			cell.textLabel.text = TGL(@"Storage.NoCachedMedia", @"No cached media");
			cell.textLabel.textColor = [[TGTheme shared] groupedDisabledColour];
			return cell;
		}
		NSDictionary *row = [self.typeRows objectAtIndex:indexPath.row];
		cell.textLabel.text = [row objectForKey:@"title"];
		cell.detailTextLabel.text = TGMediaFormatBytes([[row objectForKey:@"size"] longLongValue]);
		if ([self canClear])
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		return cell;
	}

	if (indexPath.section == TGStorageSectionChats) {
		if (!self.detailLoaded) {
			cell.textLabel.text = TGL(@"Cache.Indexing", @"Telegram is calculating current cache size.\nThis can take a few minutes.");
			cell.textLabel.textColor = [[TGTheme shared] groupedDisabledColour];
			cell.accessoryView = [self spinner];
			return cell;
		}
		NSDictionary *row = [self.chatRows objectAtIndex:indexPath.row];
		cell.textLabel.text = [row objectForKey:@"title"];
		cell.detailTextLabel.text = TGMediaFormatBytes([[row objectForKey:@"size"] longLongValue]);
		UIView *indicator = TGStorageDisclosureIndicator();
		if (indicator)
			cell.accessoryView = indicator;
		else
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		return cell;
	}

	if (indexPath.section == TGStorageSectionDownloads) {
		cell.textLabel.text = TGL(@"DownloadList.ClearAlertTitle", @"Downloaded Files");
		cell.detailTextLabel.text = [self downloadsDetailText];
		UIView *indicator = TGStorageDisclosureIndicator();
		if (indicator)
			cell.accessoryView = indicator;
		else
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		return cell;
	}

	if (indexPath.section == TGStorageSectionPolicy) {
		if (indexPath.row == 0) {
			cell.textLabel.text = TGL(@"Cache.KeepMedia", @"Keep Media");
			cell.detailTextLabel.text = TGStorageTTLName([self policyTTLSeconds]);
		} else {
			cell.textLabel.text = TGL(@"Cache.MaximumCacheSize", @"Maximum cache size");
			cell.detailTextLabel.text = TGStorageSizeName([self policyMaxBytes]);
		}
		if (self.working) {
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			cell.textLabel.textColor = [[TGTheme shared] groupedDisabledColour];
		} else {
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		}
		return cell;
	}

	NSArray *labels = @[ [NSString stringWithFormat:TGL(@"Storage.ClearKind", @"Clear %@"),
			[TGL(@"Cache.Photos", @"Photos") lowercaseString]],
		[NSString stringWithFormat:TGL(@"Storage.ClearKind", @"Clear %@"),
			[TGL(@"Cache.Videos", @"Videos") lowercaseString]],
		[NSString stringWithFormat:TGL(@"Storage.ClearKind", @"Clear %@"),
			TGL(@"Cache.OtherFiles", @"other files")],
		TGL(@"Privacy.DeleteDrafts", @"Clear All Drafts") ];
	cell.textLabel.text = [labels objectAtIndex:indexPath.row];
	cell.textLabel.textColor = [[TGTheme shared] groupedDestructiveColour];
	if (indexPath.row == 3) {
		cell.selectionStyle = self.clearingDrafts
			? UITableViewCellSelectionStyleNone
			: UITableViewCellSelectionStyleBlue;
		if (self.clearingDrafts)
			cell.accessoryView = [self spinner];
		return cell;
	}
	if ([self canClear]) {
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	} else {
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.textLabel.textColor = [[TGTheme shared] groupedDisabledColour];
		if (self.working)
			cell.accessoryView = [self spinner];
	}
	return cell;
}

- (UIView *)spinner {
	UIActivityIndicatorViewStyle style = UIActivityIndicatorViewStyleGray;
	UIActivityIndicatorView *view = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:style];
	[view startAnimating];
	return view;
}

- (UITableViewCell *)clearEverythingCellInTable:(UITableView *)tableView {
	static NSString *reuse = @"TGStorageClearAllCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:reuse];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.backgroundColor = [UIColor clearColor];
		cell.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
		cell.backgroundView.backgroundColor = [UIColor clearColor];
		cell.contentView.backgroundColor = [UIColor clearColor];
		cell.opaque = NO;

		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.tag = 772;
		button.frame = CGRectMake(9, 0, cell.contentView.bounds.size.width - 18, 45);
		button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		button.adjustsImageWhenDisabled = NO;
		button.exclusiveTouch = YES;
		button.titleLabel.font = [UIFont boldSystemFontOfSize:17];
		button.titleLabel.shadowOffset = CGSizeMake(0, -1);
		[button setTitle:TGL(@"StorageManagement.ClearAll", @"Clear everything") forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
		UIColor *shadow = [UIColor colorWithRed:0xa1 / 255.0f green:0x06 / 255.0f blue:0x03 / 255.0f alpha:0.5f];
		[button setTitleShadowColor:shadow forState:UIControlStateNormal];
		[button setTitleShadowColor:shadow forState:UIControlStateHighlighted];

		UIImage *raw = [UIImage imageNamed:@"MenuRedButton.png"];
		UIImage *rawHighlighted = [UIImage imageNamed:@"MenuRedButton_Highlighted.png"];
		if (raw) {
			int rawLeftCap = (int)(raw.size.width / 2);
			int rawTopCap = (int)(raw.size.height / 2);
			UIImage *stretched =
				[raw stretchableImageWithLeftCapWidth:rawLeftCap topCapHeight:rawTopCap];
			[button setBackgroundImage:stretched forState:UIControlStateNormal];
		}
		if (rawHighlighted) {
			int leftCap = (int)(rawHighlighted.size.width / 2);
			int topCap = (int)(rawHighlighted.size.height / 2);
			UIImage *stretchedHighlighted =
				[rawHighlighted stretchableImageWithLeftCapWidth:leftCap topCapHeight:topCap];
			[button setBackgroundImage:stretchedHighlighted forState:UIControlStateHighlighted];
		}
		if (!raw)
			button.backgroundColor = [[TGTheme shared] groupedDestructiveColour];
		[button addTarget:self action:@selector(clearEverythingPressed)
			forControlEvents:UIControlEventTouchUpInside];
		[cell.contentView addSubview:button];
	}
	UIButton *button = (UIButton *)[cell.contentView viewWithTag:772];
	button.frame = CGRectMake(9, 0, cell.contentView.bounds.size.width - 18, 45);
	button.enabled = [self canClear];
	button.alpha = [self canClear] ? 1.0f : 0.7f;
	return cell;
}

- (void)clearEverythingPressed {
	if (![self canClear])
		return;
	self.pendingAction = TGStorageActionEverything;
	self.pendingKinds = nil;
	[self presentConfirmationWithTitle:TGL(@"StorageManagement.ClearAll", @"Clear everything")];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (indexPath.section == TGStorageSectionDownloads) {
		[self openDownloads];
		return;
	}

	if (indexPath.section == TGStorageSectionPolicy) {
		if (self.working)
			return;
		[self presentPolicySheetForRow:indexPath.row];
		return;
	}

	if (indexPath.section == TGStorageSectionChats) {
		if (!self.detailLoaded || indexPath.row >= (NSInteger)self.chatRows.count)
			return;
		[self openChatDetail:[self.chatRows objectAtIndex:indexPath.row]];
		return;
	}

	if (indexPath.section == TGStorageSectionClear && indexPath.row == 3) {
		if (self.clearingDrafts)
			return;
		self.pendingAction = TGStorageActionClearDrafts;
		self.pendingKinds = nil;
		[self presentConfirmationWithTitle:TGL(@"Privacy.DeleteDrafts", @"Clear All Drafts")];
		return;
	}

	if (![self canClear])
		return;

	if (indexPath.section == TGStorageSectionTypes) {
		if (!self.detailLoaded || !self.typeRows.count)
			return;
		NSDictionary *row = [self.typeRows objectAtIndex:indexPath.row];
		[self confirmClearKinds:@[ [row objectForKey:@"kind"] ]
						  title:[NSString stringWithFormat:TGL(@"Storage.ClearKind", @"Clear %@"),
									[[row objectForKey:@"title"] lowercaseString]]];
		return;
	}

	if (indexPath.section != TGStorageSectionClear)
		return;

	NSArray *kinds = nil;
	switch (indexPath.row) {
		case 0:
			kinds = @[ @"fileTypePhoto" ];
			break;
		case 1:
			kinds = @[ @"fileTypeVideo", @"fileTypeVideoNote", @"fileTypeAnimation" ];
			break;
		case 2:
			kinds = @[ @"fileTypeDocument", @"fileTypeAudio", @"fileTypeVoiceNote" ];
			break;
		default:
			kinds = @[];
			break;
	}
	[self confirmClearKinds:kinds title:[[tableView cellForRowAtIndexPath:indexPath] textLabel].text];
}

- (void)confirmClearKinds:(NSArray *)kinds title:(NSString *)title {
	if (![self canClear])
		return;
	self.pendingAction = TGStorageActionKinds;
	self.pendingKinds = kinds ? kinds : @[];
	[self presentConfirmationWithTitle:title];
}

- (void)openChatDetail:(NSDictionary *)row {
	TGStorageChatViewController *controller = [[TGStorageChatViewController alloc] init];
	controller.chatId = (int64_t)[[row objectForKey:@"chatId"] longLongValue];
	controller.chatTitle = [row objectForKey:@"title"];
	controller.bytes = [[row objectForKey:@"size"] longLongValue];
	__weak typeof(self) weakSelf = self;
	controller.didChange = ^{
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf refresh];
		[strongSelf refreshDetail];
	};
	[self.navigationController pushViewController:controller animated:YES];
}

- (void)presentPolicySheetForRow:(NSInteger)row {
	NSString *sheetTitle = row == 0 ? TGL(@"Cache.KeepMedia", @"Keep Media")
									: TGL(@"Cache.MaximumCacheSize", @"Maximum cache size");
	UIActionSheet *sheet = [[UIActionSheet alloc]
				 initWithTitle:sheetTitle
					  delegate:self
			 cancelButtonTitle:nil
		destructiveButtonTitle:nil
			 otherButtonTitles:nil];
	sheet.tag = row == 0 ? TGStorageSheetTTL : TGStorageSheetSize;
	if (row == 0) {
		for (NSInteger i = 0; i < 4; i++)
			[sheet addButtonWithTitle:TGStorageTTLName(kStorageTTLValues[i])];
	} else {
		for (NSInteger i = 0; i < 4; i++)
			[sheet addButtonWithTitle:TGStorageSizeName(TGStorageSizeValueAtIndex(i))];
	}
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	if (self.tabBarController.tabBar)
		[sheet showFromTabBar:self.tabBarController.tabBar];
	else {
		UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:TGStorageSectionPolicy]];
		[sheet tg_showFromRect:cell.frame inView:self.tableView];
	}
}

- (void)applyPolicy {
	if (![self beginWork])
		return;

	__weak typeof(self) weakSelf = self;
	[TGStorageService applyCachePolicyMaxBytes:[self policyMaxBytes]
									ttlSeconds:[self policyTTLSeconds]
							   excludedChatIds:[self policyExcludedChatIds]
									completion:^(long long freed) {
										typeof(self) strongSelf = weakSelf;
										if (!strongSelf || !strongSelf.working)
											return;
										[strongSelf finishWorkWithFreed:freed];
									}];
}

- (void)presentConfirmationWithTitle:(NSString *)title {
	self.pendingTitle = title.length ? title : TGL(@"WebSearch.RecentSectionClear", @"Clear");

	UIActionSheet *sheet = [[UIActionSheet alloc]
				 initWithTitle:nil
					  delegate:self
			 cancelButtonTitle:nil
		destructiveButtonTitle:nil
			 otherButtonTitles:nil];
	sheet.tag = TGStorageSheetConfirm;
	[sheet addButtonWithTitle:self.pendingTitle];
	sheet.destructiveButtonIndex = 0;
	[sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.cancelButtonIndex = 1;
	if (self.tabBarController.tabBar)
		[sheet showFromTabBar:self.tabBarController.tabBar];
	else
		[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet
	clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (actionSheet.tag == TGStorageSheetTTL || actionSheet.tag == TGStorageSheetSize) {
		if (buttonIndex < 0 || buttonIndex > 3)
			return;
		NSInteger ttl = [self policyTTLSeconds];
		long long maxBytes = [self policyMaxBytes];
		if (actionSheet.tag == TGStorageSheetTTL)
			ttl = kStorageTTLValues[buttonIndex];
		else
			maxBytes = TGStorageSizeValueAtIndex(buttonIndex);
		[TGStorageService setCachePolicyMaxBytes:maxBytes
									  ttlSeconds:ttl
								 excludedChatIds:[self policyExcludedChatIds]];
		[self.tableView reloadData];
		if (ttl > 0 || maxBytes > 0)
			[self applyPolicy];
		return;
	}

	if (buttonIndex != actionSheet.destructiveButtonIndex)
		return;
	TGStorageAction action = self.pendingAction;
	NSArray *kinds = self.pendingKinds;
	self.pendingKinds = nil;
	self.pendingTitle = nil;

	if (action == TGStorageActionEverything)
		[self clearEverything];
	else if (action == TGStorageActionClearDrafts)
		[self clearAllDrafts];
	else
		[self clearKinds:kinds];
}

- (void)clearAllDrafts {
	if (self.clearingDrafts)
		return;
	self.clearingDrafts = YES;
	[self.tableView reloadData];

	__weak typeof(self) weakSelf = self;
	[TGStorageService clearAllDraftMessagesExcludingSecretChats:NO completion:^(BOOL ok) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.clearingDrafts = NO;
		[strongSelf.tableView reloadData];

		UIAlertView *alert = [[UIAlertView alloc]
				initWithTitle:TGL(@"Cache.Title", @"Storage")
					  message:ok
						  ? TGL(@"Privacy.DeleteDrafts.DraftsDeleted", @"All drafts cleared.")
						  : TGL(@"Toast.CouldNotClearDrafts", @"Could not clear drafts.")
					 delegate:nil
			cancelButtonTitle:TGL(@"Common.OK", @"OK")
			otherButtonTitles:nil];
		[alert show];
	}];
}

- (BOOL)beginWork {
	if (self.working)
		return NO;
	self.working = YES;
	[self.tableView reloadData];
	[self performSelector:@selector(clearTimedOut) withObject:nil afterDelay:60.0];
	return YES;
}

- (void)finishWorkWithFreed:(long long)freed {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(clearTimedOut)
											   object:nil];
	self.working = NO;
	[self refresh];
	[self refreshDetail];
	[self.tableView reloadData];

	NSString *message = freed > 0
		? [NSString stringWithFormat:TGL(@"ClearCache.Success", @"%@ freed on your %@!"),
			TGMediaFormatBytes(freed), [TGDevice modelName] ?: @"device"]
		: TGL(@"Storage.NothingToClear", @"There was nothing to clear.");
	UIAlertView *alert = [[UIAlertView alloc]
			initWithTitle:TGL(@"Cache.Title", @"Storage")
				  message:message
				 delegate:nil
		cancelButtonTitle:TGL(@"Common.OK", @"OK")
		otherButtonTitles:nil];
	[alert show];
}

- (void)clearKinds:(NSArray *)kinds {
	if (!kinds || ![self beginWork])
		return;

	BOOL wantsLocal = [kinds containsObject:TGStorageLocalThumbnailKind];
	NSMutableArray *remote = [NSMutableArray arrayWithArray:kinds];
	[remote removeObject:TGStorageLocalThumbnailKind];

	__weak typeof(self) weakSelf = self;
	void (^clearRemote)(long long) = ^(long long localFreed) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || !strongSelf.working)
			return;
		if (!remote.count) {
			[strongSelf finishWorkWithFreed:localFreed];
			return;
		}
		[TGStorageService clearCacheCategories:remote completion:^(long long freed) {
			typeof(self) innerSelf = weakSelf;
			if (!innerSelf || !innerSelf.working)
				return;
			[innerSelf finishWorkWithFreed:freed + localFreed];
		}];
	};

	if (wantsLocal) {
		[self purgeLocalThumbnailsWithCompletion:clearRemote];
		return;
	}
	clearRemote(0);
}

- (void)clearEverything {
	if (![self beginWork])
		return;

	__weak typeof(self) weakSelf = self;
	[self purgeLocalThumbnailsWithCompletion:^(long long localFreed) {
		[TGStorageService clearAllCacheWithCompletion:^(long long freed) {
			typeof(self) strongSelf = weakSelf;
			if (!strongSelf || !strongSelf.working)
				return;
			[strongSelf finishWorkWithFreed:freed + localFreed];
		}];
	}];
}

- (void)clearTimedOut {
	if (!self.working)
		return;
	self.working = NO;
	[self.tableView reloadData];
}

@end
