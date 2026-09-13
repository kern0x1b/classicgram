#import "TGNewContactViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGTheme.h"

@implementation TGNewContactViewController (TableView)

- (NSInteger)numberOfOptionRows {
	NSInteger rows = 0;
	if (![self hasKnownPeer] && !self.editingExistingContact)
		rows++;
	if (self.offersShareException)
		rows++;
	return rows;
}

- (BOOL)showsQRSection {
	return ![self hasKnownPeer] && !self.editingExistingContact && !self.resolvedUserId;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return [self hasKnownPeer] ? 1 : (NSInteger)self.phoneEntries.count;
	if (section == 1)
		return [self numberOfOptionRows];
	return [self showsQRSection] ? 1 : 0;
}

- (CGFloat)captionInsetForWidth:(CGFloat)width {
	return TGNewContactGroupedInset(width) + kNewContactCaptionInset;
}

- (CGFloat)captionWidthForTableWidth:(CGFloat)width {
	return MAX(40.0f, width - [self captionInsetForWidth:width] * 2.0f);
}

- (CGFloat)phoneFooterHeight {
	NSString *text = [self phoneStatusText];
	if (!text.length)
		return 0.0f;
	CGFloat width = [self headerWidth];
	CGSize size = [text sizeWithFont:[UIFont systemFontOfSize:14]
				   constrainedToSize:CGSizeMake([self captionWidthForTableWidth:width], 1000)
					   lineBreakMode:NSLineBreakByWordWrapping];
	return size.height + kNewContactCaptionPadding * 2.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.section == 2 ? 43.0f : 44.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	if ([self tableView:tableView numberOfRowsInSection:section] == 0)
		return 0.0f;
	return 10.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	if (section == 0)
		return [self phoneFooterHeight];
	if ([self tableView:tableView numberOfRowsInSection:section] == 0)
		return 0.0f;
	return 1.0f + ([UIScreen mainScreen].scale > 1.0f ? 0.5f : 1.0f);
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
	view.backgroundColor = [UIColor clearColor];
	return view;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	if (section != 0) {
		UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
		view.backgroundColor = [UIColor clearColor];
		return view;
	}
	if (!self.phoneFooterView) {
		self.phoneFooterView = [[UIView alloc] initWithFrame:CGRectZero];
		self.phoneFooterView.backgroundColor = [UIColor clearColor];
		self.phoneFooterLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		self.phoneFooterLabel.autoresizingMask =
			UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.phoneFooterLabel.backgroundColor = [UIColor clearColor];
		self.phoneFooterLabel.font = [UIFont systemFontOfSize:14];
		self.phoneFooterLabel.textAlignment = NSTextAlignmentCenter;
		self.phoneFooterLabel.numberOfLines = 0;
		self.phoneFooterLabel.lineBreakMode = NSLineBreakByWordWrapping;
		self.phoneFooterLabel.textColor = TGNewContactColour(0x697487, 1.0f);
		self.phoneFooterLabel.shadowColor = TGNewContactColour(0xdae0e8, 1.0f);
		self.phoneFooterLabel.shadowOffset = CGSizeMake(0, 1);
		[self.phoneFooterView addSubview:self.phoneFooterLabel];
	}
	self.phoneFooterLabel.text = [self phoneStatusText] ?: @"";
	CGFloat width = [self headerWidth];
	CGFloat height = [self phoneFooterHeight];
	self.phoneFooterView.frame = CGRectMake(0, 0, width, height);
	self.phoneFooterLabel.frame = CGRectMake([self captionInsetForWidth:width],
		kNewContactCaptionPadding,
		[self captionWidthForTableWidth:width],
		MAX(0.0f, height - kNewContactCaptionPadding * 2.0f));
	return self.phoneFooterView;
}

- (UITableViewCell *)optionCellForRow:(NSInteger)row {
	static NSString *reuse = @"TGNewContactOption";
	UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:reuse];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:16];

	BOOL syncRow = ![self hasKnownPeer] && !self.editingExistingContact && row == 0;
	UISwitch *toggle = [[UISwitch alloc] init];
	if (syncRow) {
		cell.textLabel.text = TGL(@"AddContact.SyncToPhone", @"Sync Contact to Phone");
		toggle.on = self.syncToPhone;
		[toggle addTarget:self action:@selector(syncToPhoneToggled:)
			forControlEvents:UIControlEventValueChanged];
	} else {
		cell.textLabel.text = TGL(@"Conversation.ShareMyPhoneNumber", @"Share My Phone Number");
		toggle.on = self.sharePhoneNumber;
		[toggle addTarget:self action:@selector(sharePhoneToggled:)
			forControlEvents:UIControlEventValueChanged];
	}
	cell.accessoryView = toggle;
	return cell;
}

- (void)syncToPhoneToggled:(UISwitch *)toggle {
	self.syncToPhone = toggle.on;
}

- (void)sharePhoneToggled:(UISwitch *)toggle {
	self.sharePhoneNumber = toggle.on;
}

