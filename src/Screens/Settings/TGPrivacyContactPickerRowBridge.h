#import <UIKit/UIKit.h>
#import "TGPrivacyContactPickerItem.h"

@class TGPrivacyContactPickerPresenter;
@class TGPrivacyContactPickerRowBridge;

BOOL TGPrivacyContactPickerRowKindIsMigrated(TGPrivacyContactPickerRowKind kind);

@interface TGPrivacyContactPickerRowBridge : NSObject

- (instancetype)initWithPresenter:(TGPrivacyContactPickerPresenter *)presenter NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) TGPrivacyContactPickerPresenter *presenter;

- (BOOL)ownsRowAtIndex:(NSInteger)row;
- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table;

@end
