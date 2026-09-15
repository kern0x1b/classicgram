#import "TGStoryAudience.h"
#import "TGTextFieldStyle.h"
#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGStoryPostOptions.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGStoryHelpers.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGStoryContactPicker.h"
#import "TGStoryPeriod.h"

static NSString *TGStoryPeriodTitle(NSInteger seconds) {
	NSInteger hours = 24;
	if (seconds == TGStoryPeriodSixHours)
		hours = 6;
	else if (seconds == TGStoryPeriodTwelveHours)
		hours = 12;
	else if (seconds == TGStoryPeriodTwoDays)
		hours = 48;
	return TGLPlural(@"MessageTimer.Hours", hours, @"%@ hour", @"%@ hours");
}

static NSString *TGStoryPrivacyTitle(NSString *privacy) {
	if ([privacy isEqualToString:@"contacts"])
		return TGL(@"PrivacySettings.LastSeenContacts", @"My Contacts");
	if ([privacy isEqualToString:@"closeFriends"])
		return TGL(@"Story.Privacy.CategoryCloseFriends", @"Close Friends");
	if ([privacy isEqualToString:@"selected"])
		return TGL(@"Story.Privacy.CategorySelectedContacts", @"Selected Contacts");
	return TGL(@"Story.Privacy.CategoryEveryone", @"Everyone");
}

@implementation TGStoryPostOptions {
	UITableView *_tableView;
	UITextField *_captionField;
	NSArray *_sections;
	UIView *_overlay;
	UILabel *_overlayLabel;
	UIProgressView *_overlayProgress;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	self.title = TGL(@"Notification.LockScreenStoryPlaceholder", @"New Story");
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];

	self.navigationItem.leftBarButtonItem =
		[TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Cancel", @"Cancel") bold:NO
									   target:self
									   action:@selector(cancelPressed)];
	self.navigationItem.rightBarButtonItem =
		[TGIcons headerBarButtonItemWithTitle:TGL(@"Stars.Transaction.Reaction.Post", @"Post") bold:NO
									   target:self
									   action:@selector(postPressed)];

	_tableView = [[UITableView alloc] initWithFrame:self.view.bounds
											  style:UITableViewStyleGrouped];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_tableView.dataSource = self;
	_tableView.delegate = self;
	_tableView.backgroundColor = TGGroupedListBackground();
	_tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	_tableView.tableHeaderView = [self previewHeader];
	[self.view addSubview:_tableView];

	[self rebuildSections];
}

- (UIView *)previewHeader {
	CGFloat width = self.view.bounds.size.width;
	CGFloat height = 148.0f;
	CGFloat plateHeight = 124.0f;
	CGFloat plateWidth = floorf(plateHeight * 9.0f / 16.0f);

	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
	header.backgroundColor = [UIColor clearColor];

	UIImageView *thumb = [[UIImageView alloc] initWithFrame:
			CGRectMake(floorf((width - plateWidth) / 2.0f), 12.0f, plateWidth, plateHeight)];
	thumb.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
		UIViewAutoresizingFlexibleRightMargin;
	thumb.backgroundColor = [UIColor blackColor];
	thumb.contentMode = UIViewContentModeScaleAspectFill;
	thumb.clipsToBounds = YES;
	thumb.layer.cornerRadius = 6.0f;
	thumb.image = self.preview;
	[header addSubview:thumb];

	return header;
}

- (void)rebuildSections {
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	[sections addObject:[NSArray arrayWithObject:@"caption"]];
	if (self.chatTitle.length > 0)
		[sections addObject:[NSArray arrayWithObject:@"chat"]];
	if (self.showsPrivacy) {
		NSMutableArray *privacyRows = [NSMutableArray arrayWithObject:@"privacy"];
		if (TGStoryAudienceAllowsExceptions(self.privacy))
			[privacyRows addObject:@"privacyExcept"];
		[sections addObject:[privacyRows copy]];
	}
	[sections addObject:[NSArray arrayWithObject:@"period"]];
	[sections addObject:[NSArray arrayWithObject:@"areas"]];
	[sections addObject:[NSArray arrayWithObject:@"page"]];
	_sections = sections;
	[_tableView reloadData];
}

- (NSString *)kindAt:(NSIndexPath *)indexPath {
	if (indexPath.section >= (NSInteger)_sections.count)
		return @"";
	NSArray *rows = [_sections objectAtIndex:(NSUInteger)indexPath.section];
	if (indexPath.row >= (NSInteger)rows.count)
		return @"";
	return [rows objectAtIndex:(NSUInteger)indexPath.row];
}

#pragma mark - the busy overlay

