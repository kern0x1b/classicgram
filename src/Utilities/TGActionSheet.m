#import "TGActionSheet.h"
#import "TGLocalization.h"

@implementation TGActionSheetAction

- (instancetype)initWithTitle:(NSString *)title action:(NSString *)action {
	return [self initWithTitle:title action:action type:TGActionSheetActionTypeGeneric];
}

- (instancetype)initWithTitle:(NSString *)title action:(NSString *)action type:(TGActionSheetActionType)type {
	self = [super init];
	if (self != nil) {
		_title = title;
		_action = action;
		_type = type;
	}
	return self;
}

@end

@interface TGActionSheet () <UIActionSheetDelegate>

@property (nonatomic, weak) id target;
@property (nonatomic, copy) void (^actionBlock)(id target, NSString *action);
@property (nonatomic, strong) NSArray *actions;

@end

@implementation TGActionSheet

static NSString *TGActionSheetCancelTitle() {
	NSString *title = TGL(@"Common.Cancel", @"Cancel");
	if (title.length == 0 || [title isEqualToString:@"Common.Cancel"])
		title = @"Cancel";
	return title;
}

- (instancetype)initWithTitle:(NSString *)title actions:(NSArray *)actions actionBlock:(void (^)(id target, NSString *action))actionBlock target:(id)target {
	NSString *sheetTitle = title.length == 0 ? nil : title;

	self = [super initWithTitle:sheetTitle delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
	if (self != nil) {
		self.delegate = self;
		self.actionSheetStyle = UIActionSheetStyleDefault;

		NSMutableArray *orderedActions = [[NSMutableArray alloc] init];
		TGActionSheetAction *cancelAction = nil;
		bool hasDestructive = false;

		for (id item in actions) {
			if (![item isKindOfClass:[TGActionSheetAction class]])
				continue;

			TGActionSheetAction *action = (TGActionSheetAction *)item;
			if (action.title.length == 0)
				continue;

			if (action.type == TGActionSheetActionTypeCancel) {
				if (cancelAction == nil)
					cancelAction = action;
				continue;
			}

			if (action.type == TGActionSheetActionTypeDestructive) {
				if (hasDestructive)
					action.type = TGActionSheetActionTypeGeneric;
				else
					hasDestructive = true;
			}

			[orderedActions addObject:action];
		}

		if (cancelAction == nil) {
			cancelAction = [[TGActionSheetAction alloc] initWithTitle:TGActionSheetCancelTitle() action:@"cancel" type:TGActionSheetActionTypeCancel];
		} else if (cancelAction.title.length == 0) {
			cancelAction.title = TGActionSheetCancelTitle();
		}

		[orderedActions addObject:cancelAction];

		_actions = orderedActions;

		self.cancelButtonIndex = -1;
		self.destructiveButtonIndex = -1;

		for (TGActionSheetAction *action in _actions) {
			NSInteger buttonIndex = [self addButtonWithTitle:action.title];
			if (action.type == TGActionSheetActionTypeCancel)
				self.cancelButtonIndex = buttonIndex;
			else if (action.type == TGActionSheetActionTypeDestructive)
				self.destructiveButtonIndex = buttonIndex;
		}

		self.actionBlock = actionBlock;
		self.target = target;
	}
	return self;
}

- (void)actionSheet:(UIActionSheet *)__unused actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex < 0 || buttonIndex >= (NSInteger)_actions.count)
		return;

	NSString *action = ((TGActionSheetAction *)_actions[buttonIndex]).action;
	if (action == nil)
		return;

	id target = _target;
	if (target == nil)
		return;

	if (_dismissBlock != nil && !_dismissBlock(target, action))
		return;

	if (_actionBlock != nil)
		_actionBlock(target, action);
}

- (void)actionSheetCancel:(UIActionSheet *)__unused actionSheet {
	if (self.cancelButtonIndex >= 0 && self.cancelButtonIndex < (NSInteger)_actions.count)
		[self actionSheet:self clickedButtonAtIndex:self.cancelButtonIndex];
}

- (void)actionSheet:(UIActionSheet *)__unused actionSheet didDismissWithButtonIndex:(NSInteger)__unused buttonIndex {
	self.delegate = nil;
	self.actionBlock = nil;
	self.dismissBlock = nil;
	self.target = nil;
}

- (BOOL)canBecomeFirstResponder {
	return false;
}

- (BOOL)resignFirstResponder {
	return false;
}

@end

@implementation UIActionSheet (TGPopoverPresentation)

- (void)tg_showFromBarButtonItem:(UIBarButtonItem *)barButtonItem inView:(UIView *)fallbackView {
	if (barButtonItem != nil && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		[self showFromBarButtonItem:barButtonItem animated:YES];
		return;
	}
	[self showInView:fallbackView];
}

- (void)tg_showFromRect:(CGRect)rect inView:(UIView *)view {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && view != nil && !CGRectIsEmpty(rect)) {
		[self showFromRect:rect inView:view animated:YES];
		return;
	}
	[self showInView:view];
}

@end
