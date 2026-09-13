#import "TGStarsViewController.h"
#import "TGFriendlyError.h"
#import "TGStarsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGClient+Payments.h"
#import "TGUpgradedGiftInfoViewController.h"
#import "TGForwardPicker.h"
#import "TGAlertView.h"
#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGIcons.h"

@interface TGStarsGiftCollectionTab : NSObject
@property (nonatomic, assign) int32_t collectionId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) TGStarsListViewController *holder;
@property (nonatomic, assign) CGPoint scrollOffset;
@property (nonatomic, assign) BOOL hasScrollOffset;
@end

@implementation TGStarsGiftCollectionTab
@end

@interface TGStarsGiftCollectionTabsController : NSObject
@property (nonatomic, weak) TGStarsViewController *owner;
@property (nonatomic, weak) TGStarsListViewController *host;
@property (nonatomic, strong) NSArray *tabs;
@property (nonatomic, assign) NSInteger activeIndex;
@property (nonatomic, assign) int64_t userId;
@property (nonatomic, copy) NSString *emptyText;
@property (nonatomic, copy) NSString *ownCollectionComment;
@property (nonatomic, copy) NSString *allGiftsComment;
- (void)selectTabAtIndex:(NSInteger)index;
@end

@implementation TGStarsGiftCollectionTabsController

- (void)selectTabAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.tabs.count)
		return;
	TGStarsListViewController *host = self.host;
	TGStarsViewController *owner = self.owner;
	if (!host || !owner)
		return;

	if (self.activeIndex >= 0 && self.activeIndex < (NSInteger)self.tabs.count) {
		TGStarsGiftCollectionTab *previous = self.tabs[(NSUInteger)self.activeIndex];
		previous.scrollOffset = host.tableView.contentOffset;
		previous.hasScrollOffset = YES;
		previous.holder.mirrorTarget = nil;
	}

	self.activeIndex = index;
	TGStarsGiftCollectionTab *tab = self.tabs[(NSUInteger)index];
	host.title = tab.title;
	host.comment = (tab.collectionId == 0) ? self.allGiftsComment : self.ownCollectionComment;
	BOOL isFirstLoad = (tab.holder == nil);
	if (isFirstLoad) {
		TGStarsListViewController *holder = [[TGStarsListViewController alloc] initWithTitle:tab.title];
		holder.loading = YES;
		holder.emptyText = (tab.collectionId == 0)
			? self.emptyText
			: TGL(@"PeerInfo.Gifts.EmptyCollection.Title", @"Organize Your Gifts");
		tab.holder = holder;
	}

	TGStarsListViewController *holder = tab.holder;
	holder.mirrorTarget = host;
	host.rows = holder.rows;
	host.loading = holder.loading;
	host.moreAvailable = holder.moreAvailable;
	host.loadMoreBlock = holder.loadMoreBlock;
	host.emptyText = holder.emptyText.length ? holder.emptyText : self.emptyText;
	[host.tableView reloadData];
	if (tab.hasScrollOffset)
		[host.tableView setContentOffset:tab.scrollOffset animated:NO];
	else
		[host.tableView setContentOffset:CGPointMake(0, -host.tableView.contentInset.top) animated:NO];

	if (isFirstLoad) {
		int64_t userId = self.userId;
		[owner loadCollectionGiftsPage:@"" collectionId:tab.collectionId userId:userId
								   list:holder
							 allGiftIds:[NSMutableArray array]];
	}
}

@end

@implementation TGStarsViewController (GiftCollections)

