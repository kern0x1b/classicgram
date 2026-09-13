#import <UIKit/UIKit.h>
#import "TGAccountUsernamesItem.h"

@class TGAccountUsernamesPresenter;
@class TGAccountUsernamesRowBridge;

typedef NS_ENUM(uint8_t, TGAccountUsernamesRowSection) {
	TGAccountUsernamesRowSectionActive = 0,
	TGAccountUsernamesRowSectionDisabled = 1,
};

BOOL TGAccountUsernamesRowKindIsMigrated(TGAccountUsernamesRowKind kind);

@interface TGAccountUsernamesRowBridge : NSObject

- (instancetype)initWithPresenter:(TGAccountUsernamesPresenter *)presenter NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) TGAccountUsernamesPresenter *presenter;

- (BOOL)ownsRowAtIndex:(NSInteger)row inSection:(TGAccountUsernamesRowSection)section;
- (UITableViewCell *)cellForRow:(NSInteger)row
					  inSection:(TGAccountUsernamesRowSection)section
						inTable:(UITableView *)table;

@end
