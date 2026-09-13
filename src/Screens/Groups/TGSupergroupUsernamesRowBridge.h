#import <UIKit/UIKit.h>
#import "TGSupergroupUsernamesItem.h"

@class TGSupergroupUsernamesPresenter;
@class TGSupergroupUsernamesRowBridge;

typedef NS_ENUM(uint8_t, TGSupergroupUsernamesRowSection) {
	TGSupergroupUsernamesRowSectionActive = 0,
	TGSupergroupUsernamesRowSectionDisabled = 1,
};

BOOL TGSupergroupUsernamesRowKindIsMigrated(TGSupergroupUsernamesRowKind kind);

@interface TGSupergroupUsernamesRowBridge : NSObject

- (instancetype)initWithPresenter:(TGSupergroupUsernamesPresenter *)presenter NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) TGSupergroupUsernamesPresenter *presenter;

- (BOOL)ownsRowAtIndex:(NSInteger)row inSection:(TGSupergroupUsernamesRowSection)section;
- (UITableViewCell *)cellForRow:(NSInteger)row
					  inSection:(TGSupergroupUsernamesRowSection)section
						inTable:(UITableView *)table;

@end
