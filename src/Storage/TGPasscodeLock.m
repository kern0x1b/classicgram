#import "TGPasscodeLock.h"
#import "TGLocalization.h"
#import "TGDevice.h"
#import "TGPasscodeLockoutState.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonKeyDerivation.h>
#import <QuartzCore/QuartzCore.h>

NSString *const TGPasscodeLockDidUnlockNotification = @"TGPasscodeLockDidUnlock";

static NSString *const TGPasscodeAutoLockKey = @"TGPasscodeAutoLockSeconds";
static NSString *const TGPasscodeLegacyDigestKey = @"TGPasscodeDigest";
static NSString *const TGPasscodeFailedAttemptsKey = @"TGPasscodeFailedAttempts";
static NSString *const TGPasscodeLastFailureAtKey = @"TGPasscodeLastFailureAt";
static NSString *const TGPasscodeLastFailureMonotonicKey = @"TGPasscodeLastFailureMonotonic";
static NSString *const TGPasscodeService = @"kuzm.ig.telegram.passcode";
static NSString *const TGPasscodeAccount = @"local";

enum { kPasscodeSaltLength = 16 };
enum { kPasscodeDigestLength = 32 };
static const uint32_t kPasscodeRounds = 8000;
static const NSUInteger kPasscodeSimpleLength = 4;

#pragma mark - keychain

static NSMutableDictionary *TGPasscodeKeychainQuery(void) {
	NSMutableDictionary *query = [NSMutableDictionary dictionary];
	[query setObject:(__bridge id)kSecClassGenericPassword
			  forKey:(__bridge id)kSecClass];
	[query setObject:TGPasscodeService forKey:(__bridge id)kSecAttrService];
	[query setObject:TGPasscodeAccount forKey:(__bridge id)kSecAttrAccount];
	return query;
}

static NSDictionary *TGPasscodeKeychainRead(OSStatus *outStatus) {
	NSMutableDictionary *query = TGPasscodeKeychainQuery();
	[query setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
	[query setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];

	CFTypeRef found = NULL;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &found);
	if (outStatus)
		*outStatus = status;
	if (status != errSecSuccess) {
		if (status != errSecItemNotFound)
			NSLog(@"passcode: keychain read failed (%d)", (int)status);
		if (found)
			CFRelease(found);
		return nil;
	}

	NSData *data = (__bridge_transfer NSData *)found;
	if (!data.length)
		return nil;
	id record = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
	return [record isKindOfClass:[NSDictionary class]] ? record : nil;
}

static BOOL TGPasscodeKeychainDelete(void) {
	OSStatus status = SecItemDelete((__bridge CFDictionaryRef)TGPasscodeKeychainQuery());
	if (status == errSecSuccess || status == errSecItemNotFound)
		return YES;
	NSLog(@"passcode: keychain delete failed (%d)", (int)status);
	return NO;
}

static BOOL TGPasscodeKeychainWrite(NSDictionary *record) {
	NSData *data = [NSPropertyListSerialization dataWithPropertyList:record format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
	if (!data.length)
		return NO;

	NSDictionary *changes = @{(__bridge id)kSecValueData : data,
		(__bridge id)kSecAttrAccessible :
			(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly};
	OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)TGPasscodeKeychainQuery(),
		(__bridge CFDictionaryRef)changes);
	if (status == errSecSuccess)
		return YES;
	if (status != errSecItemNotFound) {
		NSLog(@"passcode: keychain update failed (%d)", (int)status);
		return NO;
	}

	NSMutableDictionary *item = TGPasscodeKeychainQuery();
	[item setObject:data forKey:(__bridge id)kSecValueData];
	[item setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
			 forKey:(__bridge id)kSecAttrAccessible];

	status = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
	if (status == errSecDuplicateItem) {
		SecItemDelete((__bridge CFDictionaryRef)TGPasscodeKeychainQuery());
		status = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
	}
	if (status == errSecSuccess)
		return YES;
	NSLog(@"passcode: keychain write failed (%d)", (int)status);
	return NO;
}

#pragma mark - digest

