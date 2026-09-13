#import "TGTabBar.h"
#import "TGLocalization.h"

@interface TGTabBar ()

@property (nonatomic, strong) UIImageView *backgroundView;
@property (nonatomic, strong) UIImageView *selectedView;

@property (nonatomic, strong) NSMutableArray *allButtonViews;
@property (nonatomic, strong) NSMutableArray *allLabelViews;
@property (nonatomic, strong) NSMutableArray *buttonViews;
@property (nonatomic, strong) NSMutableArray *labelViews;

@property (nonatomic, strong) UIView *unreadBadgeContainer;
@property (nonatomic, strong) UIImageView *unreadBadgeBackground;
@property (nonatomic, strong) UILabel *unreadBadgeLabel;

@end

const int kTabIndexContacts = 0;
const int kTabIndexCalls = 1;
const int kTabIndexChats = 2;
const int kTabIndexSettings = 3;
const int kTabCount = 4;

NSString *const TGCallsTabVisibilityChangedNotification =
	@"TGCallsTabVisibilityChangedNotification";

static NSString *const TGCallsTabEnabledKey = @"TGShowCallsTab";

static const CGFloat kTabBarPadHeight = 56.0f;
static const CGFloat kTabBarPadItemWidth = 128.0f;
static const CGFloat kTabBarPadIconHeight = 36.0f;
static const CGFloat kTabBarPadLabelFontSize = 13.0f;

@implementation TGTabBar {
	int _unreadCount;
}

- (BOOL)isPadLayout {
	return NO;
}

- (CGFloat)barHeight {
	return [self isPadLayout] ? kTabBarPadHeight : 49.0f;
}

- (CGFloat)itemWidth {
	NSInteger count = self.buttonViews.count;
	CGFloat width = self.frame.size.width;
	if (count == 0 || width < 1)
		return 0;

	if ([self isPadLayout])
		return MIN(kTabBarPadItemWidth, floorf(width / count));

	float indicatorWidth = floorf(width / count);
	if (((int)indicatorWidth) % 2 != 0)
		indicatorWidth -= 1;
	return indicatorWidth;
}

- (CGFloat)groupLeft {
	NSInteger count = self.buttonViews.count;
	return floorf((self.frame.size.width - [self itemWidth] * count) / 2);
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		self.multipleTouchEnabled = false;
		self.exclusiveTouch = true;
		self.backgroundColor = [UIColor clearColor];
		self.opaque = NO;
		UIImage *rawBackgroundImage = [UIImage imageNamed:@"TabBarBackground"];
		if ([self isPadLayout] && rawBackgroundImage.size.width > 2)
			rawBackgroundImage = [rawBackgroundImage
				stretchableImageWithLeftCapWidth:(int)(rawBackgroundImage.size.width / 2)
									topCapHeight:0];
		self.backgroundView = [[UIImageView alloc] initWithImage:rawBackgroundImage];
		self.backgroundView.frame = self.bounds;
		[self addSubview:self.backgroundView];

		UIImage *rawSelectedImage = [UIImage imageNamed:@"TabBarSelected"];
		self.selectedView = [[UIImageView alloc] initWithImage:
				[rawSelectedImage stretchableImageWithLeftCapWidth:(int)(rawSelectedImage.size.width / 2) topCapHeight:0]];
		[self addSubview:self.selectedView];

		self.allButtonViews = [NSMutableArray array];
		self.allLabelViews = [NSMutableArray array];

		NSArray *names = @[ TGL(@"Contacts.Title", @"Contacts"), TGL(@"Calls.TabTitle", @"Calls"),
			TGL(@"DialogList.TabTitle", @"Chats"), TGL(@"Settings.Title", @"Settings") ];
		NSArray *icons = @[ @"TabIconContacts", @"TabIconCalls",
			@"TabIconMessages", @"TabIconSettings" ];

		for (NSInteger i = 0; i < names.count; i++) {
			UIImageView *icon = [[UIImageView alloc]
				   initWithImage:[UIImage imageNamed:icons[i]]
				highlightedImage:[UIImage imageNamed:[icons[i] stringByAppendingString:@"_Highlighted"]]];
			[self.allButtonViews addObject:icon];

			UILabel *label = [[UILabel alloc] init];
			label.backgroundColor = [UIColor clearColor];
			label.textColor = [UIColor colorWithRed:0x99 / 255.0f green:0x99 / 255.0f blue:0x99 / 255.0f alpha:1.0f];
			label.highlightedTextColor = [UIColor whiteColor];
			label.font = [UIFont boldSystemFontOfSize:
					[self isPadLayout] ? kTabBarPadLabelFontSize : 10.0f];
			label.text = names[i];
			[label sizeToFit];
			label.isAccessibilityElement = true;
			label.accessibilityLabel = names[i];
			label.accessibilityTraits = UIAccessibilityTraitButton;
			[self.allLabelViews addObject:label];
		}

		self.buttonViews = [NSMutableArray array];
		self.labelViews = [NSMutableArray array];
		_selectedIndex = kTabIndexChats;
		self.visibleTabs = [TGTabBar defaultVisibleTabs];

		_unreadCount = 0;
		[self updateAccessibility];
	}
	return self;
}

