#import "tg_client_test_double.h"
#import "TGClient+MessageContent.h"
#import "TGLocalization.h"

static TGClient *gTGTestSharedInstanceOverride = nil;

@interface TGClient ()
@property (nonatomic, assign) NSInteger tgTestSaveCachedChatsCallCount;
@property (nonatomic, assign) NSInteger tgTestResetForAccountSwitchCallCount;
@property (nonatomic, assign) NSInteger tgTestResumeFromBackgroundCallCount;
@property (nonatomic, assign) NSInteger tgTestLogOutCallCount;
@end

@implementation TGClient

@synthesize me = _tgTestMe;
@synthesize chats = _tgTestChats;
@synthesize archivedChats = _tgTestArchivedChats;
@synthesize authState = _tgTestAuthState;

+ (void)setSharedInstanceForTesting:(TGClient *)override {
	gTGTestSharedInstanceOverride = override;
}

+ (instancetype)shared {
	if (gTGTestSharedInstanceOverride)
		return gTGTestSharedInstanceOverride;
	static TGClient *fallback = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		fallback = [[TGClient alloc] init];
	});
	return fallback;
}

- (void)saveCachedChats {
	self.tgTestSaveCachedChatsCallCount++;
}

- (void)suspendForBackgroundWithCompletion:(void (^)(void))completion {
	if (completion)
		completion();
}

- (void)resumeFromBackground {
	self.tgTestResumeFromBackgroundCallCount++;
}

- (void)resetForAccountSwitch {
	self.tgTestResetForAccountSwitchCallCount++;
}

- (void)logOutWithCompletion:(void (^)(BOOL ok))completion {
	self.tgTestLogOutCallCount++;
	if (completion)
		completion(YES);
}

- (NSString *)placeholderTextForContentKind:(NSString *)kind {
	if ([kind isEqualToString:@"messageExpiredPhoto"])
		return TGL(@"Message.ImageExpired", @"Photo has expired");
	if ([kind isEqualToString:@"messageExpiredVideo"])
		return TGL(@"Message.VideoExpired", @"Video has expired");
	if ([kind isEqualToString:@"messageExpiredVoiceNote"])
		return TGL(@"Message.VoiceMessageExpired", @"Expired voice message");
	if ([kind isEqualToString:@"messageExpiredVideoNote"])
		return TGL(@"Message.VideoMessageExpired", @"Expired video message");
	if ([kind isEqualToString:@"messageUnsupported"])
		return TGL(@"Conversation.UnsupportedMediaPlaceholder",
			@"This message is not supported on your version of Telegram. "
			 "Please update to the latest version.");
	return nil;
}

@end