- (void)buildOverlay {
	_overlay = [[UIView alloc] initWithFrame:self.view.bounds];
	_overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_overlay.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.4f];

	CGFloat plateWidth = MIN(240.0f, self.view.bounds.size.width - 60.0f);
	CGRect plateFrame = CGRectMake(floorf((self.view.bounds.size.width - plateWidth) / 2.0f),
		floorf((self.view.bounds.size.height - 96.0f) / 2.0f),
		plateWidth, 96.0f);
	UIView *plate = [[UIView alloc] initWithFrame:plateFrame];
	plate.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
		UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
		UIViewAutoresizingFlexibleBottomMargin;
	plate.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.75f];
	plate.layer.cornerRadius = 10.0f;
	[_overlay addSubview:plate];

	_overlayLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 18, plateWidth - 24, 20)];
	_overlayLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_overlayLabel.backgroundColor = [UIColor clearColor];
	_overlayLabel.textColor = [UIColor whiteColor];
	_overlayLabel.textAlignment = NSTextAlignmentCenter;
	_overlayLabel.font = [UIFont boldSystemFontOfSize:14];
	_overlayLabel.text = TGL(@"Stories.Uploading0", @"Uploading 0%");
	[plate addSubview:_overlayLabel];

	_overlayProgress = [[UIProgressView alloc] initWithProgressViewStyle:
			UIProgressViewStyleDefault];
	_overlayProgress.frame = CGRectMake(16, 48, plateWidth - 32, 9);
	_overlayProgress.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_overlayProgress.progress = 0.0f;
	[plate addSubview:_overlayProgress];

	UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	spinner.center = CGPointMake(plateWidth / 2.0f, 74.0f);
	spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
		UIViewAutoresizingFlexibleRightMargin;
	[spinner startAnimating];
	[plate addSubview:spinner];

	[self.view addSubview:_overlay];
}

- (void)setBusy:(BOOL)busy {
	[_captionField resignFirstResponder];
	self.navigationItem.leftBarButtonItem.enabled = !busy;
	self.navigationItem.rightBarButtonItem.enabled = !busy;
	_tableView.userInteractionEnabled = !busy;

	if (!busy) {
		_overlay.hidden = YES;
		return;
	}
	if (_overlay == nil)
		[self buildOverlay];
	[self.view bringSubviewToFront:_overlay];
	_overlay.hidden = NO;
	[self setProgress:0.0f];
}

- (void)setProgress:(float)fraction {
	if (_overlay == nil || _overlay.hidden)
		return;
	if (fraction < 0.0f)
		fraction = 0.0f;
	if (fraction > 1.0f)
		fraction = 1.0f;
	_overlayProgress.progress = fraction;
	_overlayLabel.text = fraction >= 1.0f
		? TGL(@"Stories.Posting", @"Posting")
		: [NSString stringWithFormat:TGL(@"Share.UploadProgress", @"Uploading • %d%%"), (int)(fraction * 100.0f)];
}

#pragma mark - actions

- (void)cancelPressed {
	[_captionField resignFirstResponder];
	void (^cancel)(void) = self.onCancel;
	self.onCancel = nil;
	if (cancel != nil)
		cancel();
}

- (void)captionChanged:(UITextField *)field {
	self.caption = field.text ?: @"";
}

- (void)postPressed {
	[_captionField resignFirstResponder];
	if (_captionField != nil)
		self.caption = _captionField.text ?: @"";
	if (self.onPost != nil)
		self.onPost();
}

