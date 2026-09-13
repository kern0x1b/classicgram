#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (WebLinks)

#pragma mark - link routing

- (void)resolveLink:(NSString *)url
		 completion:(void (^ _Nullable)(NSDictionary *link))completion;

- (void)linkForInternalType:(NSDictionary *)type
					 isHttp:(BOOL)isHttp
				 completion:(void (^ _Nullable)(NSString *url))completion;

- (void)publicLinkForUsername:(NSString *)username
				   completion:(void (^ _Nullable)(NSString *url))completion;

- (void)publicLinkForStickerSetName:(NSString *)name
						 completion:(void (^ _Nullable)(NSString *url))completion;

#pragma mark - external links

- (void)externalLinkInfoForUrl:(NSString *)url
					completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)externalLinkForUrl:(NSString *)url
		  allowWriteAccess:(BOOL)allowWriteAccess
				completion:(void (^ _Nullable)(NSString *url))completion;

- (void)loginUrlInfoForButton:(int64_t)buttonId
					inMessage:(int64_t)messageId
					   inChat:(int64_t)chatId
				   completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)loginUrlForButton:(int64_t)buttonId
				inMessage:(int64_t)messageId
				   inChat:(int64_t)chatId
		 allowWriteAccess:(BOOL)allowWriteAccess
			   completion:(void (^ _Nullable)(NSString *url))completion;

- (void)deepLinkInfoForUrl:(NSString *)url
				completion:(void (^ _Nullable)(NSString *text, BOOL needsUpdate))completion;

#pragma mark - third-party login (oauth)

- (void)oauthLinkInfoForUrl:(NSString *)url
				 completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)checkOauthMatchCode:(NSString *)matchCode
					 forUrl:(NSString *)url
				 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)acceptOauthRequestForUrl:(NSString *)url
					   matchCode:(NSString *)matchCode
				allowWriteAccess:(BOOL)allowWriteAccess
		  allowPhoneNumberAccess:(BOOL)allowPhoneNumberAccess
					  completion:(void (^ _Nullable)(NSString *openUrl))completion;

- (void)declineOauthRequestForUrl:(NSString *)url;

#pragma mark - link previews

- (void)linkPreviewForText:(NSString *)text
			   withOptions:(nullable NSDictionary *)options
				completion:(void (^ _Nullable)(NSDictionary *preview))completion;

+ (NSDictionary *)linkPreviewOptionsDisabled:(BOOL)disabled
										 url:(NSString *)url
							 forceSmallMedia:(BOOL)forceSmall
							 forceLargeMedia:(BOOL)forceLarge
							   showAboveText:(BOOL)showAboveText;

+ (NSDictionary *)flattenedLinkPreview:(NSDictionary *)preview;

+ (NSArray *)tappableEntitiesIn:(NSDictionary *)formattedText;

#pragma mark - instant view

- (void)instantViewForUrl:(NSString *)url
			   completion:(void (^ _Nullable)(NSDictionary *view))completion;

- (void)instantViewForUrl:(NSString *)url
				onlyLocal:(BOOL)onlyLocal
			   completion:(void (^ _Nullable)(NSDictionary *view))completion;

#pragma mark - rich messages

+ (NSArray *)flattenedPageBlocks:(NSArray *)rawBlocks;

- (void)fullRichMessageForMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
					   completion:(void (^ _Nullable)(NSArray *blocks, BOOL isRtl))completion;

#pragma mark - misc t.me

- (void)recentlyVisitedTMeUrlsWithReferrer:(NSString * _Nullable)referrer
								completion:(void (^ _Nullable)(NSArray *urls))completion;

- (void)applicationDownloadLinkWithCompletion:(void (^ _Nullable)(NSString *url))completion;

@end

NS_ASSUME_NONNULL_END
