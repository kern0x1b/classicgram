#import "TGInviteLinksViewController.h"
#import "TGInviteLinksViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGInviteLinkService.h"

const NSInteger kInviteRequestPageLimit = 50;

@implementation TGInviteLinksViewController (Loading)

- (void)reload {
	if (self.outstanding > 0)
		return;
	self.requestsGeneration++;
	self.outstanding = 5;
	self.failed = NO;

	__weak typeof(self) weakSelf = self;
	[TGInviteLinkService canManageInviteLinksInChat:self.chatId completion:^(BOOL canManage) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		strongSelf.canManage = canManage;
		[strongSelf updateNewButton];
		[strongSelf stepFinishedWithFailure:NO];
	}];
	[TGInviteLinkService primaryInviteLinkForChat:self.chatId completion:^(NSString *link) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		strongSelf.primaryLink = [link isKindOfClass:[NSString class]] ? link : @"";
		[strongSelf stepFinishedWithFailure:NO];
	}];
	[TGInviteLinkService inviteLinksForChat:self.chatId revoked:NO completion:^(NSArray *links) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		strongSelf.links = [strongSelf secondaryLinksFrom:links];
		[strongSelf stepFinishedWithFailure:links == nil];
	}];
	[TGInviteLinkService inviteLinksForChat:self.chatId revoked:YES completion:^(NSArray *links) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		strongSelf.revokedLinks = links ?: [NSArray array];
		[strongSelf stepFinishedWithFailure:links == nil];
	}];
	self.nextRequestOffset = nil;
	NSInteger requestReloadLimit = MAX((NSInteger)self.requests.count, kInviteRequestPageLimit);
	NSInteger generation = self.requestsGeneration;
	[TGInviteLinkService joinRequestsForChat:self.chatId inviteLink:nil query:nil offsetRequest:nil
									   limit:requestReloadLimit
								  completion:^(NSArray *requests, NSInteger total, NSDictionary *nextOffset) {
									  __strong typeof(weakSelf) strongSelf = weakSelf;
									  if (!strongSelf || strongSelf.requestsGeneration != generation)
										  return;
									  strongSelf.requests = requests ?: [NSArray array];
									  strongSelf.requestTotal = total;
									  strongSelf.nextRequestOffset = requests.count ? nextOffset : nil;
									  [strongSelf stepFinishedWithFailure:requests == nil];
								  }];
}

- (BOOL)canLoadMoreRequests {
	return self.loaded && self.requests.count && self.requestTotal > (NSInteger)self.requests.count;
}

- (void)loadMoreRequests {
	if (self.loadingMoreRequests || self.outstanding > 0 || !self.nextRequestOffset)
		return;
	self.loadingMoreRequests = YES;
	NSDictionary *offset = self.nextRequestOffset;
	NSInteger generation = self.requestsGeneration;

	__weak typeof(self) weakSelf = self;
	[TGInviteLinkService joinRequestsForChat:self.chatId inviteLink:nil query:nil offsetRequest:offset
									   limit:kInviteRequestPageLimit
								  completion:^(NSArray *requests, NSInteger total, NSDictionary *nextOffset) {
									  __strong typeof(weakSelf) strongSelf = weakSelf;
									  if (!strongSelf || strongSelf.requestsGeneration != generation)
										  return;
									  strongSelf.loadingMoreRequests = NO;
									  if (!requests) {
										  [strongSelf failedWithMessage:TGL(@"InviteLink.MoreRequestsCouldNotBeLoaded", @"More requests could not be loaded.")];
										  [strongSelf.tableView reloadData];
										  return;
									  }
									  NSMutableArray *combined = [NSMutableArray arrayWithArray:strongSelf.requests ?: [NSArray array]];
									  [combined addObjectsFromArray:requests];
									  strongSelf.requests = combined;
									  strongSelf.requestTotal = total;
									  strongSelf.nextRequestOffset = requests.count ? nextOffset : nil;
									  [strongSelf rebuildSections];
									  [strongSelf.tableView reloadData];
								  }];
}

- (void)rebuildSections {
	NSMutableArray *sections = [NSMutableArray array];
	[sections addObject:[NSNumber numberWithInteger:kInviteSectionPrimary]];
	if (self.requests.count)
		[sections addObject:[NSNumber numberWithInteger:kInviteSectionRequests]];
	if (self.canManage || self.links.count)
		[sections addObject:[NSNumber numberWithInteger:kInviteSectionLinks]];
	if (self.revokedLinks.count)
		[sections addObject:[NSNumber numberWithInteger:kInviteSectionRevoked]];
	self.sections = sections;
}

@end
