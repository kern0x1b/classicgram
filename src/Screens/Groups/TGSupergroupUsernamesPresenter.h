#import <Foundation/Foundation.h>

@class TGSupergroupUsernamesItem;

@interface TGSupergroupUsernamesPresenter : NSObject

@property (nonatomic, readonly) NSInteger numberOfActiveItems;
@property (nonatomic, readonly) NSInteger numberOfDisabledItems;

- (TGSupergroupUsernamesItem *)activeItemAtRow:(NSInteger)row;
- (TGSupergroupUsernamesItem *)disabledItemAtRow:(NSInteger)row;

- (void)updateWithActive:(NSArray<NSString *> *)active
				disabled:(NSArray<NSString *> *)disabled
		editableUsername:(NSString *)editableUsername;

@end
