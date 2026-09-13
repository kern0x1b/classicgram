#import "TGSearchResultsPresenter.h"
#import "TGSearchResultItem.h"
#import "TGSearchResultItemBuilder.h"

@implementation TGSearchResultsPresenter {
	NSArray<NSArray<TGSearchResultItem *> *> *_sections;
}

- (void)updateWithSections:(NSArray *)sections {
	NSMutableArray<NSArray<TGSearchResultItem *> *> *built = [NSMutableArray arrayWithCapacity:sections.count];
	for (NSDictionary *section in sections) {
		if (![section isKindOfClass:NSDictionary.class]) {
			[built addObject:@[]];
			continue;
		}
		NSArray *rows = [section[@"rows"] isKindOfClass:NSArray.class] ? section[@"rows"] : @[];
		BOOL isMessage = [section[@"messages"] boolValue];
		NSMutableArray<TGSearchResultItem *> *items = [NSMutableArray arrayWithCapacity:rows.count];
		for (NSDictionary *row in rows) {
			if (![row isKindOfClass:NSDictionary.class])
				continue;
			[items addObject:[TGSearchResultItemBuilder itemFromRow:row isMessage:isMessage]];
		}
		[built addObject:items];
	}
	_sections = built;
}

- (NSInteger)numberOfSections {
	return (NSInteger)_sections.count;
}

- (TGSearchResultItem *)itemInSection:(NSInteger)section row:(NSInteger)row {
	if (section < 0 || section >= (NSInteger)_sections.count)
		return nil;
	NSArray<TGSearchResultItem *> *items = _sections[(NSUInteger)section];
	if (row < 0 || row >= (NSInteger)items.count)
		return nil;
	return items[(NSUInteger)row];
}

@end
