#ifndef TG_CHAT_HISTORY_MERGE_H
#define TG_CHAT_HISTORY_MERGE_H

#import <Foundation/Foundation.h>

NSArray *TGHistoryWithOlderPagePrepended(NSArray *existing,
	NSArray *incoming,
	long long anchorMessageId);

#endif
