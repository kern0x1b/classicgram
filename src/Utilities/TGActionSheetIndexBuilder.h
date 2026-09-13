#import <UIKit/UIKit.h>

@interface TGActionSheetIndexBuilder : NSObject

+ (UIActionSheet *)sheetWithTitle:(NSString *)title
						 delegate:(id<UIActionSheetDelegate>)delegate
					  otherTitles:(NSArray *)otherTitles
				 destructiveIndex:(NSInteger)destructiveIndex
					  cancelTitle:(NSString *)cancelTitle
		   destructiveButtonIndex:(NSInteger *)outDestructiveButtonIndex
				cancelButtonIndex:(NSInteger *)outCancelButtonIndex;

@end
