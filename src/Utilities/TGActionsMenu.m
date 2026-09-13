#import "TGActionsMenu.h"
#import "TGLocalization.h"
#import "TGFolderStore.h"
#import <QuartzCore/QuartzCore.h>

NSString *const TGActionsMenuSelectList = @"selectList";
NSString *const TGActionsMenuAddStory = @"addStory";
NSString *const TGActionsMenuMarkAllRead = @"markAllRead";
NSString *const TGActionsMenuEditFolders = @"editFolders";

static NSString *const TGActionsMenuOpenFolders = @"openFolders";
static NSString *const TGActionsMenuMoreFolders = @"moreFolders";

static const CGFloat kMenuHeight = 41.0f;
static const CGFloat kMenuTitlePadding = 34.0f;
static const CGFloat kMenuLineInset = 10.0f;
static const CGFloat kMenuEdgeMargin = 4.0f;
static const CGFloat kMenuGapAbove = 14.0f;
static const CGFloat kMenuGapBelow = 17.0f;
static const NSUInteger kMenuMaxButtons = 4;
static const NSUInteger kMenuFolderWindow = 3;

@protocol TGActionsMenuButtonDelegate <NSObject>
- (void)menuButtonHighlightChanged;
@end

@interface TGActionsMenuButton : UIButton

@property (nonatomic, weak) id<TGActionsMenuButtonDelegate> delegate;

@property (nonatomic, strong) UIImageView *leftView;
@property (nonatomic, strong) UIImageView *centerView;
@property (nonatomic, strong) UIImageView *rightView;

@property (nonatomic, strong) UIImageView *topLeftView;
@property (nonatomic, strong) UIImageView *topRightView;
@property (nonatomic, strong) UIImageView *bottomLeftView;
@property (nonatomic, strong) UIImageView *bottomRightView;

@end

@implementation TGActionsMenuButton

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		_leftView = [[UIImageView alloc] init];
		[self addSubview:_leftView];
		_centerView = [[UIImageView alloc] init];
		[self addSubview:_centerView];
		_rightView = [[UIImageView alloc] init];
		[self addSubview:_rightView];

		UIImage *topImage = [UIImage imageNamed:@"MenuButtonTopLine.png"];
		UIImage *bottomImage = [UIImage imageNamed:@"MenuButtonBottomLine.png"];
		UIImage *topHighlighted = [UIImage imageNamed:@"MenuButtonTopLine_Highlighted.png"];
		UIImage *bottomHighlighted = [UIImage imageNamed:@"MenuButtonBottomLine_Highlighted.png"];

		_topLeftView = [[UIImageView alloc] initWithImage:topImage highlightedImage:topHighlighted];
		[self addSubview:_topLeftView];
		_topRightView = [[UIImageView alloc] initWithImage:topImage highlightedImage:topHighlighted];
		[self addSubview:_topRightView];
		_bottomLeftView = [[UIImageView alloc] initWithImage:bottomImage highlightedImage:bottomHighlighted];
		[self addSubview:_bottomLeftView];
		_bottomRightView = [[UIImageView alloc] initWithImage:bottomImage highlightedImage:bottomHighlighted];
		[self addSubview:_bottomRightView];
	}
	return self;
}

- (void)applyHighlight:(BOOL)highlighted {
	_topLeftView.highlighted = highlighted;
	_topRightView.highlighted = highlighted;
	_bottomLeftView.highlighted = highlighted;
	_bottomRightView.highlighted = highlighted;
	_leftView.highlighted = highlighted;
	_centerView.highlighted = highlighted;
	_rightView.highlighted = highlighted;
}

- (void)setHighlighted:(BOOL)highlighted {
	[super setHighlighted:highlighted];
	id<TGActionsMenuButtonDelegate> delegate = _delegate;
	[delegate menuButtonHighlightChanged];
	[self applyHighlight:highlighted || self.selected];
}

