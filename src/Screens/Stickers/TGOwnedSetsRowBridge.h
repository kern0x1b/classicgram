#import <UIKit/UIKit.h>
#import "TGOwnedSetsItem.h"

@class TGOwnedSetsPresenter;
@class TGOwnedSetsRowBridge;

BOOL TGOwnedSetsRowKindIsMigrated(TGOwnedSetsRowKind kind);

@protocol TGOwnedSetsRowBridgeDelegate <NSObject>

@optional

- (UIImage *)ownedSetsRowBridge:(TGOwnedSetsRowBridge *)bridge thumbnailImageForKey:(NSString *)thumbnailKey;

- (void)ownedSetsRowBridge:(TGOwnedSetsRowBridge *)bridge
	loadThumbnailForKey:(NSString *)thumbnailKey
				 fileId:(int64_t)fileId
			 completion:(void (^)(UIImage *image))completion;

@end

@interface TGOwnedSetsRowBridge : NSObject

- (instancetype)initWithPresenter:(TGOwnedSetsPresenter *)presenter NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) TGOwnedSetsPresenter *presenter;
@property (nonatomic, weak) id<TGOwnedSetsRowBridgeDelegate> delegate;

- (BOOL)ownsCreateRow;
- (BOOL)ownsSetRowAtIndex:(NSInteger)row;
- (UITableViewCell *)cellForCreateRowInTable:(UITableView *)table;
- (UITableViewCell *)cellForSetRow:(NSInteger)row inTable:(UITableView *)table;

@end