+ (BOOL)callsTabEnabled {
	id stored = [[NSUserDefaults standardUserDefaults] objectForKey:TGCallsTabEnabledKey];
	if (![stored respondsToSelector:@selector(boolValue)])
		return YES;
	return [stored boolValue];
}

+ (void)setCallsTabEnabled:(BOOL)enabled {
	if (enabled == [TGTabBar callsTabEnabled])
		return;
	[[NSUserDefaults standardUserDefaults] setBool:enabled forKey:TGCallsTabEnabledKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGCallsTabVisibilityChangedNotification
					  object:nil];
}

+ (NSArray *)defaultVisibleTabs {
	if ([TGTabBar callsTabEnabled])
		return @[ @(kTabIndexContacts), @(kTabIndexCalls),
			@(kTabIndexChats), @(kTabIndexSettings) ];
	return @[ @(kTabIndexContacts), @(kTabIndexChats), @(kTabIndexSettings) ];
}

- (void)setVisibleTabs:(NSArray *)visibleTabs {
	if (!visibleTabs.count)
		visibleTabs = [TGTabBar defaultVisibleTabs];
	if ([visibleTabs isEqualToArray:_visibleTabs])
		return;
	_visibleTabs = [visibleTabs copy];

	for (UIView *view in self.allButtonViews)
		[view removeFromSuperview];
	for (UIView *view in self.allLabelViews)
		[view removeFromSuperview];

	[self.buttonViews removeAllObjects];
	[self.labelViews removeAllObjects];

	for (NSNumber *tab in _visibleTabs) {
		NSInteger index = (NSUInteger)[tab intValue];
		if (index >= self.allButtonViews.count)
			continue;
		UIView *icon = self.allButtonViews[index];
		UIView *label = self.allLabelViews[index];
		[self addSubview:icon];
		[self addSubview:label];
		[self.buttonViews addObject:icon];
		[self.labelViews addObject:label];
	}

	if (self.unreadBadgeContainer != nil)
		[self bringSubviewToFront:self.unreadBadgeContainer];

	self.selectedIndex = _selectedIndex;
	[self setNeedsLayout];
}

- (int)slotForTab:(int)tab {
	NSInteger slot = [_visibleTabs indexOfObject:@(tab)];
	if (slot == NSNotFound)
		return -1;
	return (int)slot;
}

- (int)tabForSlot:(int)slot {
	if (slot < 0 || (NSUInteger)slot >= _visibleTabs.count)
		return -1;
	return [_visibleTabs[(NSUInteger)slot] intValue];
}

- (void)updateAccessibility {
	for (NSInteger i = 0; i < self.labelViews.count; i++) {
		UILabel *label = self.labelViews[i];
		NSInteger tab = [self tabForSlot:(int)i];
		UIAccessibilityTraits traits = UIAccessibilityTraitButton;
		if (tab == _selectedIndex)
			traits |= UIAccessibilityTraitSelected;
		label.accessibilityTraits = traits;
		label.accessibilityValue = (tab == kTabIndexChats && _unreadCount > 0)
			? TGLPlural(@"VoiceOver.Chat.UnreadMessages", _unreadCount,
				  @"%ld unread message", @"%ld unread messages")
			: nil;
	}
}

