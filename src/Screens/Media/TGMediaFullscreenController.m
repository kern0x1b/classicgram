#import "TGMediaFullscreenControllerInternal.h"
#import "TGMediaPageView.h"
#import "TGClient+Files.h"
#import "TGWebViewController.h"
#import "TGRemoteImageView.h"
#import "TGTheme.h"
#import "TGViewRecycler.h"

@implementation TGMediaFullscreenController

- (instancetype)initWithItems:(NSArray *)items index:(NSInteger)index {
	self = [super init];
	if (self) {
		_items = [NSMutableArray arrayWithArray:items ?: @[]];
		_startIndex = index;
		_currentIndex = index;
		_busyPageIndex = NSNotFound;
		_visiblePages = [[NSMutableDictionary alloc] init];
		_pagePool = [[NSMutableArray alloc] init];
		_imageCache = [[NSMutableDictionary alloc] init];
		_failedPages = [[NSMutableSet alloc] init];
		_prefetchedFiles = [[NSMutableSet alloc] init];
		self.modalPresentationStyle = UIModalPresentationFullScreen;
		self.wantsFullScreenLayout = YES;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = [UIColor blackColor];
	self.view.clipsToBounds = YES;

	[self buildPagingView];
	[self buildTopBar];
	[self buildBottomBar];
	[self buildCaptionPanel];
	[self buildOverlayAndGestures];

	[self layoutPagesPreservingIndex:_startIndex];
	[self updateChromeForCurrentItem];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	_statusBarWasHidden = [UIApplication sharedApplication].statusBarHidden;
	if (_statusBarWasHidden)
		[[UIApplication sharedApplication] setStatusBarHidden:NO
												withAnimation:UIStatusBarAnimationFade];
	[self installProgressHook];
	[self installBackgroundObserver];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[[UIApplication sharedApplication] setStatusBarHidden:_statusBarWasHidden
											withAnimation:UIStatusBarAnimationFade];
	[self removeProgressHook];
	[self removeBackgroundObserver];
	[self stopInlinePlayer];
	[self stopBurnCountdown];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	[self layoutTopBar];
	[self layoutPagesPreservingIndex:_currentIndex];
	[self layoutCaptionPanel];
}

- (BOOL)shouldAutorotate {
	return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
	return orientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (NSDictionary *)currentItem {
	if (_currentIndex < 0 || _currentIndex >= (NSInteger)_items.count)
		return nil;
	return _items[_currentIndex];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	for (NSNumber *key in _imageCache.allKeys) {
		if ([key integerValue] != _currentIndex)
			[_imageCache removeObjectForKey:key];
	}
	[_pagePool removeAllObjects];
}

- (void)dealloc {
	[_burnCountdownTimer invalidate];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (_inlinePlaybackDidFinishObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_inlinePlaybackDidFinishObserverToken];
	if (_backgroundObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_backgroundObserverToken];
	[_inlinePlayer stop];
	[_inlinePlayer.view removeFromSuperview];
	for (NSNumber *fileId in _prefetchedFiles)
		[[TGClient shared] cancelDownloadOfFile:[fileId longLongValue] onlyIfPending:YES];
	_pagingView.delegate = nil;
	for (NSNumber *key in _visiblePages.allKeys)
		[(TGMediaPageView *)_visiblePages[key] setDelegate:nil];
	for (TGMediaPageView *page in _pagePool)
		page.delegate = nil;
}

@end