- (void)pushGiftsOfCollection:(int32_t)collectionId name:(NSString *)name all:(NSArray *)allCollections {
	int64_t userId = [[TGClient shared].me[@"id"] longLongValue];
	NSString *resolvedName = name.length ? name : TGL(@"Stars.Collection", @"Collection");

	NSMutableArray *tabs = [NSMutableArray array];
	TGStarsGiftCollectionTab *allTab = [[TGStarsGiftCollectionTab alloc] init];
	allTab.collectionId = 0;
	allTab.title = TGL(@"ChatList.Tabs.All", @"All");
	[tabs addObject:allTab];

	NSInteger initialIndex = 0;
	for (NSDictionary *collection in allCollections) {
		if (![collection isKindOfClass:[NSDictionary class]])
			continue;
		int32_t otherId = (int32_t)[collection[@"id"] intValue];
		NSString *otherName = collection[@"name"];
		if (![otherName isKindOfClass:[NSString class]] || !otherName.length)
			otherName = TGL(@"Stars.Collection", @"Collection");
		TGStarsGiftCollectionTab *tab = [[TGStarsGiftCollectionTab alloc] init];
		tab.collectionId = otherId;
		tab.title = otherName;
		if (otherId == collectionId)
			initialIndex = (NSInteger)tabs.count;
		[tabs addObject:tab];
	}

	TGStarsListViewController *host = [[TGStarsListViewController alloc] initWithTitle:resolvedName];
	NSMutableArray *tabTitles = [NSMutableArray array];
	for (TGStarsGiftCollectionTab *tab in tabs)
		[tabTitles addObject:tab.title];
	host.tabTitles = tabTitles;
	host.selectedTabIndex = initialIndex;
	host.loading = YES;
	host.emptyText = TGL(@"Stars.NoGiftsYet", @"No Gifts Yet");

	TGStarsGiftCollectionTabsController *tabsController = [[TGStarsGiftCollectionTabsController alloc] init];
	tabsController.owner = self;
	tabsController.host = host;
	tabsController.tabs = tabs;
	tabsController.activeIndex = -1;
	tabsController.userId = userId;
	tabsController.emptyText = TGL(@"Stars.NoGiftsYet", @"No Gifts Yet");
	tabsController.ownCollectionComment = TGL(@"Stars.GiftCollections.TapAGiftToOpenItOrTakeItOut", @"Tap a gift to open it or take it out of this collection.");
	tabsController.allGiftsComment = TGL(@"Stars.GiftCollections.TapAGiftToOpenIt", @"Tap a gift to open it.");

	host.onTabSelected = ^(NSInteger index) {
		[tabsController selectTabAtIndex:index];
	};

	[self.navigationController pushViewController:host animated:YES];
	[tabsController selectTabAtIndex:initialIndex];
}

- (void)loadCollectionGiftsPage:(NSString *)offset
				   collectionId:(int32_t)collectionId
						 userId:(int64_t)userId
						   list:(TGStarsListViewController *)list
					 allGiftIds:(NSMutableArray *)allGiftIds {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsListViewController *weakList = list;
	[[TGClient shared] receivedGiftsForUser:userId
							   collectionId:collectionId
									 offset:offset
									  limit:kStarsGiftPageSize
								 completion:^(NSArray *gifts, NSString *nextOffset, NSInteger total) {
									 (void)total;
									 typeof(self) strongSelf = weakSelf;
									 TGStarsListViewController *strongList = weakList;
									 if (!strongSelf || !strongList)
										 return;
									 if ([gifts isKindOfClass:[NSArray class]]) {
										 for (NSDictionary *gift in gifts) {
											 if (![gift isKindOfClass:[NSDictionary class]])
												 continue;
											 NSString *giftId = gift[@"giftId"];
											 if (![giftId isKindOfClass:[NSString class]] || !giftId.length)
												 continue;
											 [allGiftIds addObject:giftId];
										 }
										 for (NSDictionary *gift in gifts) {
											 if (![gift isKindOfClass:[NSDictionary class]])
												 continue;
											 NSString *giftId = gift[@"giftId"];
											 if (![giftId isKindOfClass:[NSString class]] || !giftId.length)
												 continue;
											 NSString *title = gift[@"title"];
											 if (![title isKindOfClass:[NSString class]] || !title.length)
												 title = TGL(@"Gift.View.Title", @"Gift");
											 NSString *detail = nil;
											 if ([gift[@"isUnique"] boolValue]) {
												 NSString *currency = gift[@"valueCurrency"];
												 long long value = [gift[@"valueAmount"] longLongValue];
												 if ([currency isKindOfClass:[NSString class]] && currency.length && value > 0)
													 detail = [NSString stringWithFormat:@"%.2f %@", value / 100.0, currency];
											 } else {
												 long long stars = [gift[@"starCount"] longLongValue];
												 if (stars > 0)
													 detail = [strongSelf starsText:stars signed:NO];
											 }
											 NSDictionary *row = TGStarsRow(title, detail, nil, ^{
												 typeof(self) innerSelf = weakSelf;
												 if (!innerSelf)
													 return;
												 if (collectionId == 0) {
													 [innerSelf pushGiftDetails:gift];
													 return;
												 }
												 [innerSelf showSheetForCollectionGift:gift
																		  collectionId:collectionId
																			allGiftIds:allGiftIds];
											 });
											 [strongList appendRow:row];
										 }
									 }
									 BOOL hasMore = [nextOffset isKindOfClass:[NSString class]] && nextOffset.length > 0;
									 if (hasMore) {
										 strongList.loadMoreBlock = ^{
											 typeof(self) innerSelf = weakSelf;
											 TGStarsListViewController *innerList = weakList;
											 if (innerSelf && innerList)
												 [innerSelf loadCollectionGiftsPage:nextOffset collectionId:collectionId
																			 userId:userId
																			   list:innerList
																		 allGiftIds:allGiftIds];
										 };
									 }
									 [strongList finishLoadingWithMore:hasMore];
								 }];
}

