#import "TGChecklistTaskRowView.h"
#import "TGEmoji.h"
#import "TGTheme.h"

@interface TGChecklistTaskRowView ()

@property (nonatomic, strong, readwrite) UIView *checkbox;
@property (nonatomic, strong, readwrite) UILabel *titleLabel;

@end

@implementation TGChecklistTaskRowView

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self)
		return nil;

	self.checkbox = [[UIView alloc] init];
	self.checkbox.layer.cornerRadius = 3;
	self.checkbox.layer.borderWidth = 1;
	self.checkbox.layer.borderColor = [[TGTheme shared] accentColour].CGColor;
	[self addSubview:self.checkbox];

	self.titleLabel = [[TGEmojiLabel alloc] init];
	self.titleLabel.font = [UIFont systemFontOfSize:14];
	self.titleLabel.backgroundColor = [UIColor clearColor];
	[self addSubview:self.titleLabel];

	return self;
}

- (void)setChecked:(BOOL)checked title:(NSString *)title completedByName:(NSString *)completedByName {
	self.checkbox.backgroundColor = checked ? [[TGTheme shared] accentColour] : [UIColor clearColor];
	if (checked) {
		NSMutableAttributedString *struck = [[NSMutableAttributedString alloc] initWithString:title ?: @""];
		NSRange titleRange = NSMakeRange(0, struck.length);
		[struck addAttribute:NSFontAttributeName value:self.titleLabel.font range:titleRange];
		[struck addAttribute:NSForegroundColorAttributeName
					   value:self.titleLabel.textColor
					   range:titleRange];
		[struck addAttribute:NSStrikethroughStyleAttributeName
					   value:@(NSUnderlineStyleSingle)
					   range:titleRange];
		if (completedByName.length) {
			NSString *suffix = [NSString stringWithFormat:@"  · %@", completedByName];
			NSMutableAttributedString *suffixString = [[NSMutableAttributedString alloc] initWithString:suffix];
			[suffixString addAttribute:NSForegroundColorAttributeName
								  value:[[TGTheme shared] secondaryTextColour]
								  range:NSMakeRange(0, suffixString.length)];
			[struck appendAttributedString:suffixString];
		}
		self.titleLabel.attributedText = struck;
	} else {
		self.titleLabel.attributedText = nil;
		self.titleLabel.text = title;
	}
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect bounds = self.bounds;
	self.checkbox.frame = CGRectMake(0, (bounds.size.height - 16) / 2, 16, 16);
	self.titleLabel.frame = CGRectMake(24, 0, bounds.size.width - 24, bounds.size.height);
}

@end
