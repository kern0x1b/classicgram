#import "TGPrivacyContactPickerRowBridge.h"
#import "TGPrivacyContactPickerPresenter.h"
#import "TGPrivacyContactPickerRowCell.h"

static NSSet<NSNumber *> *TGPrivacyContactPickerMigratedRowKinds(void) {
	static NSSet<NSNumber *> *migrated = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		migrated = [NSSet setWithObject:@(TGPrivacyContactPickerRowKindContact)];
	});
	return migrated;
}

BOOL TGPrivacyContactPickerRowKindIsMigrated(TGPrivacyContactPickerRowKind kind) {
	return [TGPrivacyContactPickerMigratedRowKinds() containsObject:@(kind)];
}

@implementation TGPrivacyContactPickerRowBridge

- (instancetype)initWithPresenter:(TGPrivacyContactPickerPresenter *)presenter {
	self = [super init];
	if (!self)
		return nil;

	_presenter = presenter;
	return self;
}

- (BOOL)ownsRowAtIndex:(NSInteger)row {
	TGPrivacyContactPickerItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return NO;
	return TGPrivacyContactPickerRowKindIsMigrated(item.kind);
}

- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table {
	TGPrivacyContactPickerItem *item = [self.presenter itemAtRow:row];
	if (!item)
		return nil;

	TGPrivacyContactPickerRowCell *cell = (TGPrivacyContactPickerRowCell *)[table dequeueReusableCellWithIdentifier:item.reuseIdentifier];
	if (!cell)
		cell = [[item.cellClass alloc] initWithStyle:UITableViewCellStyleDefault
									 reuseIdentifier:item.reuseIdentifier];

	[cell applyItem:item];
	return cell;
}

@end