static NSData *TGPasscodeSalt(void) {
	uint8_t bytes[kPasscodeSaltLength];
	if (SecRandomCopyBytes(kSecRandomDefault, kPasscodeSaltLength, bytes) != 0)
		for (NSInteger i = 0; i < kPasscodeSaltLength; i++)
			bytes[i] = (uint8_t)arc4random();
	return [NSData dataWithBytes:bytes length:kPasscodeSaltLength];
}

static NSData *TGPasscodeDerive(NSString *passcode, NSData *salt, uint32_t rounds) {
	NSData *text = [(passcode ?: @"") dataUsingEncoding:NSUTF8StringEncoding];
	uint8_t out[kPasscodeDigestLength];
	int result = CCKeyDerivationPBKDF(kCCPBKDF2, text.bytes, text.length,
		salt.bytes, salt.length, kCCPRFHmacAlgSHA256, rounds,
		out, kPasscodeDigestLength);
	if (result != kCCSuccess)
		return nil;
	return [NSData dataWithBytes:out length:kPasscodeDigestLength];
}

static NSString *TGPasscodeLegacyDigest(NSString *passcode) {
	NSData *data = [[NSString stringWithFormat:@"tg.passcode.%@", passcode ?: @""]
		dataUsingEncoding:NSUTF8StringEncoding];
	unsigned char out[CC_SHA1_DIGEST_LENGTH];
	CC_SHA1(data.bytes, (CC_LONG)data.length, out);
	NSMutableString *hex = [NSMutableString string];
	for (NSInteger i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
		[hex appendFormat:@"%02x", out[i]];
	return hex;
}

static BOOL TGPasscodeDataEqual(NSData *left, NSData *right) {
	if (left.length != right.length || !left.length)
		return NO;
	const uint8_t *a = left.bytes;
	const uint8_t *b = right.bytes;
	uint8_t difference = 0;
	for (NSInteger i = 0; i < left.length; i++)
		difference |= a[i] ^ b[i];
	return difference == 0;
}

#pragma mark - artwork

static UIFont *TGPasscodeDigitFont(CGFloat size) {
	UIFont *light = [UIFont fontWithName:@"HelveticaNeue-Light" size:size];
	return light ?: [UIFont systemFontOfSize:size];
}

static UIImage *TGPasscodeKeyArt(CGSize size, NSString *digit, NSString *letters,
	BOOL highlighted) {
	if (size.width < 1 || size.height < 1)
		return nil;
	UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context) {
		UIGraphicsEndImageContext();
		return nil;
	}

	CGRect circle = CGRectInset(CGRectMake(0, 0, size.width, size.height), 1.0f, 1.0f);
	if (highlighted) {
		CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 0.9f);
		CGContextFillEllipseInRect(context, circle);
	} else {
		CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 0.13f);
		CGContextFillEllipseInRect(context, circle);
		CGContextSaveGState(context);
		CGContextAddEllipseInRect(context, CGRectInset(circle, 1.0f, 1.0f));
		CGContextClip(context);
		CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 0.09f);
		CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height * 0.45f));
		CGContextRestoreGState(context);
		CGContextSetLineWidth(context, 1.0f);
		CGContextSetRGBStrokeColor(context, 1.0f, 1.0f, 1.0f, 0.38f);
		CGContextStrokeEllipseInRect(context, circle);
	}

	UIColor *ink = highlighted ? [UIColor colorWithWhite:0.09f alpha:1.0f]
							   : [UIColor whiteColor];
	UIFont *digitFont = TGPasscodeDigitFont(floorf(size.height * 0.46f));
	UIFont *lettersFont = [UIFont boldSystemFontOfSize:
			MAX(8.0f, floorf(size.height * 0.115f))];

	CGFloat digitHeight = digitFont.lineHeight;
	CGFloat lettersHeight = letters.length ? lettersFont.lineHeight : 0.0f;
	CGFloat block = digitHeight + lettersHeight;
	CGFloat top = floorf((size.height - block) / 2.0f) - (letters.length ? 1.0f : 0.0f);

	if (!highlighted) {
		CGContextSaveGState(context);
		CGContextSetShadowWithColor(context, CGSizeMake(0, -1), 0,
			[UIColor colorWithWhite:0.0f alpha:0.45f].CGColor);
	}
	[ink set];
	[digit drawInRect:CGRectMake(0, top, size.width, digitHeight)
			 withFont:digitFont
		lineBreakMode:NSLineBreakByClipping
			alignment:NSTextAlignmentCenter];
	if (letters.length)
		[letters drawInRect:CGRectMake(0, top + digitHeight - 2.0f, size.width, lettersHeight)
				   withFont:lettersFont
			  lineBreakMode:NSLineBreakByClipping
				  alignment:NSTextAlignmentCenter];
	if (!highlighted)
		CGContextRestoreGState(context);

	UIImage *art = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return art;
}

