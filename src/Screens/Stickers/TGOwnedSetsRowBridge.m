#import "TGOwnedSetsRowBridge.h"
#import "TGOwnedSetsPresenter.h"
#import "TGOwnedSetsCellBase.h"
#import "TGOwnedSetsCellCatalogue.h"

static NSSet<NSNumber *> *TGOwnedSetsMigratedRowKinds(void) {
	static NSSet<NSNumber *> *migrated = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		migrated = [NSSet set];
	});
	return migrated;
}

BOOL TGOwnedSetsRowKindIsMigrated(TGOwnedSetsRowKind kind) {
	return [TGOwnedSetsMigratedRowKinds() containsObject:@(kind)];
}

@implementation TGOwnedSetsRowBridge

- (instancetype)initWithPresenter:(TGOwnedSetsPresenter *)presenter {
	self = [super init];
	if (!self)
		return nil;

	_presenter = presenter;
	return self;
}

- (UITableViewCell *)cellForItem:(TGOwnedSetsItem *)item
					  atIndexPath:(NSIndexPath *)indexPath
						  inTable:(UITableView *)table {
	if (!item)
		return nil;

	TGOwnedSetsCellBase *cell = (TGOwnedSetsCellBase *)
		[table dequeueReusableCellWithIdentifier:item.reuseIdentifier];
	if (!cell)
		cell = [[item.cellClass alloc]
			  initWithStyle:[TGOwnedSetsCellCatalogue cellStyleForKind:item.kind]
			reuseIdentifier:item.reuseIdentifier];

	[cell applyItem:item];

	if (item.thumbnailKey.length &&
		[self.delegate respondsToSelector:@selector(ownedSetsRowBridge:thumbnailImageForKey:)]) {
		UIImage *resolved = [self.delegate ownedSetsRowBridge:self thumbnailImageForKey:item.thumbnailKey];
		if (resolved) {
			cell.imageView.image = resolved;
		} else if ([self.delegate respondsToSelector:
					@selector(ownedSetsRowBridge:loadThumbnailForKey:fileId:completion:)]) {
			__weak typeof(table) weakTable = table;
			__weak typeof(self) weakSelf = self;
			NSIndexPath *capturedIndexPath = indexPath;
			NSString *capturedThumbnailKey = [item.thumbnailKey copy];
			[self.delegate ownedSetsRowBridge:self
						   loadThumbnailForKey:item.thumbnailKey
										fileId:item.thumbnailFileId
									completion:^(UIImage *image) {
										if (!image || !capturedIndexPath)
											return;
										typeof(self) strongSelf = weakSelf;
										if (!strongSelf)
											return;
										TGOwnedSetsItem *currentItem = (capturedIndexPath.section == 0)
											? [strongSelf.presenter createRowItem]
											: [strongSelf.presenter itemAtSetRow:capturedIndexPath.row];
										if (!currentItem || ![currentItem.thumbnailKey isEqualToString:capturedThumbnailKey])
											return;
										UITableViewCell *fresh = [weakTable cellForRowAtIndexPath:capturedIndexPath];
										if (!fresh)
											return;
										fresh.imageView.image = image;
										[fresh setNeedsLayout];
									}];
		}
	}

	return cell;
}

- (BOOL)ownsCreateRow {
	return TGOwnedSetsRowKindIsMigrated(TGOwnedSetsRowKindCreate);
}

- (BOOL)ownsSetRowAtIndex:(NSInteger)row {
	if (row < 0 || row >= self.presenter.numberOfSets)
		return NO;
	return TGOwnedSetsRowKindIsMigrated(TGOwnedSetsRowKindSet);
}

- (UITableViewCell *)cellForCreateRowInTable:(UITableView *)table {
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
	return [self cellForItem:[self.presenter createRowItem] atIndexPath:indexPath inTable:table];
}

- (UITableViewCell *)cellForSetRow:(NSInteger)row inTable:(UITableView *)table {
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:1];
	return [self cellForItem:[self.presenter itemAtSetRow:row] atIndexPath:indexPath inTable:table];
}

@end