- (void)showSheetForCollectionGift:(NSDictionary *)gift
					  collectionId:(int32_t)collectionId
						allGiftIds:(NSArray *)allGiftIds {
	NSString *giftId = gift[@"giftId"];
	NSString *title = gift[@"title"];
	BOOL canMoveToTop = allGiftIds.count > 1 && ![allGiftIds.firstObject isEqual:giftId];
	TGActionSheetAction *detailsAction =
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Stars.GiftDetails", @"Gift Details") action:@"details"];
	NSMutableArray *actions = [NSMutableArray arrayWithObject:detailsAction];
	if (canMoveToTop) {
		TGActionSheetAction *moveToTopAction =
			[[TGActionSheetAction alloc] initWithTitle:TGL(@"PeerInfo.Gifts.Context.Pin", @"Pin") action:@"moveToTop"];
		[actions addObject:moveToTopAction];
	}
	TGActionSheetAction *removeAction =
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"PeerInfo.Gifts.Context.RemoveFromCollection", @"Remove From Collection")
											action:@"remove"
											  type:TGActionSheetActionTypeDestructive];
	[actions addObject:removeAction];
	TGActionSheetAction *cancelAction =
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel")
											action:@"cancel"
											  type:TGActionSheetActionTypeCancel];
	[actions addObject:cancelAction];
	__weak typeof(self) weakSelf = self;
	self.currentActionSheet = [[TGActionSheet alloc]
		initWithTitle:[title isKindOfClass:[NSString class]] ? title : nil
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  typeof(self) strongSelf = weakSelf;
			  if (!strongSelf)
				  return;
			  strongSelf.currentActionSheet = nil;
			  if ([action isEqualToString:@"details"]) {
				  [strongSelf pushGiftDetails:gift];
				  return;
			  }
			  if ([action isEqualToString:@"moveToTop"]) {
				  NSMutableArray *reordered = [NSMutableArray arrayWithObject:giftId];
				  for (NSString *otherId in allGiftIds) {
					  if (![otherId isEqual:giftId])
						  [reordered addObject:otherId];
				  }
				  TGClient *client = [TGClient shared];
				  [client reorderGifts:reordered
						  inCollection:collectionId
							completion:^(NSDictionary *collection) {
								typeof(self) innerSelf = weakSelf;
								if (innerSelf)
									[innerSelf finishSimpleAction:[collection isKindOfClass:[NSDictionary class]]
														 failure:TGL(@"Stars.TheGiftsCouldNotBeReordered", @"The gifts could not be reordered.")];
							}];
				  return;
			  }
			  if (![action isEqualToString:@"remove"])
				  return;
			  TGClient *client = [TGClient shared];
			  [client removeGiftIds:@[ giftId ]
					 fromCollection:collectionId
						 completion:^(NSDictionary *collection) {
							 typeof(self) innerSelf = weakSelf;
							 if (innerSelf)
								 [innerSelf finishSimpleAction:[collection isKindOfClass:[NSDictionary class]]
													  failure:TGL(@"Stars.TheGiftCouldNotBeRemoved", @"The gift could not be removed.")];
						 }];
		  }
			   target:self];
	UIView *presentationHost = [self sheetHostView];
	[self.currentActionSheet tg_showFromRect:CGRectMake(CGRectGetMidX(presentationHost.bounds), CGRectGetMidY(presentationHost.bounds), 1, 1)
									   inView:presentationHost];
}