static UIImage *TGPasscodeDotArt(CGFloat side, BOOL filled) {
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0.0f);
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context) {
		UIGraphicsEndImageContext();
		return nil;
	}
	CGRect dot = CGRectInset(CGRectMake(0, 0, side, side), 1.0f, 1.0f);
	CGContextSetShadowWithColor(context, CGSizeMake(0, -1), 0,
		[UIColor colorWithWhite:0.0f alpha:0.5f].CGColor);
	if (filled) {
		CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 1.0f);
		CGContextFillEllipseInRect(context, dot);
	} else {
		CGContextSetLineWidth(context, 1.0f);
		CGContextSetRGBStrokeColor(context, 1.0f, 1.0f, 1.0f, 0.6f);
		CGContextStrokeEllipseInRect(context, dot);
	}
	UIImage *art = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return art;
}

#pragma mark - keypad button

@interface TGPasscodeKeyButton : UIButton
@property (nonatomic, copy) NSString *digit;
@property (nonatomic, copy) NSString *letters;
- (void)refreshArt;
@end

@implementation TGPasscodeKeyButton

- (void)setFrame:(CGRect)frame {
	BOOL resized = !CGSizeEqualToSize(frame.size, self.frame.size);
	[super setFrame:frame];
	if (resized)
		[self refreshArt];
}

- (void)refreshArt {
	CGSize size = self.bounds.size;
	if (size.width < 2 || size.height < 2)
		return;
	[self setBackgroundImage:TGPasscodeKeyArt(size, self.digit, self.letters, NO)
					forState:UIControlStateNormal];
	[self setBackgroundImage:TGPasscodeKeyArt(size, self.digit, self.letters, YES)
					forState:UIControlStateHighlighted];
}

@end

#pragma mark - the screen

@interface TGPasscodeLockViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, copy) BOOL (^verify)(NSString *passcode);
@property (nonatomic, copy) NSTimeInterval (^lockoutRemaining)(void);
@property (nonatomic, copy) dispatch_block_t onUnlock;
@property (nonatomic, assign) BOOL simple;
- (void)reset;
@end

@interface TGPasscodeLockViewController ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *dotsView;
@property (nonatomic, strong) NSArray *dots;
@property (nonatomic, strong) NSArray *keys;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, strong) NSMutableString *entry;
@property (nonatomic, strong) NSTimer *lockoutTimer;
@end

@implementation TGPasscodeLockViewController

- (void)loadView {
	UIView *root = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
	root.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	UIImage *linen = [UIImage imageNamed:@"DarkLinen.png"];
	root.backgroundColor = linen ? [UIColor colorWithPatternImage:linen]
								 : [UIColor colorWithWhite:0.12f alpha:1.0f];
	self.view = root;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.entry = [NSMutableString string];

	self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.titleLabel.backgroundColor = [UIColor clearColor];
	self.titleLabel.textColor = [UIColor whiteColor];
	self.titleLabel.font = [UIFont boldSystemFontOfSize:17];
	self.titleLabel.textAlignment = NSTextAlignmentCenter;
	self.titleLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.55f];
	self.titleLabel.shadowOffset = CGSizeMake(0, -1);
	self.titleLabel.text = TGL(@"EnterPasscode.EnterPasscode", @"Enter your passcode");
	[self.view addSubview:self.titleLabel];

	if (self.simple)
		[self buildKeypad];
	else
		[self buildField];
}

