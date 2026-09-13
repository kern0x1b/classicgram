#import "TGMessageLayoutBuilder+Private.h"

TGMessageLayoutComputed TGMessageLayoutBuildLocation(TGMessageItem *item,
	TGChatLayoutContext *context) {
	return TGMessageLayoutBuildPhoto(item, context);
}
