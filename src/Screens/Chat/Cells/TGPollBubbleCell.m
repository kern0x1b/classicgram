#import "TGPollBubbleCell.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"
#import "TGMessage.h"
#import "TGPollContent.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGRichText.h"

@interface TGPollBubbleCell ()

@property (nonatomic, strong, readwrite) TGEmojiLabel *body;
@property (nonatomic, strong, readwrite) UILabel *subtitle;
@property (nonatomic, strong, readwrite) UIButton *retractButton;
@property (nonatomic, strong, readwrite) UIButton *addButton;
@property (nonatomic, strong, readwrite) TGEmojiLabel *explanationLabel;
@property (nonatomic, strong) NSMutableArray<TGPollOptionRowView *> *options;

@end

@implementation TGPollBubbleCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.body = [[TGEmojiLabel alloc] init];
	self.body.numberOfLines = 0;
	self.body.lineBreakMode = NSLineBreakByWordWrapping;
	self.body.font = [UIFont boldSystemFontOfSize:15];
	self.body.textColor = [[TGTheme shared] primaryTextColour];
	self.body.backgroundColor = [UIColor clearColor];
	[self.bubble addSubview:self.body];

	self.subtitle = [[UILabel alloc] init];
	self.subtitle.font = [UIFont systemFontOfSize:12];
	self.subtitle.textColor = [[TGTheme shared] secondaryTextColour];
	self.subtitle.backgroundColor = [UIColor clearColor];
	self.subtitle.hidden = YES;
	[self.bubble addSubview:self.subtitle];

	self.retractButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.retractButton.hidden = YES;
	self.retractButton.titleLabel.font = [UIFont systemFontOfSize:14];
	[self.retractButton setTitle:TGL(@"Conversation.UnvotePoll", @"Retract Vote")
						forState:UIControlStateNormal];
	[self.retractButton setTitleColor:[[TGTheme shared] accentColour] forState:UIControlStateNormal];
	[self.retractButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];
	[self.retractButton addTarget:self action:@selector(tg_retractTapped)
				 forControlEvents:UIControlEventTouchUpInside];
	[self.bubble addSubview:self.retractButton];

	self.addButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.addButton.hidden = YES;
	self.addButton.titleLabel.font = [UIFont systemFontOfSize:14];
	[self.addButton setTitle:TGL(@"CreatePoll.AddOption", @"Add an Option")
					forState:UIControlStateNormal];
	[self.addButton setTitleColor:[[TGTheme shared] accentColour] forState:UIControlStateNormal];
	[self.addButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];
	[self.addButton addTarget:self action:@selector(tg_addTapped)
			 forControlEvents:UIControlEventTouchUpInside];
	[self.bubble addSubview:self.addButton];

	self.explanationLabel = [[TGEmojiLabel alloc] init];
	self.explanationLabel.font = [UIFont systemFontOfSize:13];
	self.explanationLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.explanationLabel.backgroundColor = [UIColor clearColor];
	self.explanationLabel.numberOfLines = 0;
	self.explanationLabel.hidden = YES;
	[self.bubble addSubview:self.explanationLabel];

	self.options = [NSMutableArray array];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.pollMessageId = 0;
	self.body.richLayout = nil;
	self.explanationLabel.richLayout = nil;
	self.explanationLabel.hidden = YES;
	self.retractButton.hidden = YES;
	self.addButton.hidden = YES;
	for (TGPollOptionRowView *option in self.options)
		[option setFraction:0 percentValue:0 chosen:NO closed:NO resultsVisible:NO markState:TGPollOptionMarkStateNone];
}

- (NSUInteger)optionCount {
	return self.options.count;
}

- (TGPollOptionRowView *)optionAtIndex:(NSUInteger)index {
	while (self.options.count <= index) {
		TGPollOptionRowView *option = [[TGPollOptionRowView alloc] init];
		option.tag = (NSInteger)self.options.count;
		[option addTarget:self action:@selector(tg_optionTapped:)
			forControlEvents:UIControlEventTouchUpInside];
		[self.bubble addSubview:option];
		[self.options addObject:option];
	}
	return self.options[index];
}