- (void)setSelected:(BOOL)selected {
	[super setSelected:selected];
	id<TGActionsMenuButtonDelegate> delegate = _delegate;
	[delegate menuButtonHighlightChanged];
	[self applyHighlight:selected || self.highlighted];
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGSize size = self.bounds.size;
	CGFloat leftWidth = _leftView.image.size.width;
	CGFloat rightWidth = _rightView.image.size.width;

	_leftView.frame = CGRectMake(0, 0, leftWidth, size.height);
	_rightView.frame = CGRectMake(size.width - rightWidth, 0, rightWidth, size.height);
	_centerView.frame = CGRectMake(leftWidth, 0, MAX(0.0f, size.width - leftWidth - rightWidth), size.height);

	[self bringSubviewToFront:_topLeftView];
	[self bringSubviewToFront:_topRightView];
	[self bringSubviewToFront:_bottomLeftView];
	[self bringSubviewToFront:_bottomRightView];
	[self bringSubviewToFront:self.titleLabel];
}

@end

@interface TGActionsMenuView : UIView <TGActionsMenuButtonDelegate>

+ (void)showFromRect:(CGRect)rect
			  inView:(UIView *)host
	 currentFolderId:(NSInteger)currentFolderId
		titleForList:(NSString * (^)(NSInteger listId, NSString *title))titleForList
			onAction:(void (^)(NSString *action, NSInteger folderId))onAction;

- (void)externalDismiss;

@end

static TGActionsMenuView *sOpenMenu = nil;

@implementation TGActionsMenuView {
	UIView *_card;
	NSArray *_items;
	NSMutableArray *_buttons;
	NSMutableArray *_separators;
	UIImageView *_arrowTopView;
	UIImageView *_arrowBottomView;
	CGFloat _arrowLocation;
	BOOL _arrowOnTop;
	CGRect _anchorRect;
	CGSize _hostSize;
	BOOL _dismissed;

	NSInteger _currentFolderId;
	NSUInteger _folderOffset;
	BOOL _showingFolders;
	NSString * (^_titleForList)(NSInteger, NSString *);
	id _backgroundDismissObserverToken;
	id _orientationDismissObserverToken;
	void (^_onAction)(NSString *, NSInteger);
}

#pragma mark - items

- (NSString *)decoratedTitle:(NSString *)title forList:(NSInteger)listId {
	NSString *result = title;
	if (_titleForList != nil) {
		NSString *decorated = _titleForList(listId, title);
		if ([decorated isKindOfClass:[NSString class]] && decorated.length != 0)
			result = decorated;
	}
	return result;
}

- (NSArray *)rootItems {
	return @[ @{@"title" : TGL(@"ChatListFolderSettings.Title", @"Folders"), @"action" : TGActionsMenuOpenFolders},
		@{@"title" : TGL(@"StoryFeed.ContextAddStory", @"Add Story"), @"action" : TGActionsMenuAddStory},
		@{@"title" : TGL(@"ChatList.ReadAll", @"Read All"), @"action" : TGActionsMenuMarkAllRead} ];
}

- (NSArray *)allFolderItems {
	NSMutableArray *items = [[NSMutableArray alloc] init];

	[items addObject:@{@"title" : [self decoratedTitle:TGL(@"HashtagSearch.AllChats", @"All Chats") forList:0],
		@"action" : TGActionsMenuSelectList,
		@"folder" : @0,
		@"current" : [NSNumber numberWithBool:_currentFolderId == 0]}];

	NSArray *folders = [TGFolderStore folders];
	if (![folders isKindOfClass:[NSArray class]])
		folders = @[];

	for (id raw in folders) {
		if (![raw isKindOfClass:[NSDictionary class]])
			continue;
		NSDictionary *folder = raw;
		NSInteger listId = [folder[@"id"] integerValue];
		NSString *title = folder[@"title"];
		if (![title isKindOfClass:[NSString class]] || title.length == 0)
			title = TGL(@"ChatListFolder.DefaultTitle", @"Folder");
		[items addObject:@{@"title" : [self decoratedTitle:title forList:listId],
			@"action" : TGActionsMenuSelectList,
			@"folder" : [NSNumber numberWithInteger:listId],
			@"current" : [NSNumber numberWithBool:listId == _currentFolderId]}];
	}

	[items addObject:@{@"title" : folders.count != 0 ? TGL(@"Common.Edit", @"Edit") : TGL(@"ChatListFolder.TitleCreate", @"New Folder"),
		@"action" : TGActionsMenuEditFolders}];

	return items;
}

