#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, TGFileStatusKind) {
	TGFileStatusKindNone = 0,
	TGFileStatusKindFile,
	TGFileStatusKindDownload,
	TGFileStatusKindProgress,
	TGFileStatusKindPlay,
	TGFileStatusKindPause
};

@interface TGFileStatusView : UIView
@property (nonatomic, assign) TGFileStatusKind kind;
@property (nonatomic, assign) CGFloat progress;
@property (nonatomic, strong) UIColor *discColour;
@property (nonatomic, strong) UIColor *glyphColour;
@property (nonatomic, copy) NSString *extensionText;
- (void)setKind:(TGFileStatusKind)kind progress:(CGFloat)progress;
@end