- (void)applyItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout {
	[super applyItem:item layout:layout];

	self.pollMessageId = item.messageId;

	self.body.hidden = !(layout.parts & TGMessageLayoutPartBody);
	if (layout.parts & TGMessageLayoutPartBody) {
		self.body.frame = layout.bubble.body;
		self.body.text = item.pollQuestionText;
	}

	self.subtitle.hidden = !(layout.parts & TGMessageLayoutPartSubtitle);
	if (layout.parts & TGMessageLayoutPartSubtitle) {
		self.subtitle.frame = layout.bubble.subtitle;
		self.subtitle.text = item.pollSubtitleText;
	}

	TGPollContent *poll = [item.message.content isKindOfClass:TGPollContent.class]
		? (TGPollContent *)item.message.content
		: nil;
	BOOL quizAnswered = poll.quiz && poll.correctOptionId >= 0;
	BOOL resultsVisible = poll.totalVoterCount > 0;

	NSInteger visibleOptions = 0;
	NSInteger count = layout.repeatedRowCount;
	for (NSInteger i = 0; i < count; i++) {
		TGMessageLayoutRepeatedRow row = [layout repeatedRowAtIndex:i];
		switch (row.kind) {
			case TGMessageLayoutRowPollOption: {
				TGPollOptionRowView *option = [self optionAtIndex:row.index];
				option.frame = row.frame;
				option.hidden = NO;
				option.titleLabel.text = [self.delegate respondsToSelector:
												 @selector(bubbleCell:pollOptionTitleAtIndex:atRow:)]
					? [self.delegate bubbleCell:self
						  pollOptionTitleAtIndex:row.index
										   atRow:self.appliedRow]
					: @"";
				CGFloat fraction = [self.delegate respondsToSelector:
										   @selector(bubbleCell:pollOptionFractionAtIndex:atRow:)]
					? [self.delegate bubbleCell:self
						  pollOptionFractionAtIndex:row.index
											  atRow:self.appliedRow]
					: 0;
				NSInteger percentValue = [self.delegate respondsToSelector:
										   @selector(bubbleCell:pollOptionPercentValueAtIndex:atRow:)]
					? [self.delegate bubbleCell:self
						  pollOptionPercentValueAtIndex:row.index
												  atRow:self.appliedRow]
					: 0;
				BOOL chosen = [self.delegate respondsToSelector:
									  @selector(bubbleCell:pollOptionIsChosenAtIndex:atRow:)]
					? [self.delegate bubbleCell:self
						  pollOptionIsChosenAtIndex:row.index
											  atRow:self.appliedRow]
					: NO;
				TGPollOptionMarkState markState = TGPollOptionMarkStateNone;
				if (quizAnswered) {
					if ((NSInteger)row.index == poll.correctOptionId)
						markState = TGPollOptionMarkStateCorrect;
					else if (chosen)
						markState = TGPollOptionMarkStateWrong;
				}
				[option setFraction:fraction percentValue:percentValue chosen:chosen closed:poll.closed resultsVisible:resultsVisible markState:markState];
				visibleOptions++;
				break;
			}
			case TGMessageLayoutRowPollRetract:
				self.retractButton.hidden = NO;
				self.retractButton.frame = row.frame;
				break;
			case TGMessageLayoutRowPollAdd:
				self.addButton.hidden = NO;
				self.addButton.frame = row.frame;
				break;
			case TGMessageLayoutRowPollExplanation: {
				self.explanationLabel.hidden = NO;
				self.explanationLabel.frame = row.frame;
				self.explanationLabel.text = poll.explanation;
				if (poll.explanationEntities.count) {
					TGRichTextPalette *palette =
						[TGRichTextPalette paletteWithFont:self.explanationLabel.font
													 colour:self.explanationLabel.textColor
												 linkColour:[[TGTheme shared] accentColour]
											   accentColour:[[TGTheme shared] accentColour]];
					NSAttributedString *styled = TGRichTextBuild(poll.explanation,
						poll.explanationEntities, palette, NO);
					self.explanationLabel.richLayout = [TGRichTextLayout
						layoutWithText:styled
								 width:row.frame.size.width
							  maxLines:0
							 alignment:NSTextAlignmentLeft
						expandedBlocks:nil];
				} else {
					self.explanationLabel.richLayout = nil;
				}
				break;
			}
			default:
				break;
		}
	}
	for (NSInteger i = visibleOptions; i < self.options.count; i++)
		self.options[i].hidden = YES;

	self.isAccessibilityElement = YES;
	self.accessibilityLabel = [self tg_accessibilityLabelWithParts:@[
		item.senderDisplayName ?: @"",
		TGL(@"AttachmentMenu.Poll", @"Poll"),
		item.pollQuestionText ?: @"",
		item.pollSubtitleText ?: @"",
		item.stampText ?: @"",
	]];
}

- (void)tg_optionTapped:(TGPollOptionRowView *)option {
	if (![self.delegate respondsToSelector:@selector(bubbleCell:didTapPollOptionAtIndex:atRow:)])
		return;
	[self.delegate bubbleCell:self
		didTapPollOptionAtIndex:(NSUInteger)option.tag
						  atRow:self.appliedRow];
}

- (void)tg_retractTapped {
	[self.delegate bubbleCell:self didTapPart:TGBubbleCellPartPollRetract atRow:self.appliedRow];
}

- (void)tg_addTapped {
	[self.delegate bubbleCell:self didTapPart:TGBubbleCellPartPollAdd atRow:self.appliedRow];
}

@end
