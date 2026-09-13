#import "TGTextFieldStyle.h"
#import "TGMediaSendPreviewViewController.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGLazyFramework.h"
#import <AVFoundation/AVFoundation.h>

static const CGFloat kTGMediaPreviewBarHeight = 50.0f;

@interface TGMediaSendPreviewViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIImageView *previewView;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UITextField *captionField;
@property (nonatomic, strong) UIButton *onceButton;
@property (nonatomic, strong) UIButton *spoilerButton;
@property (nonatomic, strong) UIButton *silentButton;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, assign) BOOL sendOnce;
@property (nonatomic, assign) BOOL spoiler;
@property (nonatomic, assign) BOOL silentSend;
@property (nonatomic, assign) CGFloat keyboardOverlap;
@property (nonatomic, strong) id keyboardWillShowObserverToken;
@property (nonatomic, strong) id keyboardWillHideObserverToken;
@end

@implementation TGMediaSendPreviewViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = [UIColor blackColor];
	self.sendOnce = self.initialSendOnce;

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.title = self.videoPath.length
		? TGL(@"Message.Video", @"Video")
		: TGL(@"Message.Photo", @"Photo");
	self.navigationItem.leftBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Cancel", @"Cancel") bold:NO
									   target:self
									   action:@selector(cancelTapped)];

	self.previewView = [[UIImageView alloc] init];
	self.previewView.contentMode = UIViewContentModeScaleAspectFit;
	self.previewView.backgroundColor = [UIColor blackColor];
	self.previewView.image = self.image ?: [self videoThumbnail];
	[self.view addSubview:self.previewView];

	self.bottomBar = [[UIView alloc] init];
	self.bottomBar.backgroundColor = [[TGTheme shared] inputBarColour];
	[self.view addSubview:self.bottomBar];

	self.captionField = [[UITextField alloc] init];
	self.captionField.delegate = self;
	self.captionField.font = [UIFont systemFontOfSize:16];
	self.captionField.placeholder = TGL(@"MediaPicker.AddCaption", @"Add a caption");
	self.captionField.returnKeyType = UIReturnKeyDefault;
	TGStyleTextFieldOverDarkness(self.captionField);
	self.captionField.text = self.initialCaption;
	[self.bottomBar addSubview:self.captionField];

	self.onceButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.onceButton.layer.cornerRadius = 15;
	self.onceButton.layer.borderWidth = 1.5f;
	self.onceButton.layer.borderColor = [UIColor whiteColor].CGColor;
	self.onceButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
	[self.onceButton setTitle:@"1" forState:UIControlStateNormal];
	[self.onceButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[self.onceButton addTarget:self action:@selector(toggleSendOnce)
			   forControlEvents:UIControlEventTouchUpInside];
	self.onceButton.hidden = !self.allowsSendOnce;
	[self.bottomBar addSubview:self.onceButton];
	[self updateOnceButtonAppearance];

	self.spoilerButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.spoilerButton.layer.cornerRadius = 15;
	self.spoilerButton.layer.borderWidth = 1.5f;
	self.spoilerButton.layer.borderColor = [UIColor whiteColor].CGColor;
	self.spoilerButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
	[self.spoilerButton setTitle:@"S" forState:UIControlStateNormal];
	[self.spoilerButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[self.spoilerButton addTarget:self action:@selector(toggleSpoiler)
				  forControlEvents:UIControlEventTouchUpInside];
	[self.bottomBar addSubview:self.spoilerButton];
	[self updateSpoilerButtonAppearance];

	self.silentButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.silentButton.layer.cornerRadius = 15;
	self.silentButton.layer.borderWidth = 1.5f;
	self.silentButton.layer.borderColor = [UIColor whiteColor].CGColor;
	self.silentButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
	[self.silentButton setTitle:@"\U0001F515" forState:UIControlStateNormal];
	[self.silentButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[self.silentButton addTarget:self action:@selector(toggleSilentSend)
				 forControlEvents:UIControlEventTouchUpInside];
	self.silentButton.accessibilityLabel = TGL(@"Conversation.SendMessage.SendSilently", @"Send Without Sound");
	[self.bottomBar addSubview:self.silentButton];
	[self updateSilentButtonAppearance];

	self.sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
	[self.sendButton setTitle:TGL(@"MediaPicker.Send", @"Send") forState:UIControlStateNormal];
	[self.sendButton setTitleColor:[[TGTheme shared] accentColour] forState:UIControlStateNormal];
	[self.sendButton addTarget:self action:@selector(sendTapped)
			  forControlEvents:UIControlEventTouchUpInside];
	[self.bottomBar addSubview:self.sendButton];

	__weak typeof(self) weakSelf = self;
	self.keyboardWillShowObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIKeyboardWillShowNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf keyboardWillShow:note];
				}];
	self.keyboardWillHideObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIKeyboardWillHideNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf keyboardWillHide:note];
				}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.keyboardWillShowObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.keyboardWillShowObserverToken];
	if (self.keyboardWillHideObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.keyboardWillHideObserverToken];
}

