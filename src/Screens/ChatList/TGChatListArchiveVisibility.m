#import "TGChatListArchiveVisibility.h"
#import "TGAccountManager.h"

static NSString *const TGChatListArchiveHiddenKey = @"TGArchiveHiddenByDefault";

static NSString *TGChatListArchiveHiddenDefaultsKey(void) {
	return [TGAccountManager defaultsKey:TGChatListArchiveHiddenKey];
}

BOOL TGArchiveHiddenByDefault(void) {
	id stored = [[NSUserDefaults standardUserDefaults] objectForKey:TGChatListArchiveHiddenDefaultsKey()];
	return stored ? [stored boolValue] : YES;
}

void TGSetArchiveHiddenByDefault(BOOL hidden) {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:hidden forKey:TGChatListArchiveHiddenDefaultsKey()];
	[defaults synchronize];
}
