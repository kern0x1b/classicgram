#import <Foundation/Foundation.h>

@class TGProfileDetailItem;

@interface TGProfileDetailPresenter : NSObject

@property (nonatomic, readonly) NSInteger numberOfItems;

- (TGProfileDetailItem *)itemAtRow:(NSInteger)row;

- (void)updateDetails:(NSArray *)details isSongPlaying:(BOOL)isSongPlaying;

@end
