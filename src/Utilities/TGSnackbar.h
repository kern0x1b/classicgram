#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, TGSnackbarKind) {
	TGSnackbarKindTransient = 0,
	TGSnackbarKindDestructiveUndo,
};

@interface TGSnackbar : UIView

+ (void)showInView:(UIView *)host
			  text:(NSString *)text
		   seconds:(NSInteger)seconds
		  onCommit:(void (^)(void))commit;

+ (void)showInView:(UIView *)host
			  text:(NSString *)text
		   seconds:(NSInteger)seconds
			  kind:(TGSnackbarKind)kind
		  onCommit:(void (^)(void))commit;

+ (void)commitNow;

@end
