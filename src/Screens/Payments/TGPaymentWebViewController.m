#import "TGPaymentWebViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"

@interface TGPaymentWebViewController ()
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation TGPaymentWebViewController

- (id)initWithURLString:(NSString *)urlString {
	self = [super init];
	if (!self)
		return nil;
	_urlString = [urlString copy];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	TGTheme *theme = [TGTheme shared];
	[theme styleNavigationBar:self.navigationController.navigationBar];
	self.title = TGL(@"Checkout.WebConfirmation.Title", @"Payment");
	self.view.backgroundColor = [theme listBackgroundColour];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
	self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
		UIViewAutoresizingFlexibleHeight;
	self.webView.delegate = self;
	self.webView.scalesPageToFit = YES;
	[self.view addSubview:self.webView];

	self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
			UIActivityIndicatorViewStyleGray];
	self.spinner.center = CGPointMake(self.view.bounds.size.width / 2,
		self.view.bounds.size.height / 2);
	self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
		UIViewAutoresizingFlexibleRightMargin |
		UIViewAutoresizingFlexibleTopMargin |
		UIViewAutoresizingFlexibleBottomMargin;
	[self.view addSubview:self.spinner];

	NSURL *url = [NSURL URLWithString:self.urlString ?: @""];
	if (url)
		[self.webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
	[self.spinner startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
	[self.spinner stopAnimating];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
	[self.spinner stopAnimating];
}

@end
