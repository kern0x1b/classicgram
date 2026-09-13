#import <UIKit/UIKit.h>

typedef void (^TGReactionPickedBlock)(NSString *emoji, BOOL nowChosen);

typedef void (^TGReactionChipTappedBlock)(NSString *emoji, BOOL chosen);

typedef void (^TGReactionOpenProfileBlock)(int64_t chatId, int64_t userId, NSString *name,
	id presentingNavigation);

#pragma mark - the picker strip

@interface TGReactionPickerView : UIView

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int64_t messageId;

@property (nonatomic, copy) TGReactionPickedBlock onReactionPicked;

+ (instancetype)showForMessage:(int64_t)messageId
						inChat:(int64_t)chatId
					  fromRect:(CGRect)rect
						inView:(UIView *)host
						picked:(TGReactionPickedBlock)picked;

+ (void)dismiss;
@end

@interface TGReactionPickerView (Loading)

- (void)loadReactions;
- (void)setEmoji:(NSArray *)emoji reason:(NSString *)reason;

@end

#pragma mark - the chips under a bubble

@interface TGReactionChipsView : UIView

@property (nonatomic, copy) NSArray *chips;

@property (nonatomic, assign) BOOL outgoing;

@property (nonatomic, copy) TGReactionChipTappedBlock onChipTapped;

@property (nonatomic, copy) TGReactionOpenProfileBlock onOpenProfile;

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int64_t messageId;

@property (nonatomic, assign) BOOL allowsReactionToggle;

- (void)setChips:(NSArray *)chips animated:(BOOL)animated;

+ (CGSize)sizeForChips:(NSArray *)chips width:(CGFloat)width;

+ (CGFloat)rowHeight;

@end
