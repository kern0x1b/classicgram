#import "TGReactionPickerView.h"
#import "TGReactionPickerViewInternal.h"

#import "TGReactionService.h"

#import <QuartzCore/QuartzCore.h>

const CGFloat kStripHeight = 41.0f;
const CGFloat kStripButtonWidth = 44.0f;
const CGFloat kStripVisibleButtons = 6.0f;
const CGFloat kStripEmojiFontSize = 24.0f;
const NSTimeInterval kStripReopenSuppression = 0.4;
const CGFloat kChipHeight = 22.0f;
const CGFloat kChipRadius = 11.0f;
const CGFloat kChipPadding = 7.0f;
const CGFloat kChipGap = 4.0f;
const CGFloat kChipRowGap = 4.0f;
const CGFloat kChipEmojiFontSize = 13.0f;
const CGFloat kChipCountFontSize = 12.0f;
const CGFloat kChipCountGap = 3.0f;
const CGFloat kChipGlyphSlot = 15.0f;
const CGFloat kChipGlyphSide = 15.0f;
const CGFloat kChipMinRowWidth = 39.0f;
const CGFloat kReactionIconSide = 28.0f;
NSString *const kPaidStarGlyph = @"⭐";
const NSInteger kPaidUndoSeconds = 5;
const CGFloat kListRowHeight = 51.0f;
const CGFloat kListAvatarSide = 40.0f;
const CGFloat kListBarHeight = 44.0f;
const CGFloat kListGroupHeight = 30.0f;
const CGFloat kListGroupInset = 8.0f;
const CGFloat kListSeparatorWidth = 2.0f;
const NSInteger kListPageSize = 50;
TGReactionPickerView *sOpenPicker = nil;
NSTimeInterval sLastHideTime = 0;
NSMutableDictionary *sReactionIcons = nil;

UIImage *TGReactionScaledIcon(UIImage *image, CGFloat side) {
	if (image == nil || side < 1.0f)
		return nil;
	CGSize source = image.size;
	if (source.width < 1.0f || source.height < 1.0f)
		return nil;

	CGFloat factor = MIN(side / source.width, side / source.height);
	CGSize target = CGSizeMake(floorf(source.width * factor), floorf(source.height * factor));
	if (target.width < 1.0f || target.height < 1.0f)
		return nil;

	CGFloat scale = 1.0f;
	if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
		scale = [[UIScreen mainScreen] scale];

	UIGraphicsBeginImageContextWithOptions(target, NO, scale);
	[image drawInRect:CGRectMake(0, 0, target.width, target.height)];
	UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return result;
}

void TGReactionIconForEmoji(NSString *emoji, CGFloat side, void (^completion)(UIImage *icon)) {
	if (completion == nil)
		return;
	if (emoji.length == 0) {
		completion(nil);
		return;
	}
	if (sReactionIcons == nil)
		sReactionIcons = [[NSMutableDictionary alloc] init];

	id cached = [sReactionIcons objectForKey:emoji];
	if (cached != nil) {
		completion([cached isKindOfClass:[UIImage class]] ? cached : nil);
		return;
	}

	[TGReactionService reactionIconPathForEmoji:emoji completion:^(NSString *path) {
		if (path.length == 0) {
			[sReactionIcons setObject:[NSNull null] forKey:emoji];
			completion(nil);
			return;
		}
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
			UIImage *raw = TGDecodeThumbnail(path, side * [UIScreen mainScreen].scale);
			if (raw == nil)
				raw = [UIImage convertFromWebP:path compressedData:NULL error:NULL];
			UIImage *scaled = TGReactionScaledIcon(raw, side);
			raw = nil;
			dispatch_async(dispatch_get_main_queue(), ^{
				[sReactionIcons setObject:(scaled != nil ? (id)scaled : (id)[NSNull null])
								   forKey:emoji];
				completion(scaled);
			});
		});
	}];
}

NSMutableDictionary *sCustomReactionIcons = nil;

void TGReactionIconForCustomEmoji(NSString *customEmojiId, CGFloat side, void (^completion)(UIImage *icon)) {
	if (completion == nil)
		return;
	if (customEmojiId.length == 0) {
		completion(nil);
		return;
	}
	if (sCustomReactionIcons == nil)
		sCustomReactionIcons = [[NSMutableDictionary alloc] init];

	id cached = [sCustomReactionIcons objectForKey:customEmojiId];
	if (cached != nil) {
		completion([cached isKindOfClass:[UIImage class]] ? cached : nil);
		return;
	}

	[TGReactionService reactionIconPathForCustomEmojiId:customEmojiId completion:^(NSString *path) {
		if (path.length == 0) {
			[sCustomReactionIcons setObject:[NSNull null] forKey:customEmojiId];
			completion(nil);
			return;
		}
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
			UIImage *raw = TGDecodeThumbnail(path, side * [UIScreen mainScreen].scale);
			if (raw == nil)
				raw = [UIImage convertFromWebP:path compressedData:NULL error:NULL];
			UIImage *scaled = TGReactionScaledIcon(raw, side);
			raw = nil;
			dispatch_async(dispatch_get_main_queue(), ^{
				[sCustomReactionIcons setObject:(scaled != nil ? (id)scaled : (id)[NSNull null])
										 forKey:customEmojiId];
				completion(scaled);
			});
		});
	}];
}