- (void)buildKeypad {
	self.dotsView = [[UIView alloc] initWithFrame:CGRectZero];
	self.dotsView.backgroundColor = [UIColor clearColor];
	[self.view addSubview:self.dotsView];

	NSMutableArray *dots = [NSMutableArray array];
	for (NSInteger i = 0; i < kPasscodeSimpleLength; i++) {
		UIImageView *dot = [[UIImageView alloc] initWithFrame:CGRectZero];
		[self.dotsView addSubview:dot];
		[dots addObject:dot];
	}
	self.dots = dots;

	NSArray *digits = @[ @"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"0" ];
	NSArray *letters = @[ @"", @"A B C", @"D E F", @"G H I", @"J K L", @"M N O",
		@"P Q R S", @"T U V", @"W X Y Z", @"" ];
	NSMutableArray *keys = [NSMutableArray array];
	for (NSInteger i = 0; i < digits.count; i++) {
		TGPasscodeKeyButton *key = [TGPasscodeKeyButton buttonWithType:UIButtonTypeCustom];
		key.digit = digits[i];
		key.letters = letters[i];
		key.exclusiveTouch = YES;
		key.tag = (NSInteger)i;
		[key addTarget:self action:@selector(keyPressed:)
			forControlEvents:UIControlEventTouchUpInside];
		[self.view addSubview:key];
		[keys addObject:key];
	}
	self.keys = keys;

	self.deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[self.deleteButton setTitle:TGL(@"Common.Delete", @"Delete") forState:UIControlStateNormal];
	[self.deleteButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[self.deleteButton setTitleColor:[UIColor colorWithWhite:1.0f alpha:0.4f]
							forState:UIControlStateHighlighted];
	self.deleteButton.titleLabel.font = [UIFont systemFontOfSize:17];
	self.deleteButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
	[self.deleteButton setTitleShadowColor:[UIColor colorWithWhite:0.0f alpha:0.55f]
								  forState:UIControlStateNormal];
	self.deleteButton.hidden = YES;
	[self.deleteButton addTarget:self action:@selector(deletePressed)
				forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:self.deleteButton];

	[self refreshDots];
}

- (void)buildField {
	self.field = [[UITextField alloc] initWithFrame:CGRectZero];
	self.field.borderStyle = UITextBorderStyleRoundedRect;
	self.field.secureTextEntry = YES;
	self.field.returnKeyType = UIReturnKeyDone;
	self.field.autocapitalizationType = UITextAutocapitalizationTypeNone;
	self.field.autocorrectionType = UITextAutocorrectionTypeNo;
	self.field.font = [UIFont systemFontOfSize:17];
	self.field.delegate = self;
	self.field.placeholder = TGL(@"PrivacySettings.Passcode", @"Passcode Lock");
	[self.view addSubview:self.field];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
	if ([TGDevice isPadIdiom])
		return YES;
	return UIInterfaceOrientationIsPortrait(orientation);
}

- (BOOL)shouldAutorotate {
	return [TGDevice isPadIdiom];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return [TGDevice isPadIdiom] ? UIInterfaceOrientationMaskAll
								 : UIInterfaceOrientationMaskPortrait;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.view setNeedsLayout];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self updateLockoutDisplay];
	if (self.field && ![self isLockedOut])
		[self.field becomeFirstResponder];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	CGRect bounds = self.view.bounds;
	CGFloat top = 34.0f;

	if (self.field) {
		CGFloat width = MIN(bounds.size.width - 40.0f, 360.0f);
		self.titleLabel.frame = CGRectMake(0, top, bounds.size.width, 22.0f);
		self.field.frame = CGRectMake(floorf((bounds.size.width - width) / 2.0f),
			top + 40.0f, width, 31.0f);
		return;
	}

	CGFloat column = MIN(bounds.size.width, 420.0f);
	CGFloat side = floorf(MIN(84.0f, (column - 48.0f) / 3.0f - 14.0f));
	CGFloat gapX = floorf((column - side * 3.0f) / 4.0f);
	CGFloat gapY = floorf(MIN(gapX, 14.0f));
	CGFloat gridWidth = side * 3.0f + gapX * 2.0f;
	CGFloat gridHeight = side * 4.0f + gapY * 3.0f;
	CGFloat left = floorf((bounds.size.width - gridWidth) / 2.0f);

	CGFloat headHeight = 22.0f + 18.0f + 14.0f;
	CGFloat gridTop = floorf((bounds.size.height - gridHeight + headHeight) / 2.0f);
	gridTop = MAX(gridTop, top + headHeight + 8.0f);
	if (gridTop + gridHeight > bounds.size.height - 10.0f)
		gridTop = bounds.size.height - 10.0f - gridHeight;

	CGFloat headTop = MAX(top, gridTop - headHeight - 8.0f);
	self.titleLabel.frame = CGRectMake(0, headTop, bounds.size.width, 22.0f);

	CGFloat dotSide = 14.0f;
	CGFloat dotGap = 22.0f;
	CGFloat dotsWidth = dotSide * kPasscodeSimpleLength + dotGap * (kPasscodeSimpleLength - 1);
	self.dotsView.frame = CGRectMake(floorf((bounds.size.width - dotsWidth) / 2.0f),
		headTop + 32.0f, dotsWidth, dotSide);
	for (NSInteger i = 0; i < self.dots.count; i++)
		[self.dots[i] setFrame:CGRectMake(i * (dotSide + dotGap), 0, dotSide, dotSide)];

	for (NSInteger i = 0; i < self.keys.count; i++) {
		NSInteger row = i < 9 ? i / 3 : 3;
		NSInteger col = i < 9 ? i % 3 : 1;
		[self.keys[i] setFrame:CGRectMake(left + col * (side + gapX),
								   gridTop + row * (side + gapY), side, side)];
	}
	self.deleteButton.frame = CGRectMake(left + 2 * (side + gapX),
		gridTop + 3 * (side + gapY), side, side);
}

