#import <UIKit/UIKit.h>

@interface TGStoryPostOptions : UIViewController <UITableViewDataSource, UITableViewDelegate,
									UITextFieldDelegate>

@property (nonatomic, strong) UIImage *preview;
@property (nonatomic, copy) NSString *chatTitle;
@property (nonatomic, assign) BOOL showsPrivacy;
@property (nonatomic, assign) BOOL premium;

@property (nonatomic, copy) NSString *caption;
@property (nonatomic, copy) NSString *privacy;
@property (nonatomic, copy) NSArray *userIds;
@property (nonatomic, assign) NSInteger period;
@property (nonatomic, assign) BOOL toProfile;
@property (nonatomic, copy) NSArray *areas;

@property (nonatomic, copy) void (^onCancel)(void);
@property (nonatomic, copy) void (^onChangeChat)(void);
@property (nonatomic, copy) void (^onPost)(void);
@property (nonatomic, copy) void (^onEditAreas)(void (^applyAreas)(NSArray *areas));

- (void)rebuildSections;

- (void)setBusy:(BOOL)busy;
- (void)setProgress:(float)fraction;

@end
