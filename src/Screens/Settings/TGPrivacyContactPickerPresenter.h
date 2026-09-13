#import <Foundation/Foundation.h>

@class TGPrivacyContactPickerItem;

@interface TGPrivacyContactPickerPresenter : NSObject

@property (nonatomic, readonly) NSInteger numberOfItems;

- (TGPrivacyContactPickerItem *)itemAtRow:(NSInteger)row;
- (void)updateWithContacts:(NSArray *)contacts chosen:(NSArray *)chosen;

@end
