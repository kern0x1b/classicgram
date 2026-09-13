#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+AppSettings.h"
#import "TGTheme.h"
#import "TGHexColour.h"

static NSMutableDictionary *TGChatThemeColoursCache(void) {
	static NSMutableDictionary *cache = nil;
	if (!cache)
		cache = [[NSMutableDictionary alloc] init];
	return cache;
}

UIColor *TGActiveChatThemeBubbleMineColour(int64_t chatId) {
	NSNumber *value = TGChatThemeColoursCache()[@(chatId)][@"bubbleMineColour"];
	return [value isKindOfClass:NSNumber.class] ? TGColourFromHex((unsigned int)[value unsignedIntValue]) : nil;
}

UIColor *TGActiveChatThemeAccentColour(int64_t chatId) {
	NSNumber *value = TGChatThemeColoursCache()[@(chatId)][@"accentColour"];
	return [value isKindOfClass:NSNumber.class] ? TGColourFromHex((unsigned int)[value unsignedIntValue]) : nil;
}

void TGResetActiveChatThemeCachesForAccountSwitch(void) {
	[TGChatThemeColoursCache() removeAllObjects];
}

@implementation TGChatViewController (Theme)

- (void)loadChatTheme {
	if (!self.chatId) {
		[TGChatThemeColoursCache() removeObjectForKey:@(self.chatId)];
		self.chatThemeBackgroundRow = nil;
		self.chatThemeUnresolved = NO;
		return;
	}

	int64_t chatId = self.chatId;
	NSUInteger generation = ++self.chatThemeLoadGeneration;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatThemeColoursForChat:chatId
									 completion:^(NSDictionary *colours) {
										 __strong typeof(weakSelf) strongSelf = weakSelf;
										 if (!strongSelf || strongSelf.chatThemeLoadGeneration != generation)
											 return;
										 if (colours.count > 0)
											 TGChatThemeColoursCache()[@(chatId)] = colours;
										 else
											 [TGChatThemeColoursCache() removeObjectForKey:@(chatId)];
										 strongSelf.chatThemeUnresolved = [colours[@"unresolved"] boolValue];

										 NSDictionary *backgroundRow = [colours[@"backgroundRow"] isKindOfClass:NSDictionary.class]
											 ? colours[@"backgroundRow"]
											 : nil;
										 BOOL hadThemeBackground = strongSelf.chatThemeBackgroundRow != nil;
										 strongSelf.chatThemeBackgroundRow = backgroundRow;
										 if (backgroundRow) {
											 NSUInteger wallpaperGeneration = ++strongSelf.chatWallpaperLoadGeneration;
											 [strongSelf applyChatWallpaperRow:backgroundRow generation:wallpaperGeneration];
										 } else if (hadThemeBackground) {
											 [strongSelf loadChatWallpaper];
										 }

										 [strongSelf.table reloadData];
									 }];
}

- (void)chatThemeChanged:(NSNotification *)note {
	if (note.object && ![note.object isEqual:@(self.chatId)])
		return;
	[self loadChatTheme];
}

- (void)chatThemeCatalogChanged:(NSNotification *)note {
	if (!self.chatThemeUnresolved)
		return;
	[self loadChatTheme];
}

@end
