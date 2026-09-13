#import "TGSavedMessagesViewControllerInternal.h"
#import "TGEmoji.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGSingleLinePreview.h"
#import "TGLocalization.h"

@interface TGSavedTopicCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatar;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *previewLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UIImageView *pinIcon;
@property (nonatomic, strong) UIImageView *arrow;
@end

@implementation TGSavedTopicCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.avatar = [[UIImageView alloc] initWithFrame:
			CGRectMake(kSavedAvatarLeft, 8, kSavedAvatar, kSavedAvatar)];
	self.avatar.layer.cornerRadius = 5.0f;
	self.avatar.clipsToBounds = YES;
	self.avatar.backgroundColor = [UIColor clearColor];
	self.avatar.contentMode = UIViewContentModeScaleAspectFill;
	[self.contentView addSubview:self.avatar];

	self.titleLabel = [[TGEmojiLabel alloc] init];
	self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
	self.titleLabel.backgroundColor = [UIColor clearColor];
	self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.contentView addSubview:self.titleLabel];

	self.previewLabel = [[TGEmojiLabel alloc] init];
	self.previewLabel.font = [UIFont systemFontOfSize:14];
	self.previewLabel.backgroundColor = [UIColor clearColor];
	self.previewLabel.numberOfLines = 2;
	self.previewLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.contentView addSubview:self.previewLabel];

	self.dateLabel = [[UILabel alloc] init];
	self.dateLabel.font = [UIFont systemFontOfSize:13];
	self.dateLabel.textAlignment = NSTextAlignmentRight;
	self.dateLabel.backgroundColor = [UIColor clearColor];
	[self.contentView addSubview:self.dateLabel];

	self.pinIcon = [[UIImageView alloc] initWithImage:[TGIcons menuGlyphNamed:@"pin"]];
	self.pinIcon.hidden = YES;
	[self.contentView addSubview:self.pinIcon];

	self.arrow = [[UIImageView alloc] initWithImage:TGLocalizedDirectionalImage([UIImage imageNamed:@"DialogListArrow.png"])];
	[self.contentView addSubview:self.arrow];

	UIImage *plate = [[UIImage imageNamed:@"DialogListCell.png"]
		stretchableImageWithLeftCapWidth:1
							topCapHeight:0];
	UIImage *platePressed = [[UIImage imageNamed:@"DialogListCellHighlighted.png"]
		stretchableImageWithLeftCapWidth:1
							topCapHeight:0];
	self.backgroundView = [[UIImageView alloc] initWithImage:plate];
	self.selectedBackgroundView = [[UIImageView alloc] initWithImage:platePressed];

	self.accessoryType = UITableViewCellAccessoryNone;
	self.selectionStyle = UITableViewCellSelectionStyleBlue;
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGFloat w = self.contentView.bounds.size.width;
	CGFloat left = kSavedTextLeft;

	self.avatar.frame = CGRectMake(kSavedAvatarLeft, 8, kSavedAvatar, kSavedAvatar);

	CGFloat dateWidth = (int)[self.dateLabel.text sizeWithFont:self.dateLabel.font].width;
	CGFloat dateX = w - dateWidth - 9;
	self.dateLabel.frame = CGRectMake(dateX - (75 - dateWidth), 9, 75, 15);

	CGSize pinSize = self.pinIcon.image ? self.pinIcon.image.size : CGSizeZero;
	if (!self.pinIcon.hidden && pinSize.width > 0) {
		self.pinIcon.frame = CGRectMake(dateX - pinSize.width - 5,
			9 + (15 - pinSize.height) / 2.0f, pinSize.width, pinSize.height);
		dateX -= pinSize.width + 5;
	}

	CGFloat titleWidth = (int)(dateX - 4 - left - 18);
	titleWidth = MIN(titleWidth, [self.titleLabel.text sizeWithFont:self.titleLabel.font].width);
	if (titleWidth < 0)
		titleWidth = 0;
	self.titleLabel.frame = CGRectMake(left, 6, titleWidth, 20);

	self.previewLabel.frame = CGRectMake(left, 29, w - left - 26, 40);

	CGSize arrowSize = self.arrow.image ? self.arrow.image.size : CGSizeZero;
	self.arrow.frame = CGRectMake(w - arrowSize.width - 6, 33, arrowSize.width, arrowSize.height);
}

