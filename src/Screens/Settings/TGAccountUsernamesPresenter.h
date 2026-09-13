#import <Foundation/Foundation.h>

@class TGAccountUsernamesItem;

@interface TGAccountUsernamesPresenter : NSObject

@property (nonatomic, readonly) NSInteger numberOfActiveItems;
@property (nonatomic, readonly) NSInteger numberOfDisabledItems;

- (TGAccountUsernamesItem *)activeItemAtRow:(NSInteger)row;
- (TGAccountUsernamesItem *)disabledItemAtRow:(NSInteger)row;

- (void)updateWithActive:(NSArray<NSString *> *)active
				disabled:(NSArray<NSString *> *)disabled
		editableUsername:(NSString *)editableUsername;

@end
