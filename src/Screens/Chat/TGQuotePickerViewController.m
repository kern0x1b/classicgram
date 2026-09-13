#import "TGQuotePickerViewController.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGQuoteEntitySelection.h"

static const NSInteger kQuoteLengthLimit = 1024;

@interface TGQuotePickerViewController () <UITextViewDelegate>
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *hint;
@property (nonatomic, strong) UIBarButtonItem *quoteItem;
@end

@implementation TGQuotePickerViewController {
	BOOL _confirmed;
}

- (id)initWithText:(NSString *)text entities:(NSArray *)entities author:(NSString *)author {
	self = [super init];
	if (self) {
		_sourceText = [text copy];
		_sourceEntities = [entities copy];
		_authorName = [author copy];
		self.title = TGL(@"Conversation.MessageOptionsQuoteSelect", @"Select a Fragment");
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	TGTheme *theme = [TGTheme shared];
	self.view.backgroundColor = [theme listBackgroundColour];

	CGRect bounds = self.view.bounds;
	const CGFloat hintHeight = 34;

	self.hint = [[UILabel alloc] initWithFrame:
			CGRectMake(12, 4, bounds.size.width - 24, hintHeight - 8)];
	self.hint.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.hint.backgroundColor = [UIColor clearColor];
	self.hint.font = [UIFont systemFontOfSize:13];
	self.hint.textColor = [theme secondaryTextColour];
	self.hint.numberOfLines = 2;
	self.hint.text = TGL(@"ChatContextMenu.QuoteSelectionTip", @"Hold on a word, then move cursor to select more text to quote.");
	[self.view addSubview:self.hint];

	self.textView = [[UITextView alloc] initWithFrame:
			CGRectMake(0, hintHeight, bounds.size.width,
				bounds.size.height - hintHeight)];
	self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
		UIViewAutoresizingFlexibleHeight;
	self.textView.backgroundColor = [theme inputBarColour];
	self.textView.textColor = [theme primaryTextColour];
	self.textView.font = [UIFont systemFontOfSize:16];
	self.textView.text = self.sourceText ?: @"";
	self.textView.editable = YES;
	self.textView.dataDetectorTypes = UIDataDetectorTypeNone;
	self.textView.inputView = [[UIView alloc] initWithFrame:CGRectZero];
	self.textView.delegate = self;
	[self.view addSubview:self.textView];

	NSString *title = TGL(@"Conversation.ContextMenuQuote", @"Quote");
	self.quoteItem = [TGIcons headerBarButtonItemWithTitle:title bold:YES
													target:self
													action:@selector(commitQuote)];
	self.navigationItem.rightBarButtonItem = self.quoteItem;
	self.quoteItem.enabled = NO;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (BOOL)textView:(UITextView *)textView
	shouldChangeTextInRange:(NSRange)range
			replacementText:(NSString *)text {
	(void)textView;
	(void)range;
	(void)text;
	return NO;
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
	self.quoteItem.enabled = (textView.selectedRange.length > 0);
}

- (void)commitQuote {
	if (_confirmed)
		return;
	_confirmed = YES;
	self.quoteItem.enabled = NO;

	NSRange range = self.textView.selectedRange;
	NSString *whole = self.textView.text ?: @"";
	if (range.length == 0 || NSMaxRange(range) > whole.length) {
		[self.navigationController popViewControllerAnimated:YES];
		return;
	}
	if (range.length > kQuoteLengthLimit) {
		range.length = kQuoteLengthLimit;
		NSUInteger boundary = NSMaxRange(range);
		if (boundary > range.location && boundary < whole.length) {
			unichar boundaryUnit = [whole characterAtIndex:boundary - 1];
			if (boundaryUnit >= 0xD800 && boundaryUnit <= 0xDBFF)
				range.length -= 1;
		}
	}

	NSString *fragment = [whole substringWithRange:range];
	NSArray *entities = TGQuoteEntitiesForSelectedRange(self.sourceEntities, range);
	void (^handler)(NSString *, NSArray *, NSInteger) = self.onQuote;
	self.onQuote = nil;
	[self.navigationController popViewControllerAnimated:YES];
	if (handler)
		handler(fragment, entities, (NSInteger)range.location);
}

@end
