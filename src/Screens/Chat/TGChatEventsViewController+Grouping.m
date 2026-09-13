#import "TGChatEventsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGClient.h"
#import "TGClient+ChatManagement.h"
#import "TGClient+Messages.h"
#import "TGChatViewController.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGDateUtils.h"
#import "UIView+SafeTint.h"

@implementation TGChatEventsViewController (Grouping)

- (NSString *)dayTitleForDate:(int)date {
	time_t stamp = (time_t)date;
	struct tm parts;
	localtime_r(&stamp, &parts);
	time_t now = time(0);
	struct tm nowParts;
	localtime_r(&now, &nowParts);

	if (parts.tm_year == nowParts.tm_year && parts.tm_yday == nowParts.tm_yday)
		return TGL(@"Weekday.Today", @"Today");
	if (parts.tm_year == nowParts.tm_year && parts.tm_yday == nowParts.tm_yday - 1)
		return TGL(@"Weekday.Yesterday", @"Yesterday");

	return [TGDateUtils stringForFullDate:(int)date];
}

- (void)rebuildSections {
	[self.sections removeAllObjects];

	NSString *currentTitle = nil;
	NSMutableArray *currentRows = nil;
	for (NSDictionary *event in [self groupedDisplayEvents]) {
		NSString *title = [self dayTitleForDate:TGEventsInt(event, @"date")];
		if (!currentTitle || ![title isEqualToString:currentTitle]) {
			currentTitle = title;
			currentRows = [NSMutableArray array];
			[self.sections addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
											 title, @"title", currentRows, @"rows", nil]];
		}
		[currentRows addObject:event];
	}
}

- (NSDictionary *)eventAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section >= (NSInteger)self.sections.count)
		return nil;
	NSArray *rows = self.sections[indexPath.section][@"rows"];
	if (indexPath.row >= (NSInteger)rows.count)
		return nil;
	return rows[indexPath.row];
}

- (NSString *)summaryForEvent:(NSDictionary *)event {
	NSString *text = TGEventsText(event, @"text");
	if (text.length)
		return text;
	NSString *action = TGEventsText(event, @"action");
	if (action.length)
		return action;
	return TGL(@"ChatEvents.UnknownAction", @"Unknown action");
}

- (NSArray *)groupedDisplayEvents {
	NSMutableArray *display = [NSMutableArray array];
	NSInteger count = self.events.count;
	NSInteger i = 0;
	while (i < count) {
		NSDictionary *event = self.events[i];
		if ([TGEventsText(event, @"action") isEqualToString:@"MessageDeleted"]) {
			long long userId = TGEventsLongLong(event, @"userId");
			NSInteger j = i + 1;
			while (j < count) {
				NSDictionary *next = self.events[j];
				if (![TGEventsText(next, @"action") isEqualToString:@"MessageDeleted"])
					break;
				if (TGEventsLongLong(next, @"userId") != userId)
					break;
				j++;
			}
			NSInteger length = j - i;
			if (length > 1) {
				NSArray *subEvents = [self.events subarrayWithRange:NSMakeRange(i, length)];
				NSNumber *groupKey = TGEventsNumber(event, @"eventId");
				[display addObject:[self groupHeaderForSubEvents:subEvents groupKey:groupKey]];
				if (groupKey && [self.expandedGroupIds containsObject:groupKey])
					[display addObjectsFromArray:subEvents];
				i = j;
				continue;
			}
		}
		[display addObject:event];
		i++;
	}
	return display;
}

- (NSDictionary *)groupHeaderForSubEvents:(NSArray *)subEvents groupKey:(NSNumber *)groupKey {
	NSDictionary *first = subEvents.firstObject;
	NSString *name = TGEventsText(first, @"name");
	if (!name.length)
		name = TGL(@"Premium.GiftedTitle.Someone", @"Someone");

	NSMutableArray *peerNames = [NSMutableArray array];
	NSMutableSet *seenAuthors = [NSMutableSet set];
	for (NSDictionary *sub in subEvents) {
		NSString *authorName = TGEventsText(sub, @"messageAuthorName");
		if (!authorName.length || [seenAuthors containsObject:authorName])
			continue;
		[seenAuthors addObject:authorName];
		[peerNames addObject:authorName];
	}
	NSString *peerNamesText = peerNames.count ? [peerNames componentsJoinedByString:@", "] : name;

	BOOL expanded = groupKey && [self.expandedGroupIds containsObject:groupKey];
	NSString *messagesString = TGLPlural(@"Channel.AdminLog.MessageManyDeleted.Messages",
		(NSInteger)subEvents.count, @"%@ message", @"%@ messages");
	NSString *moreText = expanded
		? TGL(@"Channel.AdminLog.MessageManyDeleted.HideAll", @"hide all")
		: TGL(@"Channel.AdminLog.MessageManyDeleted.ShowAll", @"show all");

	NSString *text = [NSString stringWithFormat:
			TGL(@"Channel.AdminLog.MessageManyDeletedMore", @"%1$@ deleted %2$@ from %3$@  %4$@"),
		name, messagesString, peerNamesText, moreText];

	NSMutableDictionary *header = [NSMutableDictionary dictionaryWithDictionary:first];
	header[@"isGroupHeader"] = @YES;
	header[@"groupKey"] = groupKey ?: @0;
	header[@"text"] = text;
	header[@"messageId"] = @0;
	header[@"canReportNotSpam"] = @NO;
	return header;
}

- (void)toggleGroupExpanded:(NSNumber *)groupKey {
	if (!groupKey)
		return;
	if ([self.expandedGroupIds containsObject:groupKey])
		[self.expandedGroupIds removeObject:groupKey];
	else
		[self.expandedGroupIds addObject:groupKey];
	[self rebuildSections];
	[self.tableView reloadData];
}

@end
