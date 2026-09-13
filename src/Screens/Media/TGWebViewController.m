#import "TGWebViewController.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGClient+AppSettings.h"

static BOOL TGWVIsWebScheme(NSString *scheme) {
	NSString *lowered = scheme.lowercaseString;
	return [lowered isEqualToString:@"http"] || [lowered isEqualToString:@"https"];
}

@interface TGWebViewController ()
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation TGWebViewController

+ (UIViewController *)controllerForURLString:(NSString *)urlString {
	if (!urlString.length)
		return nil;
	NSURL *url = [NSURL URLWithString:urlString];
	if (!url)
		return nil;
	if (!TGWVIsWebScheme(url.scheme) || [[TGClient shared] shouldOpenExternallyForUrl:urlString])
		return nil;
	return [[TGWebViewController alloc] initWithURLString:urlString];
}

+ (BOOL)openURLString:(NSString *)urlString fromViewController:(UIViewController *)viewController {
	if (!urlString.length)
		return NO;
	TGWebViewController *browser = (TGWebViewController *)[self controllerForURLString:urlString];
	if (!browser) {
		NSURL *url = [NSURL URLWithString:urlString];
		if (!url)
			return NO;
		[[UIApplication sharedApplication] openURL:url];
		return YES;
	}

	if (viewController.navigationController)
		[viewController.navigationController pushViewController:browser animated:YES];
	else {
		UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:browser];
		browser.navigationItem.leftBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Done", @"Done") bold:YES
									   target:browser
									   action:@selector(closeTapped)];
		[viewController presentModalViewController:nav animated:YES];
	}
	return YES;
}

- (instancetype)initWithURLString:(NSString *)urlString {
	self = [super init];
	if (self) {
		_urlString = [urlString copy];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	TGTheme *theme = [TGTheme shared];
	[theme styleNavigationBar:self.navigationController.navigationBar];
	self.title = [NSURL URLWithString:self.urlString].host ?: @"";
	self.view.backgroundColor = [theme listBackgroundColour];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Web.OpenExternal", @"Open in Safari") bold:NO
									   target:self
									   action:@selector(openInSafari)];

	self.webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
	self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.webView.delegate = self;
	self.webView.scalesPageToFit = YES;
	[self.view addSubview:self.webView];

	self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	self.spinner.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
	self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
	[self.view addSubview:self.spinner];

	NSURL *url = [NSURL URLWithString:self.urlString ?: @""];
	if (url)
		[self.webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)closeTapped {
	[self dismissModalViewControllerAnimated:YES];
}

- (void)openInSafari {
	NSURLRequest *request = self.webView.request;
	NSURL *url = request.mainDocumentURL ?: request.URL;
	if (!url)
		url = [NSURL URLWithString:self.urlString ?: @""];
	if (url)
		[[UIApplication sharedApplication] openURL:url];
}

- (BOOL)webView:(UIWebView *)webView
	shouldStartLoadWithRequest:(NSURLRequest *)request
				navigationType:(UIWebViewNavigationType)navigationType {
	if (TGWVIsWebScheme(request.URL.scheme))
		return YES;
	if (request.URL && navigationType == UIWebViewNavigationTypeLinkClicked)
		[[UIApplication sharedApplication] openURL:request.URL];
	return NO;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
	[self.spinner startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
	[self.spinner stopAnimating];
	NSString *title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
	if (title.length)
		self.title = title;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
	[self.spinner stopAnimating];
}

@end
