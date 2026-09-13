#import "TGPremiumViewController.h"
#import "TGPremiumViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGClient+Premium.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGHexColour.h"

static const CGFloat kPremiumHeaderHeight = 86.0f;

@implementation TGPremiumViewController (Header)

- (void)buildHeader {
	CGFloat width = self.view.bounds.size.width ?: [UIScreen mainScreen].bounds.size.width;
	UIView *header = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, width, kPremiumHeaderHeight)];
	header.backgroundColor = [UIColor clearColor];
	header.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	UIImageView *badge = [[UIImageView alloc] initWithFrame:CGRectMake(9, 14, 70, 70)];
	badge.image = [TGIcons avatarWithInitials:@"★" size:70 colourId:2];
	badge.layer.cornerRadius = 10.0f;
	badge.clipsToBounds = YES;
	[header addSubview:badge];
	self.headerBadgeView = badge;

	UILabel *title = [[UILabel alloc] initWithFrame:
			CGRectMake(94, 24, width - 94 - 9, 24)];
	title.text = TGL(@"Settings.Premium", @"Telegram Premium");
	title.font = [UIFont boldSystemFontOfSize:19];
	title.backgroundColor = [UIColor clearColor];
	title.textColor = TGColourFromHex(0x222932);
	title.shadowColor = [UIColor colorWithRed:0xed / 255.0f green:0xf0 / 255.0f
										 blue:0xf5 / 255.0f
										alpha:0.28f];
	title.shadowOffset = CGSizeMake(0, 1);
	title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[header addSubview:title];
	self.headerTitleLabel = title;

	UILabel *status = [[UILabel alloc] initWithFrame:
			CGRectMake(94, 52, width - 94 - 9, 24)];
	status.text = TGL(@"Premium.StatusChecking", @"checking...");
	status.font = [UIFont systemFontOfSize:14];
	status.backgroundColor = [UIColor clearColor];
	status.textColor = TGColourFromHex(0x6d7d90);
	status.shadowColor = title.shadowColor;
	status.shadowOffset = CGSizeMake(0, 1);
	status.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[header addSubview:status];
	self.headerStatusLabel = status;

	self.tableView.tableHeaderView = header;
	[self refreshHeader];
}

- (void)refreshHeader {
	if (!self.headerStatusLabel)
		return;

	BOOL active = [[TGClient shared] isPremiumAccount];
	NSString *line = nil;

	if (self.subscription) {
		active = [self.subscription[@"active"] boolValue];
		NSString *expires = self.subscription[@"expiresText"];
		if ([expires isKindOfClass:[NSString class]] && expires.length)
			line = expires;
	} else if (!self.subscriptionLoaded) {
		line = TGL(@"Premium.StatusChecking", @"checking...");
	}

	if (!line.length)
		line = active ? TGL(@"Premium.ActiveOnThisAccount", @"Active on this account") : TGL(@"Premium.NotActiveOnThisAccount", @"Not active on this account");
	self.headerStatusLabel.text = line;
	if (!self.stickerShown) {
		int64_t colourId = active ? 2 : 6;
		self.headerBadgeView.image = [TGIcons avatarWithInitials:@"★" size:70 colourId:colourId];
	}
}

@end