- (void)pushGiftPickerForCollection:(int32_t)collectionId {
	TGStarsListViewController *list =
		[[TGStarsListViewController alloc] initWithTitle:TGL(@"PeerInfo.Gifts.AddGifts", @"Add a Gift")];
	list.loading = YES;
	list.emptyText = TGL(@"Stars.GiftCollections.NoGifts", @"No Gifts");
	list.comment = TGL(@"Stars.GiftCollections.TapAGiftToAddIt", @"Tap a gift to add it to this collection.");
	[self.navigationController pushViewController:list animated:YES];
	[self loadGiftPickerPage:@"" collectionId:collectionId list:list];
}

- (void)loadGiftPickerPage:(NSString *)offset
			   collectionId:(int32_t)collectionId
					   list:(TGStarsListViewController *)list {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsListViewController *weakList = list;
	int64_t userId = [[TGClient shared].me[@"id"] longLongValue];
	[[TGClient shared] receivedGiftsForUser:userId
							   collectionId:0
									 offset:offset
									  limit:kStarsGiftPageSize
								 completion:^(NSArray *gifts, NSString *nextOffset, NSInteger total) {
									 (void)total;
									 typeof(self) strongSelf = weakSelf;
									 TGStarsListViewController *strongList = weakList;
									 if (!strongSelf || !strongList)
										 return;
									 if ([gifts isKindOfClass:[NSArray class]]) {
										 for (NSDictionary *gift in gifts) {
											 if (![gift isKindOfClass:[NSDictionary class]])
												 continue;
											 NSString *giftId = gift[@"giftId"];
											 if (![giftId isKindOfClass:[NSString class]] || !giftId.length)
												 continue;
											 NSString *title = gift[@"title"];
											 if (![title isKindOfClass:[NSString class]] || !title.length)
												 title = TGL(@"Gift.View.Title", @"Gift");
											 NSDictionary *row = TGStarsRow(title, nil, nil, ^{
												 typeof(self) innerSelf = weakSelf;
												 if (!innerSelf)
													 return;
												 TGClient *client = [TGClient shared];
												 [client addGiftIds:@[ giftId ]
													   toCollection:collectionId
														 completion:^(NSDictionary *collection) {
															 typeof(self) doneSelf = weakSelf;
															 if (doneSelf)
																 [doneSelf finishSimpleAction:[collection isKindOfClass:[NSDictionary class]]
																					  failure:TGL(@"Stars.TheGiftCouldNotBeAdded", @"The gift could not be added.")];
														 }];
											 });
											 [strongList appendRow:row];
										 }
									 }
									 BOOL hasMore = [nextOffset isKindOfClass:[NSString class]] && nextOffset.length > 0;
									 if (hasMore) {
										 strongList.loadMoreBlock = ^{
											 typeof(self) innerSelf = weakSelf;
											 TGStarsListViewController *innerList = weakList;
											 if (innerSelf && innerList)
												 [innerSelf loadGiftPickerPage:nextOffset collectionId:collectionId list:innerList];
										 };
									 }
									 [strongList finishLoadingWithMore:hasMore];
								 }];
}

- (NSDictionary *)collectionOpenActionForId:(int32_t)collectionId name:(NSString *)name all:(NSArray *)allCollections {
	__weak typeof(self) weakSelf = self;
	return TGStarsAction(TGL(@"Stars.GiftCollections.OpenCollection", @"Gifts in Collection"), nil, NO, ^{
		typeof(self) strongSelf = weakSelf;
		if (strongSelf)
			[strongSelf pushGiftsOfCollection:collectionId name:name all:allCollections];
	});
}

