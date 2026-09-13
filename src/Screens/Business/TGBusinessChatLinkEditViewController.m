#import "TGBusinessChatLinkEditViewController.h"
#import "TGIcons.h"
#import "TGFriendlyError.h"
#import "TGLocalization.h"
#import "TGBusinessService.h"
#import "TGTheme.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"

static const NSInteger kNameAlertTag = 1;
static const CGFloat kNameRowHeight = 44;

@interface TGBusinessChatLinkEditViewController () <UITextViewDelegate, UIAlertViewDelegate>

@property (nonatomic, copy) NSString *linkIdentifier;
@property (nonatomic, copy) NSString *linkName;
@property (nonatomic, copy) NSString *initialText;
@property (nonatomic, strong) NSArray *initialEntities;
@property (nonatomic, strong) UITableViewCell *nameCell;
@property (nonatomic, strong) UILabel *hint;
@property (nonatomic, strong) UILabel *placeholder;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIBarButtonItem *saveItem;

@end

@implementation TGBusinessChatLinkEditViewController

- (instancetype)initWithLink:(NSDictionary *)link {
	self = [super init];
	if (self) {
		_linkIdentifier = link[@"link"];
		_linkName = link[@"title"];
		_initialText = link[@"text"] ?: @"";
		_initialEntities = [link[@"entities"] isKindOfClass:NSArray.class] ? link[@"entities"] : @[];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	TGTheme *theme = [TGTheme shared];
	self.title = TGL(@"Business.Links.EditLinkTitle", @"Link to Chat");
	self.view.backgroundColor = [theme listBackgroundColour];

	self.saveItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Save", @"Save") bold:YES
												   target:self
												   action:@selector(save)];
	self.navigationItem.rightBarButtonItem = self.saveItem;

	CGRect bounds = self.view.bounds;
	CGFloat width = bounds.size.width;

	self.nameCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"name"];
	[theme styleCell:self.nameCell];
	self.nameCell.frame = CGRectMake(0, 0, width, kNameRowHeight);
	self.nameCell.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.nameCell.textLabel.text = TGL(@"Business.Links.LinkNameTitle", @"Link Title (Optional)");
	self.nameCell.textLabel.font = [UIFont systemFontOfSize:17];
	self.nameCell.detailTextLabel.textColor = [theme cellDetailColour];
	self.nameCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	self.nameCell.selectionStyle = UITableViewCellSelectionStyleNone;
	[self updateNameCell];
	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(editName)];
	[self.nameCell addGestureRecognizer:tap];
	[self.view addSubview:self.nameCell];

	UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(0, kNameRowHeight, width, 1.0f / [UIScreen mainScreen].scale)];
	separator.backgroundColor = [theme separatorColour];
	separator.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.view addSubview:separator];

	CGFloat hintTop = kNameRowHeight + 12;
	NSString *hintText = TGL(@"Business.Links.PreviewText", @"Filled into the message field when someone opens this link.");
	CGSize hintSize = [hintText sizeWithFont:[UIFont systemFontOfSize:13]
							constrainedToSize:CGSizeMake(width - 24, 200)
								lineBreakMode:NSLineBreakByWordWrapping];
	self.hint = [[UILabel alloc] initWithFrame:CGRectMake(12, hintTop, width - 24, ceilf(hintSize.height))];
	self.hint.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.hint.backgroundColor = [UIColor clearColor];
	self.hint.font = [UIFont systemFontOfSize:13];
	self.hint.textColor = [theme secondaryTextColour];
	self.hint.numberOfLines = 0;
	self.hint.text = hintText;
	[self.view addSubview:self.hint];

	CGFloat textTop = CGRectGetMaxY(self.hint.frame) + 8;
	self.textView = [[UITextView alloc] initWithFrame:CGRectMake(0, textTop, width, bounds.size.height - textTop)];
	self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.textView.backgroundColor = [theme inputBarColour];
	self.textView.textColor = [theme primaryTextColour];
	self.textView.font = [UIFont systemFontOfSize:16];
	self.textView.text = self.initialText;
	self.textView.dataDetectorTypes = UIDataDetectorTypeNone;
	self.textView.delegate = self;
	[self.view addSubview:self.textView];

	self.placeholder = [[UILabel alloc] initWithFrame:CGRectMake(20, textTop + 8, width - 40, 20)];
	self.placeholder.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.placeholder.backgroundColor = [UIColor clearColor];
	self.placeholder.font = [UIFont systemFontOfSize:16];
	self.placeholder.textColor = [theme secondaryTextColour];
	self.placeholder.text = TGL(@"Chat.Placeholder.BusinessLinkPreset", @"Add a preset message...");
	self.placeholder.hidden = self.initialText.length > 0;
	[self.view addSubview:self.placeholder];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)updateNameCell {
	self.nameCell.detailTextLabel.text = self.linkName.length ? self.linkName : TGL(@"GroupInfo.SharedMediaNone", @"None");
}

- (void)editName {
	UIAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"Business.Links.LinkNameTitle", @"Link Title (Optional)")
						 message:nil
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"Common.Save", @"Save"), nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert textFieldAtIndex:0].text = self.linkName ?: @"";
	alert.tag = kNameAlertTag;
	[alert show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (alertView.tag != kNameAlertTag)
		return;
	if (buttonIndex == alertView.cancelButtonIndex)
		return;
	self.linkName = [alertView textFieldAtIndex:0].text;
	[self updateNameCell];
}

- (void)textViewDidChange:(UITextView *)textView {
	self.placeholder.hidden = textView.text.length > 0;
}

- (void)save {
	NSString *text = self.textView.text ?: @"";
	self.saveItem.enabled = NO;
	NSString *name = self.linkName;
	__weak typeof(self) weakSelf = self;
	if (self.linkIdentifier.length) {
		NSArray *entities = [text isEqualToString:self.initialText] ? self.initialEntities : nil;
		[TGBusinessService editBusinessChatLink:self.linkIdentifier
											text:text
										entities:entities
										   title:name
									  completion:^(BOOL ok, NSString *errorMessage) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!ok) {
				strongSelf.saveItem.enabled = YES;
				[TGSnackbar showInView:strongSelf.navigationController.view
								   text:TGFriendlyErrorText(errorMessage,
										TGL(@"Toast.CouldNotSaveChatLink", @"Could not save the chat link"))
							seconds:2
						   onCommit:nil];
				return;
			}
			void (^onSaved)(void) = strongSelf.onSaved;
			[strongSelf.navigationController popViewControllerAnimated:YES];
			[TGSnackbar showInView:strongSelf.navigationController.view
							   text:TGL(@"Business.Links.EditLinkToastSaved", @"Preset message saved.")
							seconds:2
						   onCommit:nil];
			if (onSaved)
				onSaved();
		}];
	} else {
		[TGBusinessService createBusinessChatLinkWithText:text
													 title:name
												completion:^(NSDictionary *link, NSString *errorMessage) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!link) {
				strongSelf.saveItem.enabled = YES;
				[TGSnackbar showInView:strongSelf.navigationController.view
								   text:TGFriendlyErrorText(errorMessage,
										TGL(@"Toast.CouldNotSaveChatLink", @"Could not save the chat link"))
							seconds:2
						   onCommit:nil];
				return;
			}
			void (^onSaved)(void) = strongSelf.onSaved;
			[strongSelf.navigationController popViewControllerAnimated:YES];
			[TGSnackbar showInView:strongSelf.navigationController.view
							   text:TGL(@"Business.Links.EditLinkToastSaved", @"Preset message saved.")
							seconds:2
						   onCommit:nil];
			if (onSaved)
				onSaved();
		}];
	}
}

@end
