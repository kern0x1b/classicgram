#import "TGPollUpdateMerge.h"

NSArray *TGMessagesWithUpdatedPoll(NSArray *messages, NSDictionary *pollFields,
		NSIndexSet **changedIndexes) {
	if (changedIndexes)
		*changedIndexes = [NSIndexSet indexSet];
	if (![messages isKindOfClass:[NSArray class]])
		return messages;
	if (![pollFields isKindOfClass:[NSDictionary class]])
		return messages;

	long long pollId = [pollFields[@"pollId"] longLongValue];
	if (!pollId)
		return messages;

	NSMutableIndexSet *changed = [NSMutableIndexSet indexSet];
	NSMutableArray *merged = [messages mutableCopy];
	for (NSUInteger index = 0; index < merged.count; index++) {
		NSDictionary *message = merged[index];
		if (![message isKindOfClass:[NSDictionary class]])
			continue;
		if ([message[@"pollId"] longLongValue] != pollId)
			continue;
		NSMutableDictionary *updated = [message mutableCopy];
		[updated addEntriesFromDictionary:pollFields];
		if ([updated isEqualToDictionary:message])
			continue;
		merged[index] = [updated copy];
		[changed addIndex:index];
	}

	if (!changed.count)
		return messages;
	if (changedIndexes)
		*changedIndexes = [changed copy];
	return [merged copy];
}