- (NSDictionary *)collectionAddGiftActionForId:(int32_t)collectionId {
	__weak typeof(self) weakSelf = self;
	return TGStarsAction(TGL(@"PeerInfo.Gifts.AddGifts", @"Add a Gift"), nil, NO, ^{
		typeof(self) strongSelf = weakSelf;
		if (strongSelf)
			[strongSelf pushGiftPickerForCollection:collectionId];
	});
}

- (NSDictionary *)collectionRenameActionForId:(int32_t)collectionId
								   controller:(TGStarsDetailViewController *)controller {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsDetailViewController *weakController = controller;
	return TGStarsAction(TGL(@"PeerInfo.Gifts.RenameCollection", @"Rename"), nil, NO, ^{
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf promptWithTitle:TGL(@"PeerInfo.Gifts.RenameCollection", @"Rename")
							message:TGL(@"Stories.EditAlbum.Text", @"Choose a new name.")
						placeholder:TGL(@"Contacts.SortByName", @"Name")
							numeric:NO
						  maxLength:kStarsGiftCollectionNameMaxLength
						actionTitle:TGL(@"Conversation.LinkDialogSave", @"Save")
							handler:^(NSString *text) {
								typeof(self) innerSelf = weakSelf;
								TGStarsDetailViewController *strongController = weakController;
								if (!innerSelf || !strongController)
									return;
								strongController.busy = YES;
								[strongController.tableView reloadData];
								TGClient *client = [TGClient shared];
								[client renameGiftCollection:collectionId
														  to:text
												  completion:^(NSDictionary *renamed) {
													  typeof(self) doneSelf = weakSelf;
													  if (doneSelf)
														  [doneSelf finishAction:strongController
																		 success:[renamed isKindOfClass:[NSDictionary class]]
																		 failure:TGL(@"Stars.TheCollectionCouldNotBeRenamed", @"The collection could not be renamed.")];
												  }];
							}];
	});
}

- (NSDictionary *)collectionMoveToTopActionForId:(int32_t)collectionId
											 all:(NSArray *)allCollections {
	__weak typeof(self) weakSelf = self;
	return TGStarsAction(TGL(@"Stars.GiftCollections.MoveToTop", @"Move to Top"), nil, NO, ^{
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSMutableArray *ids = [NSMutableArray arrayWithObject:@(collectionId)];
		for (NSDictionary *other in allCollections) {
			int32_t otherId = (int32_t)[other[@"id"] intValue];
			if (otherId != collectionId)
				[ids addObject:@(otherId)];
		}
		[[TGClient shared] reorderGiftCollections:ids completion:^(BOOL ok, NSString *error) {
			typeof(self) innerSelf = weakSelf;
			if (!innerSelf)
				return;
			[innerSelf finishSimpleAction:ok
								   failure:TGFriendlyErrorText(error, TGL(@"Stars.GiftCollections.ReorderFailed", @"The collection could not be moved."))];
		}];
	});
}

- (NSDictionary *)collectionDeleteActionForId:(int32_t)collectionId {
	__weak typeof(self) weakSelf = self;
	return TGStarsAction(TGL(@"PeerInfo.Gifts.DeleteCollection", @"Delete Collection"), nil, YES, ^{
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf confirmWithTitle:TGL(@"PeerInfo.Gifts.DeleteCollection", @"Delete Collection")
							 message:TGL(@"PeerInfo.Gifts.RemoveCollectionConfirmation", @"The collection is removed. The gifts in it are kept.")
							  action:TGL(@"PeerInfo.Gifts.RemoveCollectionAction", @"Remove")
							   block:^{
								   typeof(self) innerSelf = weakSelf;
								   if (!innerSelf)
									   return;
								   [[TGClient shared] deleteGiftCollection:collectionId completion:^(BOOL ok, NSString *error) {
									   typeof(self) doneSelf = weakSelf;
									   if (!doneSelf)
										   return;
									   [doneSelf finishSimpleAction:ok
															 failure:TGFriendlyErrorText(error, TGL(@"Stars.GiftCollections.DeleteFailed", @"The collection could not be removed."))];
								   }];
							   }];
	});
}

