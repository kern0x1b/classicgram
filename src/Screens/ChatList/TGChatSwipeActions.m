#import "TGChatSwipeActions.h"

NSArray *TGChatSwipeActionKinds(NSDictionary *chat,
	BOOL showingSearchResults,
	BOOL multiSelecting,
	BOOL showingArchive) {
	if (showingSearchResults || multiSelecting)
		return nil;
	if (![chat isKindOfClass:[NSDictionary class]])
		return nil;
	if (![chat[@"id"] longLongValue])
		return nil;

	NSString *mute = [chat[@"isMuted"] boolValue] ? @"unmute" : @"mute";
	NSString *archive = showingArchive ? @"unarchive" : @"archive";
	return @[ mute, archive, @"delete" ];
}
