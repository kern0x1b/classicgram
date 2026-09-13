#import "TGInviteLinksViewController.h"
#import "TGStringTruncation.h"
#import "TGInviteLinksViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"

static const NSInteger kInviteHairlineTag = 7811;

static CGFloat TGInviteRetinaPixel(void) {
	return [UIScreen mainScreen].scale > 1.0f ? 0.5f : 0.0f;
}

@implementation TGInviteLinksViewController (TableData)

#pragma mark - table structure

- (NSInteger)kindOfSection:(NSInteger)section {
	if (section < 0 || section >= (NSInteger)self.sections.count)
		return -1;
	return [self.sections[section] integerValue];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSInteger kind = [self kindOfSection:section];
	if (kind == kInviteSectionPrimary)
		return self.primaryLink.length ? 1 : 0;
	if (kind == kInviteSectionRequests)
		return (NSInteger)self.requests.count + ([self canLoadMoreRequests] ? 1 : 0);
	if (kind == kInviteSectionLinks)
		return (NSInteger)self.links.count + (self.canManage ? 1 : 0);
	if (kind == kInviteSectionRevoked)
		return (NSInteger)self.revokedLinks.count + (self.canManage ? 1 : 0);
	return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 44;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self headerTitleForSection:section];
	if (!title)
		return 12;
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	TGTheme *theme = [TGTheme shared];
	return [theme groupedHeaderViewWithTitle:[self headerTitleForSection:section]
									   width:tableView.bounds.size.width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *title = [self footerTitleForSection:section];
	if (!title)
		return 1;
	TGTheme *theme = [TGTheme shared];
	return [theme groupedCommentHeightForText:title
										width:tableView.bounds.size.width];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	TGTheme *theme = [TGTheme shared];
	return [theme groupedCommentViewWithText:[self footerTitleForSection:section]
									   width:tableView.bounds.size.width];
}

#pragma mark - model access

- (NSDictionary *)linkAtIndexPath:(NSIndexPath *)indexPath {
	NSInteger kind = [self kindOfSection:indexPath.section];
	if (kind == kInviteSectionLinks && indexPath.row < (NSInteger)self.links.count)
		return self.links[indexPath.row];
	if (kind == kInviteSectionRevoked && indexPath.row < (NSInteger)self.revokedLinks.count)
		return self.revokedLinks[indexPath.row];
	return nil;
}

- (NSDictionary *)requestAtIndexPath:(NSIndexPath *)indexPath {
	if ([self kindOfSection:indexPath.section] != kInviteSectionRequests)
		return nil;
	if (indexPath.row >= (NSInteger)self.requests.count)
		return nil;
	return self.requests[indexPath.row];
}

- (BOOL)isActionRowAtIndexPath:(NSIndexPath *)indexPath {
	NSInteger kind = [self kindOfSection:indexPath.section];
	if (kind == kInviteSectionLinks)
		return self.canManage && indexPath.row == (NSInteger)self.links.count;
	if (kind == kInviteSectionRevoked)
		return self.canManage && indexPath.row == (NSInteger)self.revokedLinks.count;
	if (kind == kInviteSectionRequests)
		return indexPath.row >= (NSInteger)self.requests.count;
	return NO;
}

#pragma mark - cells

- (UITableViewCell *)actionCellForTable:(UITableView *)tableView
								  title:(NSString *)title
							destructive:(BOOL)destructive {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"action"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"action"];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.text = title;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.textLabel.textColor = destructive ? [[TGTheme shared] groupedDestructiveColour] : [[TGTheme shared] groupedActionColour];
	cell.textLabel.highlightedTextColor = [UIColor whiteColor];
	cell.detailTextLabel.text = @"";
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	UIView *hairline = [cell.contentView viewWithTag:kInviteHairlineTag];
	hairline.hidden = YES;
	return cell;
}

- (UITableViewCell *)actionRowCellForTable:(UITableView *)tableView
									  kind:(NSInteger)kind
								 indexPath:(NSIndexPath *)indexPath {
	if (kind == kInviteSectionLinks)
		return [self actionCellForTable:tableView title:TGL(@"InviteLink.Create", @"Create a New Link")
							destructive:NO];
	if (kind == kInviteSectionRevoked)
		return [self actionCellForTable:tableView title:TGL(@"InviteLink.DeleteAllRevokedLinks", @"Delete All Revoked Links")
							destructive:YES];
	NSInteger remaining = self.requestTotal - (NSInteger)self.requests.count;
	return [self actionCellForTable:tableView
							  title:self.loadingMoreRequests
			? TGL(@"Channel.NotificationLoading", @"Loading…")
			: TGLPlural(@"InviteLink.ShowMoreRequestsWithCount", remaining,
				  @"Show More (%@ left)", @"Show More (%@ left)")
						destructive:NO];
}

- (void)configurePrimaryCell:(UITableViewCell *)cell {
	cell.textLabel.text = [self shortLink:self.primaryLink];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
	cell.textLabel.textColor = [[TGTheme shared] groupedActionColour];
	cell.detailTextLabel.text = @"";
}