- (NSArray *)folderPageItems {
	NSArray *all = [self allFolderItems];
	if (all.count <= kMenuMaxButtons) {
		_folderOffset = 0;
		return all;
	}

	if (_folderOffset >= all.count)
		_folderOffset = 0;

	NSMutableArray *page = [[NSMutableArray alloc] init];
	for (NSInteger i = _folderOffset; i < all.count && page.count < kMenuFolderWindow; i++)
		[page addObject:[all objectAtIndex:i]];

	[page addObject:@{@"title" : TGL(@"Common.More", @"More"), @"action" : TGActionsMenuMoreFolders}];
	return page;
}

- (NSArray *)currentPageItems {
	return _showingFolders ? [self folderPageItems] : [self rootItems];
}

#pragma mark - lifecycle

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		self.backgroundColor = [UIColor clearColor];
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

		_buttons = [[NSMutableArray alloc] init];
		_separators = [[NSMutableArray alloc] init];
		_arrowLocation = 50.0f;

		_card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, kMenuHeight)];
		_card.backgroundColor = [UIColor clearColor];
		[self addSubview:_card];

		_arrowTopView = [[UIImageView alloc]
			   initWithImage:[UIImage imageNamed:@"MenuArrowTop.png"]
			highlightedImage:[UIImage imageNamed:@"MenuArrowTop_Highlighted.png"]];
		[_card addSubview:_arrowTopView];

		_arrowBottomView = [[UIImageView alloc]
			   initWithImage:[UIImage imageNamed:@"MenuArrowBottom.png"]
			highlightedImage:[UIImage imageNamed:@"MenuArrowBottom_Highlighted.png"]];
		[_card addSubview:_arrowBottomView];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (_backgroundDismissObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_backgroundDismissObserverToken];
	if (_orientationDismissObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_orientationDismissObserverToken];
}

- (void)externalDismiss {
	if (sOpenMenu == self)
		sOpenMenu = nil;
	[self teardownAnimated:YES];
}

- (void)hostNotification:(NSNotification *)notification {
	[self externalDismiss];
}

- (void)teardownAnimated:(BOOL)animated {
	if (_dismissed)
		return;
	_dismissed = YES;
	_onAction = nil;
	_titleForList = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (_backgroundDismissObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:_backgroundDismissObserverToken];
		_backgroundDismissObserverToken = nil;
	}
	if (_orientationDismissObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:_orientationDismissObserverToken];
		_orientationDismissObserverToken = nil;
	}
	self.userInteractionEnabled = NO;

	if (!animated) {
		[self removeFromSuperview];
		return;
	}

	UIView *card = _card;
	__weak TGActionsMenuView *weakSelf = self;
	[UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState
		animations:^{
			card.alpha = 0.0f;
		} completion:^(BOOL finished) {
			card.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
			[weakSelf removeFromSuperview];
		}];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	if (_dismissed)
		return;
	CGSize size = self.bounds.size;
	if (_hostSize.width > 0 &&
		(fabs(size.width - _hostSize.width) > 0.5f || fabs(size.height - _hostSize.height) > 0.5f)) {
		if (sOpenMenu == self)
			sOpenMenu = nil;
		[self teardownAnimated:NO];
	}
}

#pragma mark - building

- (NSArray *)buttonWidthsWithFont:(UIFont *)titleFont {
	CGFloat maximumWidth = MAX(60.0f, self.bounds.size.width - kMenuEdgeMargin * 2.0f);

	NSMutableArray *widths = [[NSMutableArray alloc] init];
	CGFloat naturalWidth = 0;
	for (NSInteger i = 0; i < _items.count; i++) {
		NSString *title = [[_items objectAtIndex:i] objectForKey:@"title"];
		CGFloat width = [title sizeWithFont:titleFont].width + kMenuTitlePadding;
		if (i == 0 || i == _items.count - 1)
			width += 1;
		width = floorf(width);
		naturalWidth += width;
		[widths addObject:[NSNumber numberWithFloat:width]];
	}

	if (naturalWidth > maximumWidth) {
		CGFloat scale = maximumWidth / naturalWidth;
		CGFloat used = 0;
		for (NSInteger i = 0; i < widths.count; i++) {
			CGFloat width = floorf([[widths objectAtIndex:i] floatValue] * scale);
			if (width < 24.0f)
				width = 24.0f;
			if (i == widths.count - 1 && used + width < maximumWidth)
				width = floorf(maximumWidth - used);
			used += width;
			[widths replaceObjectAtIndex:i withObject:[NSNumber numberWithFloat:width]];
		}
	}

	return widths;
}