- (void)refreshDots {
	UIImage *empty = TGPasscodeDotArt(14.0f, NO);
	UIImage *filled = TGPasscodeDotArt(14.0f, YES);
	for (NSInteger i = 0; i < self.dots.count; i++)
		[self.dots[i] setImage:i < self.entry.length ? filled : empty];
	self.deleteButton.hidden = self.entry.length == 0;
}

- (void)keyPressed:(TGPasscodeKeyButton *)sender {
	if ([self isLockedOut])
		return;
	if (self.entry.length >= kPasscodeSimpleLength)
		return;
	[self.entry appendString:sender.digit];
	[self refreshDots];
	if (self.entry.length < kPasscodeSimpleLength)
		return;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(submit) object:nil];
	[self performSelector:@selector(submit) withObject:nil afterDelay:0.06];
}

- (void)deletePressed {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(submit) object:nil];
	if (!self.entry.length)
		return;
	[self.entry deleteCharactersInRange:NSMakeRange(self.entry.length - 1, 1)];
	[self refreshDots];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	if ([self isLockedOut])
		return NO;
	[self.entry setString:textField.text ?: @""];
	[self submit];
	return NO;
}

- (void)submit {
	if ([self isLockedOut]) {
		[self refuse];
		return;
	}
	NSString *typed = [self.entry copy];
	if (self.verify && self.verify(typed)) {
		[self stopLockoutTimer];
		if (self.onUnlock)
			self.onUnlock();
		return;
	}
	[self refuse];
	[self updateLockoutDisplay];
}

- (void)refuse {
	[self.entry setString:@""];
	self.field.text = @"";
	[self refreshDots];
	[self shakeView:self.field ?: self.dotsView];
}

- (void)reset {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(submit) object:nil];
	[self.entry setString:@""];
	self.field.text = @"";
	[self refreshDots];
	[self updateLockoutDisplay];
	if (self.field && self.isViewLoaded && self.view.window && ![self isLockedOut])
		[self.field becomeFirstResponder];
}

- (BOOL)isLockedOut {
	return self.lockoutRemaining && self.lockoutRemaining() > 0;
}