- (void)pushCollection:(NSDictionary *)collection all:(NSArray *)allCollections {
	int32_t collectionId = (int32_t)[collection[@"id"] intValue];
	NSString *name = collection[@"name"];
	if (![name isKindOfClass:[NSString class]] || !name.length)
		name = TGL(@"Stars.Collection", @"Collection");
	NSInteger count = [collection[@"giftCount"] integerValue];

	NSArray *pairs = @[ @[ TGL(@"PeerInfo.PaneGifts", @"Gifts"), [NSString stringWithFormat:@"%d", (int)count] ] ];
	TGStarsDetailViewController *controller =
		[[TGStarsDetailViewController alloc] initWithTitle:name pairs:pairs comment:nil];
	NSMutableArray *actions = [NSMutableArray array];

	[actions addObject:[self collectionOpenActionForId:collectionId name:name all:allCollections]];
	[actions addObject:[self collectionAddGiftActionForId:collectionId]];
	[actions addObject:[self collectionRenameActionForId:collectionId controller:controller]];

	if (allCollections.count > 1 &&
		![[allCollections objectAtIndex:0] isEqual:collection]) {
		NSDictionary *moveToTopAction = [self collectionMoveToTopActionForId:collectionId all:allCollections];
		[actions addObject:moveToTopAction];
	}

	[actions addObject:[self collectionDeleteActionForId:collectionId]];

	controller.actions = actions;
	[self.navigationController pushViewController:controller animated:YES];
}

- (void)showCollectionLimitReachedAlert {
	TGAlertView *alert = [[TGAlertView alloc]
		initWithTitle:TGL(@"PeerInfo.Gifts.CollectionLimitReached.Title", @"Limit Reached")
			  message:TGL(@"PeerInfo.Gifts.CollectionLimitReached.Text", @"Please remove one of the existing collections to add a new one.")
	  cancelButtonTitle:TGL(@"Common.OK", @"OK")
			okButtonTitle:nil
		  completionBlock:nil];
	[alert show];
}

- (NSDictionary *)newCollectionRowForList:(TGStarsListViewController *)list count:(NSInteger)count {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsListViewController *weakList = list;
	return TGStarsRow(TGL(@"PeerInfo.Gifts.Context.NewCollection", @"New Collection"), nil, nil, ^{
		typeof(self) strongSelf = weakSelf;
		TGStarsListViewController *innerList = weakList;
		if (!strongSelf || !innerList)
			return;
		[[TGClient shared] giftCollectionCountMaxWithCompletion:^(NSInteger countMax) {
			typeof(self) limitSelf = weakSelf;
			TGStarsListViewController *limitList = weakList;
			if (!limitSelf || !limitList)
				return;
			if (count >= countMax) {
				[limitSelf showCollectionLimitReachedAlert];
				return;
			}
			[limitSelf promptWithTitle:TGL(@"PeerInfo.Gifts.Context.NewCollection", @"New Collection")
							   message:TGL(@"PeerInfo.Gifts.CreateCollection.Text", @"Name this collection.")
						   placeholder:TGL(@"Contacts.SortByName", @"Name")
							   numeric:NO
							 maxLength:kStarsGiftCollectionNameMaxLength
						   actionTitle:TGL(@"Common.Create", @"Create")
							   handler:^(NSString *text) {
								   typeof(self) innerSelf = weakSelf;
								   TGStarsListViewController *createList = weakList;
								   if (!innerSelf || !createList)
									   return;
								   createList.loading = YES;
								   [createList.tableView reloadData];
								   TGClient *client = [TGClient shared];
								   [client createGiftCollectionNamed:text
															 giftIds:@[]
														  completion:^(NSDictionary *created) {
															  typeof(self) doneSelf = weakSelf;
															  TGStarsListViewController *doneList = weakList;
															  if (!doneSelf || !doneList)
																  return;
															  if (![created isKindOfClass:[NSDictionary class]]) {
																  [doneList finishLoadingWithMore:NO];
																  [doneSelf showMessage:TGL(@"Stars.TheCollectionCouldNotBeCreated", @"The collection could not be created.")];
																  return;
															  }
															  [doneSelf fillCollectionsList:doneList];
														  }];
							   }];
		}];
	});
}