- (void)changePrivacy {
	NSArray *titles = [NSArray arrayWithObjects:
			TGL(@"Story.Privacy.CategoryEveryone", @"Everyone"),
			TGL(@"PrivacySettings.LastSeenContacts", @"My Contacts"),
			TGL(@"Story.Privacy.CategoryCloseFriends", @"Close Friends"),
			TGL(@"Story.Privacy.CategorySelectedContacts", @"Selected Contacts"), nil];
	NSArray *values = [NSArray arrayWithObjects:
			@"everyone", @"contacts", @"closeFriends", @"selected", nil];

	NSMutableArray *actions = [[NSMutableArray alloc] init];
	for (NSString *title in titles)
		[actions addObject:[[TGActionSheetAction alloc] initWithTitle:title action:title]];
	TGActionSheetAction *cancelAction = [TGActionSheetAction alloc];
	cancelAction = [cancelAction initWithTitle:TGL(@"Common.Cancel", @"Cancel")
										action:@"cancel"
										  type:TGActionSheetActionTypeCancel];
	[actions addObject:cancelAction];

	__weak TGStoryPostOptions *weakSelf = self;
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:TGL(@"Story.Context.Privacy", @"Who Can See")
						 actions:actions
					 actionBlock:^(id target, NSString *action) {
						 (void)target;
						 TGStoryPostOptions *strongSelf = weakSelf;
						 NSInteger index = [titles indexOfObject:action];
						 if (strongSelf == nil || index == NSNotFound)
							 return;
						 NSString *chosen = [values objectAtIndex:index];
						 if (![chosen isEqualToString:@"selected"]) {
							 NSArray *kept = TGStoryAudienceExceptionsAfterChange(strongSelf.privacy,
								 chosen, strongSelf.userIds);
							 strongSelf.privacy = chosen;
							 strongSelf.userIds = kept;
							 [strongSelf rebuildSections];
							 return;
						 }
						 [TGStoryContactPicker presentFrom:strongSelf
													 title:TGL(@"Story.Privacy.CategorySelectedContacts", @"Selected Contacts")
											   preselected:strongSelf.userIds
													picked:^(NSArray *userIds) {
														TGStoryPostOptions *innerSelf = weakSelf;
														if (innerSelf == nil || userIds.count == 0)
															return;
														innerSelf.privacy = @"selected";
														innerSelf.userIds = userIds;
														[innerSelf rebuildSections];
													}];
					 }
						  target:self];
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)changePrivacyExceptions {
	__weak TGStoryPostOptions *weakSelf = self;
	[TGStoryContactPicker presentFrom:self
								title:TGL(@"Story.Privacy.HideFrom", @"Hide From")
						  preselected:self.userIds
							   picked:^(NSArray *userIds) {
								   TGStoryPostOptions *strongSelf = weakSelf;
								   if (strongSelf == nil)
									   return;
								   strongSelf.userIds = userIds.count ? userIds : nil;
								   [strongSelf rebuildSections];
							   }];
}

- (void)changePeriod {
	NSArray *values = [NSArray arrayWithObjects:
			[NSNumber numberWithInteger:TGStoryPeriodSixHours],
		[NSNumber numberWithInteger:TGStoryPeriodTwelveHours],
		[NSNumber numberWithInteger:TGStoryPeriodDay],
		[NSNumber numberWithInteger:TGStoryPeriodTwoDays], nil];

	NSMutableArray *actions = [[NSMutableArray alloc] init];
	NSMutableArray *titles = [[NSMutableArray alloc] init];
	for (NSNumber *value in values) {
		NSString *title = TGStoryPeriodTitle([value integerValue]);
		[titles addObject:title];
		[actions addObject:[[TGActionSheetAction alloc] initWithTitle:title action:title]];
	}
	TGActionSheetAction *cancelAction = [TGActionSheetAction alloc];
	cancelAction = [cancelAction initWithTitle:TGL(@"Common.Cancel", @"Cancel")
										action:@"cancel"
										  type:TGActionSheetActionTypeCancel];
	[actions addObject:cancelAction];

	__weak TGStoryPostOptions *weakSelf = self;
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:TGL(@"Story.Editor.ExpirationText", @"Choose how long the story will be visible.")
						 actions:actions
					 actionBlock:^(id target, NSString *action) {
						 (void)target;
						 TGStoryPostOptions *strongSelf = weakSelf;
						 NSInteger index = [titles indexOfObject:action];
						 if (strongSelf == nil || index == NSNotFound)
							 return;
						 NSInteger chosen = [[values objectAtIndex:index] integerValue];
						 if (chosen != TGStoryPeriodDay && !strongSelf.premium) {
							 TGAlertView *premiumAlert = [TGAlertView alloc];
							 premiumAlert = [premiumAlert initWithTitle:nil
																message:TGL(@"Story.Editor.TooltipPremiumExpiration", @"Other durations need Telegram Premium.")
													  cancelButtonTitle:TGL(@"Common.OK", @"OK")
														  okButtonTitle:nil
														completionBlock:nil];
							 [premiumAlert show];
							 return;
						 }
						 strongSelf.period = chosen;
						 [strongSelf->_tableView reloadData];
					 }
						  target:self];
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)pageSwitchChanged:(UISwitch *)control {
	self.toProfile = control.on;
}

