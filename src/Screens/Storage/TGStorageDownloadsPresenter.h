#import <Foundation/Foundation.h>

@class TGStorageDownloadsItem;

@interface TGStorageDownloadsPresenter : NSObject

@property (nonatomic, readonly) NSInteger numberOfEntryRows;
@property (nonatomic, readonly) BOOL showsClearRow;

- (TGStorageDownloadsItem *)itemAtEntryRow:(NSInteger)row;
- (TGStorageDownloadsItem *)clearRowItem;

- (void)updateWithEntries:(NSArray *)entries
				   loaded:(BOOL)loaded
				  loading:(BOOL)loading
				showsMore:(BOOL)showsMore
		   suggestedNames:(NSDictionary *)suggestedNames;

@end