UIViewController *TGReactionOwningController(UIView *view) {
	UIResponder *responder = view;
	while (responder != nil) {
		if ([responder isKindOfClass:[UIViewController class]])
			return (UIViewController *)responder;
		responder = [responder nextResponder];
	}
	return nil;
}

UIImage *TGReactionStretch(NSString *name, int cap) {
	UIImage *image = [UIImage imageNamed:name];
	if (image == nil)
		return nil;
	if (cap == -1)
		cap = (int)(image.size.width / 2);
	else if (cap < -1)
		cap = (int)(image.size.width - 1);
	if (cap > (int)image.size.width - 1)
		cap = MAX(0, (int)image.size.width - 1);
	return [image stretchableImageWithLeftCapWidth:cap topCapHeight:0];
}

@implementation TGReactionPickerView

+ (void)dismiss {
	TGReactionPickerView *picker = sOpenPicker;
	sOpenPicker = nil;
	[picker teardownAnimated:YES];
}

+ (instancetype)showForMessage:(int64_t)messageId
						inChat:(int64_t)chatId
					  fromRect:(CGRect)rect
						inView:(UIView *)host
						picked:(TGReactionPickedBlock)picked {
	if (host == nil)
		return nil;

	CGRect hostBounds = host.bounds;
	if (hostBounds.size.width < 40 || hostBounds.size.height < 40)
		return nil;

	BOOL wasOpen = (sOpenPicker != nil);
	[self dismiss];
	if (!wasOpen && [NSDate timeIntervalSinceReferenceDate] - sLastHideTime < kStripReopenSuppression)
		return nil;

	TGReactionPickerView *picker = [[TGReactionPickerView alloc] initWithFrame:hostBounds];
	picker.chatId = chatId;
	picker.messageId = messageId;
	picker.onReactionPicked = picked;
	picker->_anchorRect = rect;
	picker->_hostSize = hostBounds.size;
	[host addSubview:picker];
	sOpenPicker = picker;

	__weak TGReactionPickerView *weakPicker = picker;
	picker->_backgroundDismissObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIApplicationDidEnterBackgroundNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong TGReactionPickerView *strongPicker = weakPicker;
					if (!strongPicker)
						return;
					[strongPicker externalDismiss];
				}];
	picker->_orientationDismissObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIApplicationWillChangeStatusBarOrientationNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong TGReactionPickerView *strongPicker = weakPicker;
					if (!strongPicker)
						return;
					[strongPicker externalDismiss];
				}];

	[picker showSpinner];
	[picker present];
	[picker loadReactions];

	return picker;
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		self.backgroundColor = [UIColor clearColor];
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

		_buttons = [[NSMutableArray alloc] init];
		_separators = [[NSMutableArray alloc] init];
		_arrowLocation = 50;
		_paidAnonymous = [TGReactionService defaultPaidReactionIsAnonymous];
		_anchorRect = CGRectMake(frame.size.width / 2, frame.size.height / 2, 0, 0);

		_card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, kStripHeight)];
		_card.backgroundColor = [UIColor clearColor];
		_card.clipsToBounds = NO;
		[self addSubview:_card];

		_scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 0, kStripHeight)];
		_scrollView.backgroundColor = [UIColor clearColor];
		_scrollView.showsHorizontalScrollIndicator = NO;
		_scrollView.showsVerticalScrollIndicator = NO;
		_scrollView.alwaysBounceHorizontal = NO;
		_scrollView.clipsToBounds = YES;
		[_card addSubview:_scrollView];

		UIImage *topLine = [UIImage imageNamed:@"MenuButtonTopLine.png"];
		UIImage *bottomLine = [UIImage imageNamed:@"MenuButtonBottomLine.png"];

		_topLineView = [[UIImageView alloc] initWithImage:topLine];
		[_card addSubview:_topLineView];
		_topLineRightView = [[UIImageView alloc] initWithImage:topLine];
		[_card addSubview:_topLineRightView];
		_bottomLineView = [[UIImageView alloc] initWithImage:bottomLine];
		[_card addSubview:_bottomLineView];
		_bottomLineRightView = [[UIImageView alloc] initWithImage:bottomLine];
		[_card addSubview:_bottomLineRightView];

		_arrowTopView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MenuArrowTop.png"]];
		[_card addSubview:_arrowTopView];
		_arrowBottomView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MenuArrowBottom.png"]];
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
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

@end