- (void)configureRequestCell:(UITableViewCell *)cell
				 atIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *request = [self requestAtIndexPath:indexPath];
	NSString *name = request[@"name"];
	if (![name isKindOfClass:[NSString class]] || !name.length)
		name = TGL(@"Contacts.UnknownName", @"Unknown");
	cell.textLabel.text = name;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.text = [self subtitleForRequest:request];
	if (!self.canManage)
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	NSString *initials = [self initialsForName:name];
	int64_t colourId = [request[@"userId"] longLongValue];
	cell.imageView.image = [TGIcons avatarWithInitials:initials size:30 colourId:colourId];
}

- (void)configureLinkCell:(UITableViewCell *)cell
			  atIndexPath:(NSIndexPath *)indexPath
				  revoked:(BOOL)revoked {
	NSDictionary *link = [self linkAtIndexPath:indexPath];
	cell.textLabel.text = [self titleForLink:link];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.text = [self subtitleForLink:link revoked:revoked];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSInteger kind = [self kindOfSection:indexPath.section];

	if ([self isActionRowAtIndexPath:indexPath])
		return [self actionRowCellForTable:tableView kind:kind indexPath:indexPath];

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"row"];
		UIView *hairline = [[UIView alloc] initWithFrame:CGRectZero];
		hairline.tag = kInviteHairlineTag;
		hairline.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
		[cell.contentView addSubview:hairline];
	}

	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.textLabel.highlightedTextColor = [UIColor whiteColor];
	cell.detailTextLabel.highlightedTextColor = [UIColor whiteColor];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13 + TGInviteRetinaPixel()];
	cell.detailTextLabel.textColor = [[TGTheme shared] groupedDisabledColour];
	cell.imageView.image = nil;

	if (kind == kInviteSectionPrimary)
		[self configurePrimaryCell:cell];
	else if (kind == kInviteSectionRequests)
		[self configureRequestCell:cell atIndexPath:indexPath];
	else
		[self configureLinkCell:cell atIndexPath:indexPath
						revoked:kind == kInviteSectionRevoked];

	UIView *hairline = [cell.contentView viewWithTag:kInviteHairlineTag];
	NSInteger rows = [self tableView:tableView numberOfRowsInSection:indexPath.section];
	hairline.backgroundColor = [[TGTheme shared] separatorColour];
	hairline.hidden = indexPath.row + 1 >= rows;
	return cell;
}

- (NSString *)initialsForName:(NSString *)name {
	NSArray *parts = [name componentsSeparatedByString:@" "];
	NSMutableString *initials = [NSMutableString string];
	for (NSString *part in parts) {
		if (!part.length)
			continue;
		[initials appendString:[TGSafeFirstCharacter(part) uppercaseString]];
		if (initials.length >= 2)
			break;
	}
	return initials.length ? initials : @"?";
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath {
	UIView *hairline = [cell.contentView viewWithTag:kInviteHairlineTag];
	if (!hairline)
		return;
	CGRect bounds = cell.contentView.bounds;
	CGFloat thickness = 1.0f / [UIScreen mainScreen].scale;
	hairline.frame = CGRectMake(10, bounds.size.height - thickness,
		bounds.size.width - 10, thickness);
}

#pragma mark - swipe to revoke

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([self isActionRowAtIndexPath:indexPath] || !self.canManage)
		return NO;
	NSInteger kind = [self kindOfSection:indexPath.section];
	return kind == kInviteSectionLinks || kind == kInviteSectionRevoked;
}

- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	return [self kindOfSection:indexPath.section] == kInviteSectionRevoked
		? TGL(@"InviteLink.ContextDelete", @"Delete")
		: TGL(@"InviteLink.ContextRevoke", @"Revoke");
}

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;
	NSDictionary *link = [self linkAtIndexPath:indexPath];
	if (!link)
		return;
	if ([self kindOfSection:indexPath.section] == kInviteSectionRevoked)
		[self deleteRevokedLink:link];
	else
		[self revokeLink:link];
}

#pragma mark - selection

- (UIView *)sheetHostView {
	if (self.navigationController.view)
		return self.navigationController.view;
	return self.view;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSInteger kind = [self kindOfSection:indexPath.section];

	if ([self isActionRowAtIndexPath:indexPath]) {
		if (kind == kInviteSectionLinks)
			[self createLink];
		else if (kind == kInviteSectionRevoked)
			[self confirmDeleteAllRevoked];
		else
			[self loadMoreRequests];
		return;
	}

	if (kind == kInviteSectionPrimary) {
		[self showSheetForPrimaryLink];
		return;
	}
	if (kind == kInviteSectionRequests) {
		[self showSheetForRequest:[self requestAtIndexPath:indexPath]];
		return;
	}
	[self showSheetForLink:[self linkAtIndexPath:indexPath]
				   revoked:kind == kInviteSectionRevoked];
}

@end
