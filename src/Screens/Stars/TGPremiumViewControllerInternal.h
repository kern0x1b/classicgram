#import <UIKit/UIKit.h>
#import "TGPremiumViewController.h"

enum {
	TGPremiumSectionAccount = 0,
	TGPremiumSectionLimits,
	TGPremiumSectionFeatures,
	TGPremiumSectionBoosts,
	TGPremiumSectionGiftCode,
	TGPremiumSectionCount
};

extern NSString *TGPremiumDateText(id value);

@interface TGPremiumViewController ()
@property (nonatomic, strong) NSDictionary *subscription;
@property (nonatomic, strong) NSDictionary *options;
@property (nonatomic, strong) NSArray *limits;
@property (nonatomic, strong) NSArray *features;
@property (nonatomic, strong) NSArray *slots;
@property (nonatomic, assign) BOOL subscriptionLoaded;
@property (nonatomic, assign) BOOL optionsLoaded;
@property (nonatomic, assign) BOOL slotsLoaded;
@property (nonatomic, assign) NSInteger trialRemaining;
@property (nonatomic, assign) NSInteger trialWeekly;
@property (nonatomic, assign) NSTimeInterval trialCooldownUntil;
@property (nonatomic, assign) BOOL trialKnown;
@property (nonatomic, strong) id trialObserverToken;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerStatusLabel;
@property (nonatomic, strong) UIImageView *headerBadgeView;
@property (nonatomic, assign) BOOL stickerShown;

- (void)reloadTapped;
@end

@interface TGPremiumViewController (Header)

- (void)buildHeader;
- (void)refreshHeader;

@end

@interface TGPremiumViewController (Loading)

- (void)load;
- (void)loadTranscriptionTrial;
- (void)applyTranscriptionTrialState;
- (BOOL)showsTranscriptionRow;
- (NSString *)transcriptionTrialText;

@end

@interface TGPremiumViewController (Shape)

- (NSString *)commentForSection:(NSInteger)section;
- (BOOL)isCommentRow:(NSIndexPath *)indexPath;
- (UIFont *)commentFont;

@end

@interface TGPremiumViewController (Cells)

- (BOOL)featureIsSupported:(NSDictionary *)feature;

@end