- (UIImage *)videoThumbnail {
	if (!self.videoPath.length)
		return nil;
	AVURLAsset *asset = [TGAVClass(AVURLAsset)
		URLAssetWithURL:[NSURL fileURLWithPath:self.videoPath] options:nil];
	AVAssetImageGenerator *generator = [[TGAVClass(AVAssetImageGenerator) alloc] initWithAsset:asset];
	generator.appliesPreferredTrackTransform = YES;
	CGImageRef frame = [generator copyCGImageAtTime:CMTimeMake(0, 1) actualTime:NULL error:NULL];
	if (!frame)
		return nil;
	UIImage *thumbnail = [UIImage imageWithCGImage:frame];
	CGImageRelease(frame);
	return thumbnail;
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	CGRect bounds = self.view.bounds;
	CGFloat barHeight = kTGMediaPreviewBarHeight + self.keyboardOverlap;
	CGFloat barTop = bounds.size.height - barHeight;

	self.previewView.frame = CGRectMake(0, 0, bounds.size.width, barTop);
	self.bottomBar.frame = CGRectMake(0, barTop, bounds.size.width, barHeight);

	CGFloat side = 30;
	CGFloat margin = 10;
	CGFloat toggleX = margin;
	self.onceButton.frame = CGRectMake(toggleX, (kTGMediaPreviewBarHeight - side) / 2, side, side);
	if (!self.onceButton.hidden)
		toggleX += side + margin;
	self.spoilerButton.frame = CGRectMake(toggleX, (kTGMediaPreviewBarHeight - side) / 2, side, side);
	toggleX += side + margin;
	self.silentButton.frame = CGRectMake(toggleX, (kTGMediaPreviewBarHeight - side) / 2, side, side);
	toggleX += side + margin;

	CGFloat sendWidth = [[self.sendButton titleForState:UIControlStateNormal]
		sizeWithFont:self.sendButton.titleLabel.font].width + 20;
	self.sendButton.frame = CGRectMake(bounds.size.width - margin - sendWidth,
		0, sendWidth, kTGMediaPreviewBarHeight);

	CGFloat fieldLeft = toggleX;
	CGFloat fieldRight = self.sendButton.frame.origin.x;
	self.captionField.frame = CGRectMake(fieldLeft, 0,
		MAX(0, fieldRight - fieldLeft - margin), kTGMediaPreviewBarHeight);
}

- (void)updateOnceButtonAppearance {
	self.onceButton.backgroundColor = self.sendOnce
		? [[TGTheme shared] accentColour]
		: [UIColor clearColor];
}

- (void)toggleSendOnce {
	if (!self.allowsSendOnce)
		return;
	self.sendOnce = !self.sendOnce;
	[self updateOnceButtonAppearance];
}

- (void)updateSpoilerButtonAppearance {
	self.spoilerButton.backgroundColor = self.spoiler
		? [[TGTheme shared] accentColour]
		: [UIColor clearColor];
}

- (void)toggleSpoiler {
	self.spoiler = !self.spoiler;
	[self updateSpoilerButtonAppearance];
}

- (void)updateSilentButtonAppearance {
	self.silentButton.backgroundColor = self.silentSend
		? [[TGTheme shared] accentColour]
		: [UIColor clearColor];
}

- (void)toggleSilentSend {
	self.silentSend = !self.silentSend;
	[self updateSilentButtonAppearance];
}

- (void)cancelTapped {
	[self.captionField resignFirstResponder];
	void (^cancel)(void) = self.onCancel;
	[self.navigationController popViewControllerAnimated:YES];
	if (cancel)
		cancel();
}

- (void)sendTapped {
	void (^send)(NSString *, BOOL, BOOL, BOOL) = self.onSend;
	if (!send)
		return;
	self.onSend = nil;
	[self.captionField resignFirstResponder];
	NSString *caption = [self.captionField.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
	BOOL once = self.sendOnce;
	BOOL spoiler = self.spoiler;
	BOOL silent = self.silentSend;
	[self.navigationController popViewControllerAnimated:YES];
	send(caption, once, spoiler, silent);
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return YES;
}

- (void)keyboardWillShow:(NSNotification *)note {
	NSValue *value = [note.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
	if (![value isKindOfClass:[NSValue class]])
		return;
	CGRect keyboard = [self.view convertRect:[value CGRectValue] fromView:nil];
	CGFloat overlap = MAX(0, CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(keyboard));
	self.keyboardOverlap = overlap;
	[self.view setNeedsLayout];
	[self.view layoutIfNeeded];
}

- (void)keyboardWillHide:(NSNotification *)note {
	(void)note;
	self.keyboardOverlap = 0.0f;
	[self.view setNeedsLayout];
	[self.view layoutIfNeeded];
}

@end