@end

@implementation TGSavedMessagesViewController (Cells)

- (UITableViewCell *)messageCellForRow:(NSInteger)row inTable:(UITableView *)tableView {
	static NSString *reuse = @"TGSavedMessageCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:reuse];

	TGTheme *theme = [TGTheme shared];
	[theme styleCell:cell];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;

	cell.textLabel.font = [UIFont systemFontOfSize:15];
	cell.textLabel.textColor = [theme primaryTextColour];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.textColor = [theme secondaryTextColour];
	cell.textLabel.text = @"";
	cell.detailTextLabel.text = @"";

	if (row < 0 || row >= (NSInteger)self.messageHits.count)
		return cell;

	NSDictionary *message = self.messageHits[row];
	NSString *text = message[@"text"];
	NSString *kindLabel = TGSavedKindLabel(message[@"kind"]);
	BOOL hasText = [text isKindOfClass:NSString.class] && text.length;
	cell.textLabel.text = hasText
		? text
		: (kindLabel.length ? kindLabel : TGL(@"PeerInfo.PaneMedia", @"Media"));

	NSString *stamp = TGSavedDate([message[@"date"] doubleValue]);
	NSString *detail = (kindLabel.length && ![kindLabel isEqualToString:cell.textLabel.text])
		? kindLabel
		: @"";
	cell.detailTextLabel.text = (detail.length && stamp.length)
		? [NSString stringWithFormat:@"%@  %@", detail, stamp]
		: (detail.length ? detail : stamp);
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (![self sectionHoldsTopics:indexPath.section])
		return [self messageCellForRow:indexPath.row inTable:tableView];

	static NSString *reuse = @"TGSavedTopicCell";
	TGSavedTopicCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGSavedTopicCell alloc] initWithStyle:UITableViewCellStyleDefault
									   reuseIdentifier:reuse];

	TGTheme *theme = [TGTheme shared];
	cell.backgroundColor = [theme listBackgroundColour];
	cell.backgroundView.hidden = NO;
	cell.titleLabel.textColor = [theme primaryTextColour];
	cell.previewLabel.textColor = [theme secondaryTextColour];
	cell.dateLabel.textColor = [theme accentColour];
	cell.dateLabel.text = @"";
	cell.previewLabel.text = @"";
	cell.titleLabel.text = @"";
	cell.avatar.image = nil;
	cell.pinIcon.hidden = YES;

	NSArray *rows = [self topicRows];
	if (indexPath.row >= (NSInteger)rows.count)
		return cell;

	NSDictionary *topic = rows[indexPath.row];
	cell.titleLabel.text = TGSavedTopicTitle(topic);

	NSString *draft = topic[@"draft"];
	NSString *text = topic[@"text"];
	if ([draft isKindOfClass:NSString.class] && draft.length) {
		cell.previewLabel.text = TGSingleLinePreviewText([NSString stringWithFormat:@"%@ %@",
			TGL(@"DialogList.Draft", @"Draft:"), draft]);
	} else if ([text isKindOfClass:NSString.class] && text.length) {
		cell.previewLabel.text = TGSingleLinePreviewText([topic[@"outgoing"] boolValue]
			? [NSString stringWithFormat:@"%@: %@", TGL(@"DialogList.You", @"You"), text]
			: text);
	}

	cell.dateLabel.text = TGSavedDate([topic[@"date"] doubleValue]);
	cell.pinIcon.hidden = ![topic[@"isPinned"] boolValue];
	if (!cell.pinIcon.hidden)
		cell.pinIcon.image = [TGIcons menuGlyphNamed:@"pin"];
	cell.avatar.image = [self avatarForTopic:topic];

	[cell setNeedsLayout];
	return cell;
}

@end