- (void)fillCollectionsList:(TGStarsListViewController *)list {
	__weak typeof(self) weakSelf = self;
	__weak TGStarsListViewController *weakList = list;
	[[TGClient shared] giftCollectionsWithCompletion:^(NSArray *collections) {
		typeof(self) strongSelf = weakSelf;
		TGStarsListViewController *strongList = weakList;
		if (!strongSelf || !strongList)
			return;
		[strongList.rows removeAllObjects];
		NSArray *all = [collections isKindOfClass:[NSArray class]] ? collections : @[];
		for (NSDictionary *collection in all) {
			if (![collection isKindOfClass:[NSDictionary class]])
				continue;
			NSString *name = collection[@"name"];
			if (![name isKindOfClass:[NSString class]] || !name.length)
				name = TGL(@"Stars.Collection", @"Collection");
			NSString *giftCount = [NSString stringWithFormat:@"%d", (int)[collection[@"giftCount"] integerValue]];
			NSDictionary *row = TGStarsRow(name, nil, giftCount, ^{
				typeof(self) innerSelf = weakSelf;
				if (innerSelf)
					[innerSelf pushCollection:collection all:all];
			});
			[strongList appendRow:row];
		}
		[strongList appendRow:[strongSelf newCollectionRowForList:strongList count:all.count]];
		[strongList finishLoadingWithMore:NO];
	}];
}

- (void)pushGiftCollections {
	TGStarsListViewController *list =
		[[TGStarsListViewController alloc] initWithTitle:TGL(@"Stars.MyCollections", @"My Collections")];
	list.loading = YES;
	list.emptyText = TGL(@"Stars.GiftCollections.NoCollections", @"No Collections");
	list.comment = TGL(@"Stars.GiftCollections.CollectionsGroupTheGiftsShownOnYourProfile", @"Collections group the gifts shown on your profile.");
	[self.navigationController pushViewController:list animated:YES];
	[self fillCollectionsList:list];
}

- (void)pushCollectionPickerForGift:(NSString *)giftId {
	TGStarsListViewController *list =
		[[TGStarsListViewController alloc] initWithTitle:TGL(@"PeerInfo.Gifts.Context.AddToCollection", @"Add to Collection")];
	list.loading = YES;
	list.emptyText = TGL(@"Stars.GiftCollections.NoCollections", @"No Collections");
	__weak typeof(self) weakSelf = self;
	__weak TGStarsListViewController *weakList = list;
	[self.navigationController pushViewController:list animated:YES];
	[[TGClient shared] giftCollectionsWithCompletion:^(NSArray *collections) {
		typeof(self) strongSelf = weakSelf;
		TGStarsListViewController *strongList = weakList;
		if (!strongSelf || !strongList)
			return;
		if ([collections isKindOfClass:[NSArray class]]) {
			for (NSDictionary *collection in collections) {
				if (![collection isKindOfClass:[NSDictionary class]])
					continue;
				int32_t collectionId = (int32_t)[collection[@"id"] intValue];
				NSString *name = collection[@"name"];
				if (![name isKindOfClass:[NSString class]] || !name.length)
					name = TGL(@"Stars.Collection", @"Collection");
				[strongList appendRow:TGStarsRow(name, nil, nil, ^{
					typeof(self) innerSelf = weakSelf;
					if (!innerSelf)
						return;
					TGClient *client = [TGClient shared];
					[client addGiftIds:@[ giftId ]
						  toCollection:collectionId
							completion:^(NSDictionary *updated) {
								typeof(self) doneSelf = weakSelf;
								if (doneSelf)
									[doneSelf finishSimpleAction:[updated isKindOfClass:[NSDictionary class]]
														 failure:TGL(@"Stars.TheGiftCouldNotBeAdded", @"The gift could not be added.")];
							}];
				})];
			}
		}
		[strongList finishLoadingWithMore:NO];
	}];
}

@end
