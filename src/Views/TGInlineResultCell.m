#import "TGInlineResultCell.h"
#import "TGTheme.h"
#import "TGLocalization.h"

static NSString *TGInlineResultKindLabel(NSString *kind) {
	if ([kind isEqualToString:@"photo"])
		return TGL(@"Message.Photo", @"Photo");
	if ([kind isEqualToString:@"video"])
		return TGL(@"Message.Video", @"Video");
	if ([kind isEqualToString:@"animation"])
		return TGL(@"Message.Animation", @"GIF");
	if ([kind isEqualToString:@"sticker"])
		return TGL(@"Message.Sticker", @"Sticker");
	if ([kind isEqualToString:@"document"])
		return TGL(@"Message.File", @"File");
	if ([kind isEqualToString:@"audio"])
		return TGL(@"Attachment.Audio", @"Audio");
	if ([kind isEqualToString:@"voiceNote"])
		return TGL(@"Message.Audio", @"Voice message");
	if ([kind isEqualToString:@"location"])
		return TGL(@"Message.Location", @"Location");
	if ([kind isEqualToString:@"venue"])
		return TGL(@"Story.Areas.Venue", @"Venue");
	if ([kind isEqualToString:@"contact"])
		return TGL(@"Message.Contact", @"Contact");
	if ([kind isEqualToString:@"game"])
		return TGL(@"Message.Game", @"Game");
	if ([kind isEqualToString:@"article"])
		return TGL(@"Attachment.Article", @"Article");
	return @"";
}

@implementation TGInlineResultCell

+ (NSString *)reuseIdentifier {
	return @"TGInlineResultCell";
}

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
	if (self != nil)
		[[TGTheme shared] styleCell:self];
	return self;
}

- (void)configureWithResult:(NSDictionary *)result {
	NSString *title = result[@"title"];
	self.textLabel.text = title.length ? title : TGInlineResultKindLabel(result[@"kind"]);
	self.textLabel.font = [UIFont boldSystemFontOfSize:15];
	self.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	self.detailTextLabel.text = result[@"description"];
	self.detailTextLabel.font = [UIFont systemFontOfSize:13];
	self.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.imageView.image = nil;
	self.textLabel.textAlignment = NSTextAlignmentLeft;
	self.accessoryType = UITableViewCellAccessoryNone;
}

- (void)configureAsButtonWithText:(NSString *)text {
	self.textLabel.text = text.length ? text : TGL(@"Chat.StartBot", @"Start Bot");
	self.textLabel.font = [UIFont boldSystemFontOfSize:15];
	self.textLabel.textColor = [[TGTheme shared] accentColour];
	self.textLabel.textAlignment = NSTextAlignmentCenter;
	self.detailTextLabel.text = nil;
	self.imageView.image = nil;
	self.accessoryType = UITableViewCellAccessoryNone;
}

@end
