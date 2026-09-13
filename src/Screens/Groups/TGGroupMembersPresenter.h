#import <Foundation/Foundation.h>

@class TGGroupMembersItem;

@interface TGGroupMembersPresenter : NSObject

@property (nonatomic, readonly) NSInteger numberOfItems;

- (TGGroupMembersItem *)itemAtRow:(NSInteger)row;
- (void)updateWithMembers:(NSArray *)members;

@end
