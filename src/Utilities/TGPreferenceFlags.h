#import <Foundation/Foundation.h>

extern NSString *const TGPreferenceChatListLayoutChangedNotification;

@interface TGPreferenceFlags : NSObject

+ (BOOL)syncContactsEnabled;
+ (void)setSyncContactsEnabled:(BOOL)enabled;

+ (BOOL)secretChatLinkPreviewsEnabled;
+ (void)setSecretChatLinkPreviewsEnabled:(BOOL)enabled;

+ (BOOL)badgeCountsUnreadChats;
+ (void)setBadgeCountsUnreadChats:(BOOL)enabled;
+ (BOOL)badgeIncludesMuted;
+ (void)setBadgeIncludesMuted:(BOOL)enabled;

+ (BOOL)storiesEnabled;
+ (void)setStoriesEnabled:(BOOL)enabled;

+ (NSArray *)chatListLayouts;
+ (NSArray *)chatListLayoutTitles;
+ (NSString *)chatListLayout;
+ (NSString *)chatListLayoutTitle;
+ (BOOL)chatListShowsFolderChooser;
+ (void)setChatListLayout:(NSString *)layout;

+ (BOOL)savedMessagesShowsTopics;
+ (void)setSavedMessagesShowsTopics:(BOOL)showsTopics;

+ (float)voicePlaybackRate;
+ (void)setVoicePlaybackRate:(float)rate;

+ (BOOL)stickersLargeEmojiEnabled;
+ (BOOL)stickersLoopAnimatedEnabled;

@end
