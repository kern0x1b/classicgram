#import <Foundation/Foundation.h>

@class TGNewGroupMembersItem;

@interface TGNewGroupMembersPresenter : NSObject

@property (nonatomic, readonly) NSInteger numberOfItems;

- (TGNewGroupMembersItem *)itemAtRow:(NSInteger)row;

- (void)updateWithContacts:(NSArray *)contacts
					titles:(NSArray<NSString *> *)titles
				  selected:(NSArray *)selected;

@end
