#import "TGListBackground.h"
#import "TGClient+Contacts.h"
#import "TGProfileLinkJoinsController.h"
#import "TGProfileViewControllerInternal.h"
#import "TGProfileViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGPopupMenu.h"
#import "TGActionSheet.h"
#import "TGForwardPicker.h"
#import "UIView+SafeTint.h"
#import "TGImageDecode.h"
#import "TGClient+ChatManagement.h"
#import "TGJoinedMemberPageMerge.h"
#import "TGClient+Groups.h"
#import "TGLazyFramework.h"
#import <AVFoundation/AVFoundation.h>
#import <AddressBook/AddressBook.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import "TGEmoji.h"
#import "TGDateLabel.h"
#import "TGDateUtils.h"
#import "TGAlertView.h"

static const NSInteger kJoinsPageLimit = 50;

@implementation TGProfileLinkJoinsController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"InviteLink.JoinedListTitle", @"Joined via Link");
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)reload {
	self.joinsGeneration++;
	self.members = @[];
	self.exhausted = NO;
	self.loadingMore = NO;
	if (!self.chatId || !self.link.length) {
		self.loaded = YES;
		[self.tableView reloadData];
		return;
	}
	[self loadMoreJoins];
}

- (void)loadMoreJoins {
	if (self.loadingMore || self.exhausted || !self.link.length)
		return;
	self.loadingMore = YES;
	NSDictionary *last = [self.members lastObject];
	int64_t afterUserId = [last[@"userId"] isKindOfClass:[NSNumber class]]
		? [last[@"userId"] longLongValue]
		: 0;
	NSInteger afterJoinDate = [last[@"date"] isKindOfClass:[NSNumber class]]
		? [last[@"date"] integerValue]
		: 0;
	NSInteger generation = self.joinsGeneration;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] membersJoinedViaInviteLink:self.link
										   inChat:self.chatId
									  afterUserId:afterUserId
									afterJoinDate:afterJoinDate
											limit:kJoinsPageLimit
									   completion:^(NSArray *members, NSInteger total) {
										   TGProfileLinkJoinsController *strongSelf = weakSelf;
										   if (!strongSelf || strongSelf.joinsGeneration != generation)
											   return;
										   strongSelf.loadingMore = NO;
										   strongSelf.loaded = YES;
										   strongSelf.total = total;
										   NSArray *merged = TGJoinedMembersWithPageAppended(strongSelf.members, members);
										   if (!merged) {
											   strongSelf.exhausted = YES;
											   [strongSelf.tableView reloadData];
											   return;
										   }
										   strongSelf.members = merged;
										   [strongSelf.tableView reloadData];
									   }];
}

- (void)tableView:(UITableView *)tableView
	willDisplayCell:(UITableViewCell *)cell
  forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row < (NSInteger)self.members.count - 1)
		return;
	[self loadMoreJoins];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.members.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return kMemberRowHeight;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (!self.loaded)
		return nil;
	if (!self.members.count)
		return TGL(@"InviteLink.PeopleJoinedShortNone", @"no one joined yet");
	if (self.total > (NSInteger)self.members.count)
		return [NSString stringWithFormat:TGL(@"InviteLink.JoinedShowingLatestFormat", @"%ld joined, showing the latest %ld"),
			(long)self.total, (long)self.members.count];
	return TGLPlural(@"InviteLink.PeopleJoinedShort", self.total, @"%@ joined", @"%@ joined");
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [[TGTheme shared] groupedHeaderHeightForTitle:
			[self tableView:tableView titleForHeaderInSection:section]];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *headerTitle = [self tableView:tableView titleForHeaderInSection:section];
	CGFloat headerWidth = tableView.bounds.size.width;
	return [[TGTheme shared] groupedHeaderViewWithTitle:headerTitle width:headerWidth];
}

- (NSString *)dateTextFor:(id)value {
	if (![value isKindOfClass:[NSNumber class]])
		return @"";
	NSTimeInterval seconds = [value doubleValue];
	if (seconds <= 0)
		return @"";
	return [TGDateUtils stringForFullDateAndTime:(int)seconds];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"join"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"join"];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	id raw = indexPath.row < (NSInteger)self.members.count
		? self.members[indexPath.row]
		: nil;
	NSDictionary *member = [raw isKindOfClass:[NSDictionary class]] ? raw : @{};
	NSString *name = TGProfileText(member[@"name"]) ?: @"";
	cell.textLabel.text = name;
	cell.detailTextLabel.text = [self dateTextFor:member[@"date"]];
	NSString *initial = TGProfileInitial(name);
	int64_t colourId = TGProfileInt64(member[@"userId"]);
	cell.imageView.image = [TGIcons avatarWithInitials:initial size:kMemberAvatarSide colourId:colourId];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	id raw = indexPath.row < (NSInteger)self.members.count
		? self.members[indexPath.row]
		: nil;
	if (![raw isKindOfClass:[NSDictionary class]])
		return;
	int64_t userId = TGProfileInt64([raw objectForKey:@"userId"]);
	if (!userId)
		return;
	NSString *name = TGProfileText([raw objectForKey:@"name"]) ?: @"";
	UINavigationController *navigation = self.navigationController;
	if (!navigation)
		return;
	[[TGClient shared] privateChatWithUser:userId completion:^(int64_t chatId) {
		[TGProfileViewController showProfileForChatId:chatId
											   userId:userId
												title:name
										 inNavigation:navigation];
	}];
}

@end