- (void)buildPage {
	for (TGActionsMenuButton *button in _buttons) {
		button.delegate = nil;
		[button removeFromSuperview];
	}
	[_buttons removeAllObjects];
	for (UIView *separator in _separators)
		[separator removeFromSuperview];
	[_separators removeAllObjects];

	_items = [self currentPageItems];

	UIImage *rawLeftImage = [UIImage imageNamed:@"MenuButtonLeft.png"];
	UIImage *leftImage = [rawLeftImage stretchableImageWithLeftCapWidth:(int)(rawLeftImage.size.width - 1) topCapHeight:0];
	UIImage *rightImage = [[UIImage imageNamed:@"MenuButtonRight.png"] stretchableImageWithLeftCapWidth:0 topCapHeight:0];
	UIImage *rawCenterImage = [UIImage imageNamed:@"MenuButtonCenter.png"];
	UIImage *centerImage = [rawCenterImage stretchableImageWithLeftCapWidth:(int)(rawCenterImage.size.width / 2) topCapHeight:0];

	UIImage *rawLeftHighlighted = [UIImage imageNamed:@"MenuButtonLeft_Highlighted.png"];
	UIImage *leftHighlightedImage = [rawLeftHighlighted stretchableImageWithLeftCapWidth:(int)(rawLeftHighlighted.size.width - 1) topCapHeight:0];
	UIImage *rightHighlightedImage = [[UIImage imageNamed:@"MenuButtonRight_Highlighted.png"] stretchableImageWithLeftCapWidth:0 topCapHeight:0];
	UIImage *rawCenterHighlighted = [UIImage imageNamed:@"MenuButtonCenter_Highlighted.png"];
	UIImage *centerHighlightedImage = [rawCenterHighlighted stretchableImageWithLeftCapWidth:(int)(rawCenterHighlighted.size.width / 2) topCapHeight:0];

	UIImage *separatorImage = [UIImage imageNamed:@"MenuButtonSeparator.png"];

	UIFont *titleFont = [UIFont boldSystemFontOfSize:14];

	NSArray *widths = [self buttonWidthsWithFont:titleFont];

	UIColor *shadowNormal = [UIColor colorWithWhite:0.0f alpha:0.8f];
	UIColor *shadowHighlighted = [UIColor colorWithRed:0x18 / 255.0f green:0x6b / 255.0f blue:0xcb / 255.0f alpha:0.6f];

	CGFloat totalWidth = 0;

	for (NSInteger i = 0; i < _items.count; i++) {
		NSString *title = [[_items objectAtIndex:i] objectForKey:@"title"];

		TGActionsMenuButton *button = [[TGActionsMenuButton alloc] initWithFrame:CGRectZero];
		button.tag = (NSInteger)i;
		button.delegate = self;
		button.titleLabel.font = titleFont;
		button.titleLabel.shadowOffset = CGSizeMake(0, -1);
		button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
		button.exclusiveTouch = YES;
		[button setTitle:title forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		[button setTitleColor:[UIColor colorWithWhite:1.0f alpha:0.5f] forState:UIControlStateDisabled];
		[button setTitleShadowColor:shadowNormal forState:UIControlStateNormal];
		[button setTitleShadowColor:shadowHighlighted forState:UIControlStateHighlighted];
		[button setTitleShadowColor:shadowHighlighted forState:UIControlStateSelected];
		[button setTitleShadowColor:shadowHighlighted forState:UIControlStateHighlighted | UIControlStateSelected];
		[button addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];

		button.centerView.image = centerImage;
		button.centerView.highlightedImage = centerHighlightedImage;
		button.leftView.image = centerImage;
		button.leftView.highlightedImage = centerHighlightedImage;
		button.rightView.image = centerImage;
		button.rightView.highlightedImage = centerHighlightedImage;

		UIEdgeInsets titleInset = UIEdgeInsetsMake(0, 0, 0, 0);
		if (i == 0) {
			button.leftView.image = leftImage;
			button.leftView.highlightedImage = leftHighlightedImage;
			titleInset.left += 2;
		}
		if (i == _items.count - 1) {
			button.rightView.image = rightImage;
			button.rightView.highlightedImage = rightHighlightedImage;
			titleInset.right += 2;
		}
		button.titleEdgeInsets = titleInset;

		CGFloat width = [[widths objectAtIndex:i] floatValue];
		button.frame = CGRectMake(totalWidth, 0, width, kMenuHeight);
		totalWidth += width;

		[_card addSubview:button];
		[_buttons addObject:button];

		if ([[[_items objectAtIndex:i] objectForKey:@"current"] boolValue])
			button.selected = YES;

		if (i > 0) {
			UIImageView *separator = [[UIImageView alloc] initWithImage:separatorImage];
			[_card addSubview:separator];
			[_separators addObject:separator];
		}
	}

	CGRect cardFrame = _card.frame;
	cardFrame.size.width = totalWidth;
	cardFrame.size.height = kMenuHeight;
	_card.frame = cardFrame;

	[_card bringSubviewToFront:_arrowTopView];
	[_card bringSubviewToFront:_arrowBottomView];

	[self positionCard];
	[self layoutCard];
}

- (void)positionCard {
	CGRect frame = _card.frame;
	CGRect rect = _anchorRect;

	frame.origin.x = floorf(rect.origin.x + rect.size.width / 2 - frame.size.width / 2);
	if (frame.origin.x < kMenuEdgeMargin)
		frame.origin.x = kMenuEdgeMargin;
	if (frame.origin.x + frame.size.width > self.bounds.size.width - kMenuEdgeMargin)
		frame.origin.x = self.bounds.size.width - kMenuEdgeMargin - frame.size.width;

	frame.origin.y = rect.origin.y - frame.size.height - kMenuGapAbove;
	if (frame.origin.y < 2.0f) {
		frame.origin.y = rect.origin.y + rect.size.height + kMenuGapBelow;
		if (frame.origin.y + frame.size.height > self.bounds.size.height - kMenuGapAbove) {
			frame.origin.y = floorf((self.bounds.size.height - frame.size.height) / 2);
			_arrowOnTop = NO;
		} else
			_arrowOnTop = YES;
	} else
		_arrowOnTop = NO;

	_arrowLocation = floorf(rect.origin.x + rect.size.width / 2) - frame.origin.x;

	_card.layer.anchorPoint = CGPointMake(MAX(0.0f, MIN(1.0f, _arrowLocation / MAX(1.0f, frame.size.width))),
		_arrowOnTop ? -0.2f : 1.2f);
	_card.frame = frame;
}

- (BOOL)buttonContainsArrow:(TGActionsMenuButton *)button atIndex:(NSUInteger)index {
	BOOL containsArrow = _arrowLocation >= button.frame.origin.x &&
		_arrowLocation < button.frame.origin.x + button.frame.size.width;
	if (index == 0 && _arrowLocation < button.frame.size.width)
		containsArrow = YES;
	if (index == _buttons.count - 1 && _arrowLocation >= button.frame.origin.x)
		containsArrow = YES;
	return containsArrow;
}

- (void)menuButtonHighlightChanged {
	BOOL arrowHighlighted = NO;
	for (NSInteger index = 0; index < _buttons.count; index++) {
		TGActionsMenuButton *button = [_buttons objectAtIndex:index];
		if (button.highlighted || button.selected) {
			arrowHighlighted = [self buttonContainsArrow:button atIndex:index];
			break;
		}
	}
	_arrowTopView.highlighted = arrowHighlighted;
	_arrowBottomView.highlighted = arrowHighlighted;
}

- (void)layoutCard {
	NSInteger count = _buttons.count;
	CGFloat arrowWidth = _arrowTopView.image.size.width;

	for (NSInteger index = 0; index < count; index++) {
		TGActionsMenuButton *button = [_buttons objectAtIndex:index];
		[button layoutSubviews];

		CGFloat linePosition = 0.0f;
		CGFloat lineWidth = button.frame.size.width;

		if (index > 0) {
			UIImageView *separator = [_separators objectAtIndex:index - 1];
			separator.frame = CGRectMake(button.frame.origin.x - 1, 2,
				separator.image.size.width, kMenuHeight - 5);
		}

		BOOL containsArrow = [self buttonContainsArrow:button atIndex:index];

		if (index == 0) {
			linePosition += kMenuLineInset;
			lineWidth -= kMenuLineInset;
		}
		if (index == count - 1)
			lineWidth -= kMenuLineInset;

		if (containsArrow) {
			CGFloat minArrowX = button.frame.origin.x + (index == 0 ? kMenuLineInset : 0.0f);
			CGFloat maxArrowX = button.frame.origin.x + button.frame.size.width - arrowWidth +
				(index == count - 1 ? -kMenuLineInset : 0.0f);
			CGFloat arrowX = floorf(_arrowLocation - arrowWidth / 2.0f);
			arrowX = MIN(MAX(minArrowX, arrowX), maxArrowX);

			_arrowTopView.frame = CGRectMake(arrowX, -9,
				arrowWidth, _arrowTopView.image.size.height);
			_arrowBottomView.frame = CGRectMake(arrowX, kMenuHeight - 4,
				_arrowBottomView.image.size.width,
				_arrowBottomView.image.size.height);
		}

		CGFloat topLineHeight = button.topLeftView.image.size.height;
		CGFloat bottomLineHeight = button.bottomLeftView.image.size.height;

		if (!_arrowOnTop || !containsArrow) {
			button.topLeftView.frame = CGRectMake(linePosition, 0, lineWidth, topLineHeight);
			button.topRightView.frame = CGRectMake(linePosition, 0, 0, topLineHeight);
		} else {
			CGFloat firstWidth = MAX(0.0f, _arrowTopView.frame.origin.x - button.frame.origin.x - linePosition);
			button.topLeftView.frame = CGRectMake(linePosition, 0, firstWidth, topLineHeight);
			CGFloat secondPosition = MIN(linePosition + lineWidth, linePosition + firstWidth + arrowWidth);
			button.topRightView.frame = CGRectMake(secondPosition, 0,
				MAX(0.0f, linePosition + lineWidth - secondPosition),
				topLineHeight);
		}

		if (_arrowOnTop || !containsArrow) {
			button.bottomLeftView.frame = CGRectMake(linePosition, kMenuHeight - 4, lineWidth, bottomLineHeight);
			button.bottomRightView.frame = CGRectMake(linePosition, kMenuHeight - 4, 0, bottomLineHeight);
		} else {
			CGFloat firstWidth = MAX(0.0f, _arrowBottomView.frame.origin.x - button.frame.origin.x - linePosition);
			button.bottomLeftView.frame = CGRectMake(linePosition, kMenuHeight - 4, firstWidth, bottomLineHeight);
			CGFloat secondPosition = MIN(linePosition + lineWidth, linePosition + firstWidth + arrowWidth);
			button.bottomRightView.frame = CGRectMake(secondPosition, kMenuHeight - 4,
				MAX(0.0f, linePosition + lineWidth - secondPosition),
				bottomLineHeight);
		}
	}

	_arrowTopView.hidden = !_arrowOnTop;
	_arrowBottomView.hidden = _arrowOnTop;
}

#pragma mark - presentation

- (void)present {
	_card.alpha = 1.0f;
	_card.transform = CGAffineTransformMakeScale(0.1f, 0.1f);

	if ([_card.layer respondsToSelector:@selector(setRasterizationScale:)])
		_card.layer.rasterizationScale = [[UIScreen mainScreen] scale];
	_card.layer.shouldRasterize = YES;

	UIView *card = _card;
	[UIView animateWithDuration:0.142 delay:0
		options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
		animations:^{
			card.transform = CGAffineTransformMakeScale(1.07f, 1.07f);
		} completion:^(BOOL finished) {
			if (!finished)
				return;
			[UIView animateWithDuration:0.08 delay:0
				options:UIViewAnimationOptionBeginFromCurrentState
				animations:^{
					card.transform = CGAffineTransformMakeScale(0.967f, 0.967f);
				} completion:^(BOOL finishedInner) {
					if (!finishedInner)
						return;
					[UIView animateWithDuration:0.06 delay:0
						options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
						animations:^{
							card.transform = CGAffineTransformIdentity;
						} completion:^(BOOL finishedLast) {
							if (finishedLast)
								card.layer.shouldRasterize = NO;
						}];
				}];
		}];
}

- (void)turnToPage {
	UIView *card = _card;
	__weak TGActionsMenuView *weakSelf = self;
	[UIView animateWithDuration:0.1 delay:0 options:UIViewAnimationOptionBeginFromCurrentState
		animations:^{
			card.alpha = 0.0f;
		} completion:^(BOOL finished) {
			TGActionsMenuView *strongSelf = weakSelf;
			if (strongSelf == nil || strongSelf->_dismissed)
				return;
			[strongSelf buildPage];
			card.transform = CGAffineTransformIdentity;
			[UIView animateWithDuration:0.12 delay:0 options:UIViewAnimationOptionBeginFromCurrentState
							 animations:^{
								 card.alpha = 1.0f;
							 }
							 completion:nil];
		}];
}

- (void)rowTapped:(TGActionsMenuButton *)row {
	if (_dismissed)
		return;
	NSInteger index = row.tag;
	if (index < 0 || (NSUInteger)index >= _items.count)
		return;

	NSDictionary *item = [_items objectAtIndex:(NSUInteger)index];
	NSString *action = [item objectForKey:@"action"];

	if ([action isEqualToString:TGActionsMenuOpenFolders]) {
		row.selected = YES;
		_showingFolders = YES;
		_folderOffset = 0;
		[self turnToPage];
		return;
	}

	if ([action isEqualToString:TGActionsMenuMoreFolders]) {
		row.selected = YES;
		_folderOffset += kMenuFolderWindow;
		[self turnToPage];
		return;
	}

	row.selected = YES;

	NSInteger folderId = [[item objectForKey:@"folder"] integerValue];
	void (^handler)(NSString *, NSInteger) = _onAction;
	[self externalDismiss];
	if (handler != nil)
		handler(action, folderId);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
	UIView *result = [super hitTest:point withEvent:event];
	if (_dismissed)
		return result;
	if (result == self || result == nil) {
		[self externalDismiss];
		return nil;
	}
	return result;
}

#pragma mark - entry

+ (void)showFromRect:(CGRect)rect
			  inView:(UIView *)host
	 currentFolderId:(NSInteger)currentFolderId
		titleForList:(NSString * (^)(NSInteger, NSString *))titleForList
			onAction:(void (^)(NSString *, NSInteger))onAction {
	if (host == nil)
		return;

	CGRect hostBounds = host.bounds;
	if (hostBounds.size.width < 20.0f || hostBounds.size.height < 20.0f)
		return;

	BOOL wasOpen = (sOpenMenu != nil);
	[sOpenMenu externalDismiss];
	if (wasOpen)
		return;

	TGActionsMenuView *menu = [[TGActionsMenuView alloc] initWithFrame:hostBounds];
	menu->_hostSize = hostBounds.size;
	menu->_anchorRect = rect;
	menu->_currentFolderId = currentFolderId;
	menu->_titleForList = [titleForList copy];
	menu->_onAction = [onAction copy];
	[menu buildPage];

	[host addSubview:menu];
	sOpenMenu = menu;

	__weak TGActionsMenuView *weakMenu = menu;
	menu->_backgroundDismissObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIApplicationDidEnterBackgroundNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong TGActionsMenuView *strongMenu = weakMenu;
					if (!strongMenu)
						return;
					[strongMenu hostNotification:note];
				}];
	menu->_orientationDismissObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIApplicationWillChangeStatusBarOrientationNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong TGActionsMenuView *strongMenu = weakMenu;
					if (!strongMenu)
						return;
					[strongMenu hostNotification:note];
				}];

	[menu present];
}

@end

@implementation TGActionsMenu

+ (void)showFromRect:(CGRect)rect
			  inView:(UIView *)host
	 currentFolderId:(NSInteger)currentFolderId
		titleForList:(NSString * (^)(NSInteger, NSString *))titleForList
			onAction:(void (^)(NSString *, NSInteger))onAction {
	[TGActionsMenuView showFromRect:rect
							 inView:host
					currentFolderId:currentFolderId
					   titleForList:titleForList
						   onAction:onAction];
}

+ (void)dismiss {
	[sOpenMenu externalDismiss];
}

+ (BOOL)isVisible {
	return sOpenMenu != nil;
}

@end
