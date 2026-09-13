#import "TGSearchResultsRowBridge.h"
#import "TGSearchResultsPresenter.h"
#import "TGSearchResultCell.h"
#import "TGSearchMessageCell.h"
#import "TGSearchRowMetrics.h"

static NSSet<NSNumber *> *TGSearchMigratedRowKinds(void) {
	static NSSet<NSNumber *> *migrated = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		migrated = [NSSet setWithObjects:@(TGSearchRowKindGeneric), @(TGSearchRowKindMessage), nil];
	});
	return migrated;
}

BOOL TGSearchRowKindIsMigrated(TGSearchRowKind kind) {
	return [TGSearchMigratedRowKinds() containsObject:@(kind)];
}

@implementation TGSearchResultsRowBridge

- (instancetype)initWithPresenter:(TGSearchResultsPresenter *)presenter {
	self = [super init];
	if (!self)
		return nil;

	_presenter = presenter;
	return self;
}

- (BOOL)ownsRowAtIndexPath:(NSIndexPath *)indexPath {
	TGSearchResultItem *item = [self.presenter itemInSection:indexPath.section row:indexPath.row];
	if (!item)
		return NO;
	return TGSearchRowKindIsMigrated(item.kind);
}

- (UITableViewCell *)cellForIndexPath:(NSIndexPath *)indexPath inTable:(UITableView *)table {
	TGSearchResultItem *item = [self.presenter itemInSection:indexPath.section row:indexPath.row];
	if (!item)
		return nil;

	UIImage *avatar = item.avatarPrecomputed;
	id<TGSearchResultsRowBridgeDelegate> owner = self.delegate;
	if (!item.avatarIsPrecomputed &&
		[owner respondsToSelector:@selector(searchResultsRowBridge:avatarForChatId:title:fileId:size:)]) {
		CGFloat size = (item.kind == TGSearchRowKindMessage) ? kSearchMessageAvatar : kSearchAvatar;
		avatar = [owner searchResultsRowBridge:self
							   avatarForChatId:item.avatarColourId
										 title:item.avatarTitle
										fileId:item.avatarFileId
										  size:size];
	}

	if (item.kind == TGSearchRowKindMessage) {
		TGSearchMessageCell *cell = (TGSearchMessageCell *)[table dequeueReusableCellWithIdentifier:item.reuseIdentifier];
		if (!cell)
			cell = [[item.cellClass alloc] initWithStyle:UITableViewCellStyleDefault
										 reuseIdentifier:item.reuseIdentifier];
		[cell applyItem:item avatar:avatar];
		return cell;
	}

	TGSearchResultCell *cell = (TGSearchResultCell *)[table dequeueReusableCellWithIdentifier:item.reuseIdentifier];
	if (!cell)
		cell = [[item.cellClass alloc] initWithStyle:UITableViewCellStyleDefault
									 reuseIdentifier:item.reuseIdentifier];
	[cell applyItem:item avatar:avatar];
	return cell;
}

@end