- (void)editAreas {
	if (self.onEditAreas == nil)
		return;
	__weak typeof(self) weakSelf = self;
	self.onEditAreas(^(NSArray *areas) {
		typeof(self) strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		strongSelf.areas = areas;
		[strongSelf->_tableView reloadData];
	});
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	(void)tableView;
	return (NSInteger)_sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	(void)tableView;
	if (section >= (NSInteger)_sections.count)
		return 0;
	return (NSInteger)[[_sections objectAtIndex:(NSUInteger)section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	(void)tableView;
	NSString *kind = [self kindAt:[NSIndexPath indexPathForRow:0 inSection:section]];
	if ([kind isEqualToString:@"page"])
		return TGL(@"Story.KeepsOnPageAfterExpires", @"Keeps the story on your page after it expires.");
	if ([kind isEqualToString:@"period"] && !self.premium)
		return TGL(@"Story.DurationsOtherThan24HoursNeedPremium",
				   @"Durations other than 24 hours need Telegram Premium.");
	if ([kind isEqualToString:@"areas"])
		return TGL(@"Story.Areas.Footer", @"Add a location, a link or a message to your story.");
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	CGFloat measured = [[TGTheme shared] groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	if (!caption.length)
		return nil;
	return [[TGTheme shared] groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *kind = [self kindAt:indexPath];

	if ([kind isEqualToString:@"caption"]) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"caption"];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:@"caption"];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			_captionField = [[UITextField alloc] initWithFrame:
					CGRectInset(cell.contentView.bounds, 12.0f, 0.0f)];
			_captionField.autoresizingMask = UIViewAutoresizingFlexibleWidth |
				UIViewAutoresizingFlexibleHeight;
			_captionField.placeholder = TGL(@"MediaPicker.AddCaption", @"Add a caption");
			_captionField.font = TGTextFieldFont();
			_captionField.returnKeyType = UIReturnKeyDone;
			_captionField.delegate = self;
			_captionField.clearButtonMode = UITextFieldViewModeWhileEditing;
			_captionField.textColor = [[TGTheme shared] primaryTextColour];
			_captionField.text = self.caption ?: @"";
			TGStyleTextField(_captionField);
			[_captionField addTarget:self
							  action:@selector(captionChanged:)
					forControlEvents:UIControlEventEditingChanged];
			[cell.contentView addSubview:_captionField];
		}
		[[TGTheme shared] styleCell:cell];
		return cell;
	}

	if ([kind isEqualToString:@"page"]) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"page"];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:@"page"];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
		cell.textLabel.text = TGL(@"Story.Privacy.KeepOnMyPage", @"Keep on My Page");
		UISwitch *control = [[UISwitch alloc] init];
		control.on = self.toProfile;
		[control addTarget:self
					  action:@selector(pageSwitchChanged:)
			forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = control;
		[[TGTheme shared] styleCell:cell];
		return cell;
	}

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"value"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"value"];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	if ([kind isEqualToString:@"chat"]) {
		cell.textLabel.text = TGL(@"Story.Privacy.PostStoryAs", @"Post As");
		cell.detailTextLabel.text = self.chatTitle ?: @"";
	} else if ([kind isEqualToString:@"privacy"]) {
		cell.textLabel.text = TGL(@"Story.Context.Privacy", @"Who Can See");
		cell.detailTextLabel.text = [self.privacy isEqualToString:@"selected"]
			? TGLPlural(@"Story.ContextPrivacy.LabelOnlySelected", (NSInteger)self.userIds.count, @"%@ Person", @"%@ People")
			: TGStoryPrivacyTitle(self.privacy);
	} else if ([kind isEqualToString:@"privacyExcept"]) {
		cell.textLabel.text = TGL(@"Story.Privacy.HideFrom", @"Hide From");
		cell.detailTextLabel.text = self.userIds.count
			? TGLPlural(@"Story.ContextPrivacy.LabelOnlySelected", (NSInteger)self.userIds.count,
				  @"%@ Person", @"%@ People")
			: TGL(@"GroupInfo.SharedMediaNone", @"None");
	} else if ([kind isEqualToString:@"areas"]) {
		cell.textLabel.text = TGL(@"Story.Areas.Title", @"Add to Your Story");
		cell.detailTextLabel.text = self.areas.count
			? [NSString stringWithFormat:TGL(@"Story.Areas.LuAdded", @"%lu Added"), (unsigned long)self.areas.count]
			: TGL(@"GroupInfo.SharedMediaNone", @"None");
	} else {
		cell.textLabel.text = TGL(@"Stories.ExpiresIn", @"Expires In");
		cell.detailTextLabel.text = TGStoryPeriodTitle(self.period);
	}
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	[[TGTheme shared] styleCell:cell];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSString *kind = [self kindAt:indexPath];
	if ([kind isEqualToString:@"privacy"]) {
		[self changePrivacy];
		return;
	}
	if ([kind isEqualToString:@"privacyExcept"]) {
		[self changePrivacyExceptions];
		return;
	}
	if ([kind isEqualToString:@"period"]) {
		[self changePeriod];
		return;
	}
	if ([kind isEqualToString:@"areas"]) {
		[self editAreas];
		return;
	}
	if ([kind isEqualToString:@"chat"] && self.onChangeChat != nil)
		self.onChangeChat();
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return NO;
}

@end