- (void)setFrame:(CGRect)frame {
	if ([self isPadLayout]) {
		CGFloat height = [self barHeight];
		frame.origin.y += frame.size.height - height;
		frame.size.height = height;
	}
	[super setFrame:frame];
}

- (void)layoutSelectedView {
	NSInteger count = self.buttonViews.count;
	CGFloat width = self.frame.size.width;
	if (count == 0 || width < 1)
		return;

	NSInteger slot = [self slotForTab:_selectedIndex];
	self.selectedView.hidden = slot < 0;
	if (slot < 0)
		return;

	float indicatorWidth = [self itemWidth];
	float paddingLeft = [self groupLeft];

	if ([self isPadLayout]) {
		self.selectedView.frame = CGRectMake(paddingLeft + indicatorWidth * slot,
			0, indicatorWidth, [self barHeight]);
		return;
	}

	float additionalWidth = 0;
	float additionalOffset = 0;
	if (slot == 0 || slot == (int)count - 1)
		additionalWidth += paddingLeft + 1;
	if (slot == 0)
		additionalOffset += -paddingLeft - 1;

	self.selectedView.frame = CGRectMake(paddingLeft + indicatorWidth * slot + additionalOffset,
		0, indicatorWidth + additionalWidth, 49);
}

- (int)indexForLocation:(CGPoint)location {
	NSInteger count = self.buttonViews.count;
	if (count == 0)
		return -1;

	if ([self isPadLayout]) {
		CGFloat itemWidth = [self itemWidth];
		if (itemWidth < 1)
			return -1;
		CGFloat offset = location.x - [self groupLeft];
		if (offset < 0 || offset >= itemWidth * count)
			return -1;
		return (int)(offset / itemWidth);
	}

	return MAX(0, MIN((int)count - 1, (int)(location.x / (self.frame.size.width / count))));
}

- (void)setSelectedIndex:(int)selectedIndex {
	for (UIImageView *icon in self.allButtonViews)
		icon.highlighted = false;
	for (UILabel *label in self.allLabelViews)
		label.highlighted = false;

	if ([self slotForTab:selectedIndex] < 0 && _visibleTabs.count)
		selectedIndex = kTabIndexChats;

	_selectedIndex = selectedIndex;
	[self layoutSelectedView];
	[self setNeedsLayout];

	NSInteger slot = [self slotForTab:_selectedIndex];
	if (slot >= 0) {
		((UIImageView *)self.buttonViews[(NSUInteger)slot]).highlighted = true;
		((UILabel *)self.labelViews[(NSUInteger)slot]).highlighted = true;
	}

	[self updateAccessibility];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	[super touchesBegan:touches withEvent:event];

	UITouch *touch = [touches anyObject];
	if (touch == nil || self.buttonViews.count == 0)
		return;

	NSInteger tab = [self tabForSlot:[self indexForLocation:[touch locationInView:self]]];
	if (tab < 0)
		return;

	self.selectedIndex = tab;

	if ([self.tabDelegate respondsToSelector:@selector(tabBarSelectedItem:)])
		[self.tabDelegate tabBarSelectedItem:tab];
}

- (void)loadUnreadBadgeView {
	if (self.unreadBadgeContainer != nil)
		return;

	self.unreadBadgeContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
	self.unreadBadgeContainer.hidden = true;
	self.unreadBadgeContainer.userInteractionEnabled = false;
	self.unreadBadgeContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[self addSubview:self.unreadBadgeContainer];

	UIImage *badgeBackground = [UIImage imageNamed:@"TabBarBadge"];
	self.unreadBadgeBackground = [[UIImageView alloc] initWithImage:
			[badgeBackground stretchableImageWithLeftCapWidth:10 topCapHeight:0]];
	[self.unreadBadgeContainer addSubview:self.unreadBadgeBackground];

	CGFloat retinaPixel = [UIScreen mainScreen].scale > 1 ? 0.5f : 0.0f;

	self.unreadBadgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(9, 4 + retinaPixel, 28 + retinaPixel, 10)];
	self.unreadBadgeLabel.backgroundColor = [UIColor clearColor];
	self.unreadBadgeLabel.textColor = [UIColor whiteColor];
	self.unreadBadgeLabel.font = [UIFont boldSystemFontOfSize:11];
	[self.unreadBadgeContainer addSubview:self.unreadBadgeLabel];

	[self setNeedsLayout];
}