- (void)updateLockoutDisplay {
	NSTimeInterval remaining = self.lockoutRemaining ? self.lockoutRemaining() : 0;
	BOOL lockedOut = remaining > 0;

	CGFloat alpha = lockedOut ? 0.35f : 1.0f;
	for (TGPasscodeKeyButton *key in self.keys) {
		key.enabled = !lockedOut;
		key.alpha = alpha;
	}
	self.deleteButton.enabled = !lockedOut;
	self.dotsView.alpha = alpha;
	self.field.enabled = !lockedOut;
	self.field.alpha = alpha;

	if (lockedOut) {
		self.titleLabel.text = [NSString stringWithFormat:
				TGL(@"EnterPasscode.TryAgainInSecondsFormat", @"Try again in %d s"),
			(int)ceil(remaining)];
		if (self.field && self.view.window)
			[self.field resignFirstResponder];
		if (!self.lockoutTimer)
			self.lockoutTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
				selector:@selector(lockoutTick) userInfo:nil repeats:YES];
		return;
	}

	[self stopLockoutTimer];
	self.titleLabel.text = TGL(@"EnterPasscode.EnterPasscode", @"Enter your passcode");
}

- (void)lockoutTick {
	[self updateLockoutDisplay];
}

- (void)stopLockoutTimer {
	[self.lockoutTimer invalidate];
	self.lockoutTimer = nil;
}

- (void)shakeView:(UIView *)view {
	if (!view)
		return;
	CGRect original = view.frame;
	CGRect right = original;
	right.origin.x = original.origin.x + 4.0f;
	CGRect left = original;
	left.origin.x = original.origin.x - 4.0f;

	[UIView animateWithDuration:0.05 delay:0.0
		options:UIViewAnimationOptionAutoreverse
		animations:^{
			view.frame = right;
		} completion:^(BOOL finished) {
			if (!finished) {
				view.frame = original;
				return;
			}
			[UIView animateWithDuration:0.05 delay:0.0
				options:(UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse)
				animations:^{
					[UIView setAnimationRepeatCount:3];
					view.frame = left;
				} completion:^(__unused BOOL innerFinished) {
					view.frame = original;
				}];
		}];
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[self.lockoutTimer invalidate];
}

@end

#pragma mark - the lock

@interface TGPasscodeLock ()
@property (nonatomic, strong) NSDictionary *record;
@property (nonatomic, assign) BOOL recordLoaded;
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) TGPasscodeLockViewController *screen;
@property (nonatomic, weak) UIWindow *previousKeyWindow;
@property (nonatomic, assign) BOOL locked;
@property (nonatomic, assign) BOOL covering;
@property (nonatomic, assign) NSTimeInterval leftAt;
@end

@implementation TGPasscodeLock

+ (instancetype)shared {
	static TGPasscodeLock *shared = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		shared = [[TGPasscodeLock alloc] init];
	});
	return shared;
}

#pragma mark - stored state

- (NSDictionary *)currentRecord {
	if (self.recordLoaded)
		return self.record;

	OSStatus status = errSecSuccess;
	NSDictionary *stored = TGPasscodeKeychainRead(&status);
	if (stored) {
		self.record = stored;
		self.recordLoaded = YES;
		return self.record;
	}

	[self migrateLegacyDigest];
	if (self.record || status == errSecItemNotFound)
		self.recordLoaded = YES;
	return self.record;
}

- (void)migrateLegacyDigest {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	id legacy = [defaults objectForKey:TGPasscodeLegacyDigestKey];
	if (![legacy isKindOfClass:[NSString class]] || ![legacy length])
		return;
	NSDictionary *record = @{@"legacy" : legacy, @"simple" : @NO};
	self.record = record;
	if (!TGPasscodeKeychainWrite(record))
		return;
	[defaults removeObjectForKey:TGPasscodeLegacyDigestKey];
	[defaults synchronize];
}

- (BOOL)isSet {
	return [self currentRecord] != nil;
}

- (BOOL)isSimple {
	NSNumber *simple = [[self currentRecord] objectForKey:@"simple"];
	return simple ? simple.boolValue : YES;
}

