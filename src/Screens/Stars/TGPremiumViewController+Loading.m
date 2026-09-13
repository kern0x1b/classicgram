#import "TGPremiumViewController.h"
#import "TGDateUtils.h"
#import "TGPremiumViewControllerInternal.h"
#import "TGImageDecode.h"
#import "TGLocalization.h"
#import "TGClient+Files.h"
#import "TGClient+Premium.h"
#import "TGClient+Network.h"

@implementation TGPremiumViewController (Loading)

- (void)load {
	__weak typeof(self) weakSelf = self;

	[[TGClient shared] premiumSubscriptionWithCompletion:^(NSDictionary *info) {
		weakSelf.subscription = [info isKindOfClass:[NSDictionary class]] ? info : nil;
		weakSelf.subscriptionLoaded = YES;
		[weakSelf refreshHeader];
		[weakSelf.tableView reloadData];
	}];

	[[TGClient shared] premiumOptionsWithCompletion:^(NSDictionary *options) {
		weakSelf.options = [options isKindOfClass:[NSDictionary class]] ? options : nil;
		weakSelf.optionsLoaded = YES;
		[weakSelf.tableView reloadData];
	}];

	[[TGClient shared] premiumLimitsWithCompletion:^(NSArray *limits) {
		weakSelf.limits = [limits isKindOfClass:[NSArray class]] ? limits : @[];
		[weakSelf.tableView reloadData];
	}];

	[[TGClient shared] premiumFeaturesWithCompletion:^(NSArray *features) {
		weakSelf.features = [features isKindOfClass:[NSArray class]] ? features : @[];
		[weakSelf.tableView reloadData];
	}];

	if (!self.stickerShown)
		[self loadHeaderSticker];

	[self loadTranscriptionTrial];

	[[TGClient shared] availableBoostSlotsWithCompletion:^(NSArray *slots) {
		weakSelf.slots = [slots isKindOfClass:[NSArray class]] ? slots : @[];
		weakSelf.slotsLoaded = YES;
		[weakSelf.tableView reloadData];
	}];
}

- (void)loadHeaderSticker {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] premiumInfoStickerForMonths:0 completion:^(NSDictionary *sticker) {
		if (![sticker isKindOfClass:[NSDictionary class]])
			return;
		long long fileId = [sticker[@"thumbnailFileId"] longLongValue];
		if (fileId <= 0)
			fileId = [sticker[@"fileId"] longLongValue];
		if (fileId <= 0)
			return;
		[[TGClient shared] downloadFile:fileId completion:^(NSString *path) {
			if (!path.length || !weakSelf)
				return;
			CGFloat badgePixels = weakSelf.headerBadgeView.bounds.size.height * [UIScreen mainScreen].scale;
			if (badgePixels < 1.0f)
				badgePixels = 160.0f;
			dispatch_async(TGImageDecodeQueue(), ^{
				UIImage *image = nil;
				@autoreleasepool {
					image = TGDecodeThumbnail(path, badgePixels);
				}
				if (!image)
					return;
				dispatch_async(dispatch_get_main_queue(), ^{
					if (!weakSelf)
						return;
					weakSelf.stickerShown = YES;
					weakSelf.headerBadgeView.contentMode = UIViewContentModeScaleAspectFit;
					weakSelf.headerBadgeView.image = image;
				});
			});
		}];
	}];
}

- (void)loadTranscriptionTrial {
	[self applyTranscriptionTrialState];

	if (self.trialObserverToken)
		return;

	__weak typeof(self) weakSelf = self;
	self.trialObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGSpeechRecognitionTrialDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf applyTranscriptionTrialState];
					[strongSelf.tableView reloadData];
				}];
}

- (void)applyTranscriptionTrialState {
	TGClient *client = [TGClient shared];
	self.trialKnown = client.speechRecognitionTrialKnown;
	self.trialWeekly = client.speechRecognitionTrialWeeklyCount;
	self.trialRemaining = client.speechRecognitionTrialLeftCount;
	self.trialCooldownUntil = client.speechRecognitionTrialNextResetDate;
}

- (BOOL)showsTranscriptionRow {
	return self.trialKnown && self.trialWeekly > 0;
}

- (NSString *)transcriptionTrialText {
	if ([[TGClient shared] isPremiumAccount] || [self.options[@"isPremium"] boolValue])
		return TGL(@"PeerInfo.Gifts.Unlimited", @"Unlimited");

	NSInteger left = self.trialRemaining < 0 ? 0 : self.trialRemaining;
	if (left > 0) {
		if (self.trialWeekly > 0)
			return [NSString stringWithFormat:TGL(@"Premium.LeftOfWeeklyLimit", @"%@ of %@ left"),
				@(left), @(self.trialWeekly)];
		return TGLPlural(@"Premium.TrialUsesLeft", left, @"%@ left", @"%@ left");
	}

	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	if (self.trialCooldownUntil > now) {
		return [NSString stringWithFormat:TGL(@"Premium.ResetsAt", @"Resets %@"),
			[TGDateUtils stringForDateAndTime:(int)self.trialCooldownUntil]];
	}
	return TGL(@"Premium.NoneLeft", @"None left");
}

@end