- (void)setUnreadCount:(int)unreadCount {
	if (unreadCount < 0)
		unreadCount = 0;

	_unreadCount = unreadCount;
	[self updateAccessibility];

	if (unreadCount <= 0 && self.unreadBadgeLabel == nil)
		return;

	[self loadUnreadBadgeView];

	if (unreadCount <= 0) {
		self.unreadBadgeLabel.text = nil;
		self.unreadBadgeContainer.hidden = true;
		return;
	}

	NSString *text;
	if (unreadCount < 1000)
		text = [NSString stringWithFormat:@"%d", unreadCount];
	else if (unreadCount < 1000000)
		text = [NSString stringWithFormat:@"%dK", unreadCount / 1000];
	else
		text = [NSString stringWithFormat:@"%dM", unreadCount / 1000000];

	CGFloat retinaPixel = [UIScreen mainScreen].scale > 1 ? 0.5f : 0.0f;

	self.unreadBadgeLabel.text = text;
	self.unreadBadgeContainer.hidden = false;

	CGRect frame = self.unreadBadgeBackground.frame;
	int textWidth = (int)[text sizeWithFont:self.unreadBadgeLabel.font
						  constrainedToSize:self.unreadBadgeLabel.bounds.size
							  lineBreakMode:NSLineBreakByTruncatingTail]
						.width;
	frame.size.width = MAX(20, textWidth + 12 + retinaPixel * 2);
	frame.origin.x = self.unreadBadgeBackground.superview.frame.size.width - frame.size.width;
	self.unreadBadgeBackground.frame = frame;

	CGRect labelFrame = self.unreadBadgeLabel.frame;
	labelFrame.origin.x = 6 + retinaPixel + frame.origin.x;
	self.unreadBadgeLabel.frame = labelFrame;
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGSize viewSize = self.frame.size;
	self.backgroundView.frame = CGRectMake(0, 0, viewSize.width, viewSize.height);

	NSInteger count = self.buttonViews.count;
	if (count == 0 || viewSize.width < 1)
		return;

	float indicatorWidth = [self itemWidth];
	float paddingLeft = [self groupLeft];
	BOOL pad = [self isPadLayout];
	[self layoutSelectedView];

	NSInteger index = -1;
	for (UIImageView *iconView in self.buttonViews) {
		index++;

		CGRect frame = iconView.frame;
		if (pad) {
			CGSize imageSize = iconView.image.size;
			if (imageSize.height > 0) {
				CGFloat scale = kTabBarPadIconHeight / imageSize.height;
				frame.size = CGSizeMake(floorf(imageSize.width * scale), floorf(imageSize.height * scale));
			}
		}
		frame.origin.x = paddingLeft + index * indicatorWidth + floorf((indicatorWidth - frame.size.width) / 2);
		frame.origin.y = pad ? 1 : 4;
		iconView.frame = frame;

		if ([self tabForSlot:index] == kTabIndexChats && self.unreadBadgeContainer != nil) {
			CGRect unreadBadgeContainerFrame = self.unreadBadgeContainer.frame;
			unreadBadgeContainerFrame.origin.x = frame.origin.x + frame.size.width - 9;
			unreadBadgeContainerFrame.origin.y = pad ? 0 : 2;
			self.unreadBadgeContainer.frame = unreadBadgeContainerFrame;
		}

		UILabel *labelView = self.labelViews[index];
		CGRect labelFrame = labelView.frame;
		labelFrame.origin.x = paddingLeft + index * indicatorWidth + floorf((indicatorWidth - labelFrame.size.width) / 2);
		labelFrame.origin.y = pad ? floorf(viewSize.height - labelFrame.size.height - 2) : 35;
		labelView.frame = labelFrame;
	}
}

@end