- (BOOL)matches:(NSString *)passcode {
	NSDictionary *record = [self currentRecord];
	if (!record)
		return YES;

	NSString *legacy = [record objectForKey:@"legacy"];
	if ([legacy isKindOfClass:[NSString class]])
		return [legacy isEqualToString:TGPasscodeLegacyDigest(passcode)];

	NSData *salt = [record objectForKey:@"salt"];
	NSData *digest = [record objectForKey:@"digest"];
	NSNumber *rounds = [record objectForKey:@"rounds"];
	if (![salt isKindOfClass:[NSData class]] || ![digest isKindOfClass:[NSData class]])
		return NO;
	return TGPasscodeDataEqual(digest,
		TGPasscodeDerive(passcode, salt, rounds ? rounds.unsignedIntValue : kPasscodeRounds));
}

- (BOOL)setPasscode:(NSString *)passcode simple:(BOOL)simple {
	if (!passcode.length)
		return [self removePasscode];

	NSData *salt = TGPasscodeSalt();
	NSData *digest = TGPasscodeDerive(passcode, salt, kPasscodeRounds);
	if (!digest)
		return NO;

	NSDictionary *record = @{@"salt" : salt,
		@"digest" : digest,
		@"rounds" : @(kPasscodeRounds),
		@"simple" : @(simple)};
	if (!TGPasscodeKeychainWrite(record))
		return NO;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults objectForKey:TGPasscodeLegacyDigestKey]) {
		[defaults removeObjectForKey:TGPasscodeLegacyDigestKey];
		[defaults synchronize];
	}
	self.record = record;
	self.recordLoaded = YES;
	[self resetFailedAttempts];
	return YES;
}

#pragma mark - failed-attempt lockout

- (NSInteger)failedAttempts {
	return [[NSUserDefaults standardUserDefaults] integerForKey:TGPasscodeFailedAttemptsKey];
}

- (NSTimeInterval)lastFailureAt {
	return [[NSUserDefaults standardUserDefaults] doubleForKey:TGPasscodeLastFailureAtKey];
}

- (NSTimeInterval)lastFailureMonotonic {
	return [[NSUserDefaults standardUserDefaults] doubleForKey:TGPasscodeLastFailureMonotonicKey];
}

- (void)registerFailedAttempt {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setInteger:[self failedAttempts] + 1 forKey:TGPasscodeFailedAttemptsKey];
	[defaults setDouble:[NSDate timeIntervalSinceReferenceDate] forKey:TGPasscodeLastFailureAtKey];
	[defaults setDouble:CACurrentMediaTime() forKey:TGPasscodeLastFailureMonotonicKey];
	[defaults synchronize];
}

- (void)resetFailedAttempts {
	if (![self failedAttempts])
		return;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:TGPasscodeFailedAttemptsKey];
	[defaults removeObjectForKey:TGPasscodeLastFailureAtKey];
	[defaults removeObjectForKey:TGPasscodeLastFailureMonotonicKey];
	[defaults synchronize];
}

- (NSTimeInterval)lockoutRemainingSeconds {
	return TGPasscodeLockoutRemainingSeconds([self failedAttempts], [self lastFailureAt],
		[NSDate timeIntervalSinceReferenceDate], [self lastFailureMonotonic], CACurrentMediaTime());
}

- (BOOL)attemptUnlock:(NSString *)passcode {
	if ([self lockoutRemainingSeconds] > 0)
		return NO;
	if ([self matches:passcode]) {
		[self resetFailedAttempts];
		return YES;
	}
	[self registerFailedAttempt];
	return NO;
}

- (BOOL)removePasscode {
	if (!TGPasscodeKeychainDelete())
		return NO;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults objectForKey:TGPasscodeLegacyDigestKey]) {
		[defaults removeObjectForKey:TGPasscodeLegacyDigestKey];
		[defaults synchronize];
	}
	self.record = nil;
	self.recordLoaded = YES;
	self.locked = NO;
	self.covering = NO;
	[self resetFailedAttempts];
	[self hideWindow];
	return YES;
}

- (NSInteger)autoLockSeconds {
	return [[NSUserDefaults standardUserDefaults] integerForKey:TGPasscodeAutoLockKey];
}

