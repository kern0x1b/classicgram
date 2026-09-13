#import "TGActionSheetIndexBuilder.h"

@implementation TGActionSheetIndexBuilder

+ (UIActionSheet *)sheetWithTitle:(NSString *)title
						 delegate:(id<UIActionSheetDelegate>)delegate
					  otherTitles:(NSArray *)otherTitles
				 destructiveIndex:(NSInteger)destructiveIndex
					  cancelTitle:(NSString *)cancelTitle
		   destructiveButtonIndex:(NSInteger *)outDestructiveButtonIndex
				cancelButtonIndex:(NSInteger *)outCancelButtonIndex {
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:title delegate:delegate cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];

	NSInteger resolvedDestructiveIndex = -1;
	for (NSInteger i = 0; i < (NSInteger)otherTitles.count; i++) {
		NSInteger addedIndex = [sheet addButtonWithTitle:otherTitles[i]];
		if (i == destructiveIndex)
			resolvedDestructiveIndex = addedIndex;
	}
	if (resolvedDestructiveIndex >= 0)
		sheet.destructiveButtonIndex = resolvedDestructiveIndex;

	NSInteger resolvedCancelIndex = [sheet addButtonWithTitle:cancelTitle];
	sheet.cancelButtonIndex = resolvedCancelIndex;

	if (outDestructiveButtonIndex)
		*outDestructiveButtonIndex = resolvedDestructiveIndex;
	if (outCancelButtonIndex)
		*outCancelButtonIndex = resolvedCancelIndex;

	return sheet;
}

@end