- (UITableViewCell *)knownPeerPhoneCell {
	static NSString *reuse = @"TGNewContactKnownPhone";
	TGNewContactPhoneCell *cell = [self.tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGNewContactPhoneCell alloc] initWithReuseIdentifier:reuse];
	cell.labelView.text = TGL(@"ContactInfo.PhoneLabelMobile", @"mobile");
	cell.field = nil;
	cell.lastInGroup = YES;
	[cell setShowsRemoveControl:NO];
	cell.textLabel.text = nil;
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	if (!cell.staticValueLabel) {
		cell.staticValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		cell.staticValueLabel.backgroundColor = [UIColor clearColor];
		cell.staticValueLabel.font = [UIFont boldSystemFontOfSize:15];
		cell.staticValueLabel.textColor = [UIColor blackColor];
		cell.staticValueLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[cell.contentView addSubview:cell.staticValueLabel];
	}
	NSString *phone = self.prefillPhone.length
		? ([self.prefillPhone hasPrefix:@"+"] ? self.prefillPhone
											  : [@"+" stringByAppendingString:self.prefillPhone])
		: TGL(@"ContactInfo.PhoneNumberHidden", @"Hidden");
	cell.staticValueLabel.textColor = self.prefillPhone.length
		? [UIColor blackColor]
		: [[TGTheme shared] secondaryTextColour];
	cell.staticValueLabel.text = phone;
	[cell setNeedsLayout];
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	UIButton *qr = (UIButton *)[cell.contentView viewWithTag:0x51525254];
	if (qr) {
		CGRect frame = qr.frame;
		frame.origin.x = 0.0f;
		frame.size.width = MAX(1.0f, cell.contentView.bounds.size.width);
		qr.frame = frame;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 1)
		return [self optionCellForRow:indexPath.row];

	if (indexPath.section == 0 && [self hasKnownPeer])
		return [self knownPeerPhoneCell];

	if (indexPath.section == 0) {
		static NSString *reuse = @"TGNewContactPhone";
		TGNewContactPhoneCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
		if (!cell)
			cell = [[TGNewContactPhoneCell alloc] initWithReuseIdentifier:reuse];
		NSMutableDictionary *entry = [self.phoneEntries objectAtIndex:(NSUInteger)indexPath.row];
		cell.labelView.text = [entry objectForKey:@"label"];
		cell.field = [entry objectForKey:@"field"];
		cell.lastInGroup = (indexPath.row == (NSInteger)self.phoneEntries.count - 1);
		[cell setShowsRemoveControl:[self rowCarriesNumber:indexPath]];
		[cell.removeButton removeTarget:self action:NULL
					   forControlEvents:UIControlEventTouchUpInside];
		[cell.removeButton addTarget:self action:@selector(removePhoneRowPressed:)
					forControlEvents:UIControlEventTouchUpInside];
		[[TGTheme shared] styleCell:cell];
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		[cell setNeedsLayout];
		[cell layoutIfNeeded];
		return cell;
	}

	static NSString *reuse = @"TGQRRow";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];
		cell.backgroundColor = [UIColor clearColor];
		cell.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;

		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.tag = 0x51525254;
		UIImage *plate = TGNewContactStretchedImage(@"GroupedActionButton.png");
		UIImage *platePressed = TGNewContactStretchedImage(@"GroupedActionButton_Highlighted.png");
		if (plate)
			[button setBackgroundImage:plate forState:UIControlStateNormal];
		if (platePressed)
			[button setBackgroundImage:platePressed forState:UIControlStateHighlighted];
		button.titleLabel.font = [UIFont boldSystemFontOfSize:14];
		button.titleLabel.shadowOffset = CGSizeMake(0, 1);
		[button setTitleColor:TGNewContactColour(0x4a6587, 1.0f) forState:UIControlStateNormal];
		[button setTitleShadowColor:TGNewContactColour(0xffffff, 0.45f) forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
		[button setTitleShadowColor:[UIColor clearColor] forState:UIControlStateHighlighted];
		button.exclusiveTouch = YES;
		button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[button setTitle:TGL(@"AddContact.AddQR", @"Add via QR Code") forState:UIControlStateNormal];
		[button addTarget:self action:@selector(qrTapped) forControlEvents:UIControlEventTouchUpInside];
		[cell.contentView addSubview:button];
	}
	UIButton *button = (UIButton *)[cell.contentView viewWithTag:0x51525254];
	UIImage *plate = [UIImage imageNamed:@"GroupedActionButton.png"];
	CGFloat buttonHeight = plate ? plate.size.height : 43.0f;
	CGFloat width = tableView.bounds.size.width - TGNewContactGroupedInset(tableView.bounds.size.width) * 2.0f;
	button.frame = CGRectMake(0, 0, MAX(1.0f, width), buttonHeight);
	if (!plate)
		button.backgroundColor = [UIColor whiteColor];
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return [self rowCarriesNumber:indexPath];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
	return [self rowCarriesNumber:indexPath];
}

- (void)removePhoneRowPressed:(UIButton *)button {
	UIView *view = button;
	while (view && ![view isKindOfClass:[TGNewContactPhoneCell class]])
		view = view.superview;
	if (!view)
		return;
	NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)view];
	if (!indexPath)
		return;
	[self tableView:self.tableView commitEditingStyle:UITableViewCellEditingStyleDelete
		 forRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete || indexPath.section != 0)
		return;
	NSMutableDictionary *entry = [self.phoneEntries objectAtIndex:(NSUInteger)indexPath.row];
	UITextField *field = [entry objectForKey:@"field"];
	field.delegate = nil;
	[field removeFromSuperview];
	[self.phoneEntries removeObjectAtIndex:(NSUInteger)indexPath.row];
	[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
					 withRowAnimation:UITableViewRowAnimationFade];
	if (!self.phoneEntries.count) {
		[self.phoneEntries addObject:[self makePhoneEntry]];
		[tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]]
						 withRowAnimation:UITableViewRowAnimationFade];
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		[tableView reloadData];
	});
	[self schedulePhoneLookup];
	[self updateDoneEnabled];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == 0 && ![self hasKnownPeer])
		[self presentLabelPickerForRow:indexPath.row];
}

@end