- (void)setAutoLockSeconds:(NSInteger)seconds {
	[[NSUserDefaults standardUserDefaults] setInteger:seconds forKey:TGPasscodeAutoLockKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)isLocked {
	return self.locked;
}

- (BOOL)isLockedOrWillLockOnReturn {
	if (![self isSet])
		return NO;
	if (self.locked)
		return YES;
	NSInteger grace = [self autoLockSeconds];
	if (grace <= 0)
		return YES;
	NSTimeInterval away = [NSDate timeIntervalSinceReferenceDate] - self.leftAt;
	return away >= (NSTimeInterval)grace;
}

#pragma mark - the window

- (void)showWindowLocked:(BOOL)askForIt {
	if (!self.window) {
		self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
		self.window.windowLevel = UIWindowLevelAlert;
		self.window.backgroundColor = [UIColor blackColor];
		self.window.opaque = YES;
	}
	if (!self.screen || self.screen.simple != [self isSimple]) {
		TGPasscodeLockViewController *screen = [[TGPasscodeLockViewController alloc] init];
		screen.simple = [self isSimple];
		__weak typeof(self) weakSelf = self;
		screen.verify = ^BOOL(NSString *passcode) {
			return [weakSelf attemptUnlock:passcode];
		};
		screen.lockoutRemaining = ^NSTimeInterval(void) {
			return [weakSelf lockoutRemainingSeconds];
		};
		screen.onUnlock = ^{
			[weakSelf finishUnlock];
		};
		self.screen = screen;
		self.window.rootViewController = screen;
	}

	if (self.window.hidden) {
		UIWindow *key = [UIApplication sharedApplication].keyWindow;
		if (key != self.window)
			self.previousKeyWindow = key;
		[key endEditing:YES];
		self.window.alpha = 1.0f;
		self.window.hidden = NO;
	}
	if (askForIt)
		[self.window makeKeyAndVisible];
	[self.screen reset];
}

- (void)hideWindow {
	if (!self.window || self.window.hidden)
		return;
	[self.window endEditing:YES];
	self.window.hidden = YES;
	UIWindow *previous = self.previousKeyWindow
		?: [UIApplication sharedApplication].delegate.window;
	[previous makeKeyAndVisible];
}

- (void)finishUnlock {
	self.locked = NO;
	self.covering = NO;
	[self.window endEditing:YES];
	__weak typeof(self) weakSelf = self;
	[UIView animateWithDuration:0.25 animations:^{
		weakSelf.window.alpha = 0.0f;
	} completion:^(__unused BOOL finished) {
		[weakSelf hideWindow];
		weakSelf.window.alpha = 1.0f;
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGPasscodeLockDidUnlockNotification
						  object:nil];
	}];
}

#pragma mark - lifecycle

- (void)applicationDidFinishLaunching {
	if (![self isSet])
		return;
	self.locked = YES;
	[self showWindowLocked:YES];
}

- (void)applicationWillResignActive {
	self.leftAt = [NSDate timeIntervalSinceReferenceDate];
	if (![self isSet] || self.locked)
		return;
	self.covering = YES;
	[self showWindowLocked:NO];
}

- (void)applicationDidEnterBackground {
	self.leftAt = [NSDate timeIntervalSinceReferenceDate];
}

- (void)applicationWillEnterForeground {
	if (![self isSet])
		return;
	NSTimeInterval away = [NSDate timeIntervalSinceReferenceDate] - self.leftAt;
	NSInteger grace = [self autoLockSeconds];
	if (!self.locked && grace > 0 && away < (NSTimeInterval)grace)
		return;
	self.locked = YES;
	self.covering = NO;
	[self showWindowLocked:YES];
}

- (void)applicationDidBecomeActive {
	if (self.locked) {
		[self showWindowLocked:YES];
		return;
	}
	if (self.covering) {
		if ([self isLockedOrWillLockOnReturn]) {
			self.locked = YES;
			self.covering = NO;
			[self showWindowLocked:YES];
			return;
		}
		self.covering = NO;
		[self hideWindow];
	}
}

@end
