#import "TGChecklistBubbleCell.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"
#import "TGTheme.h"
#import "TGLocalization.h"

@interface TGChecklistBubbleCell ()

@property (nonatomic, strong, readwrite) TGEmojiLabel *body;
@property (nonatomic, strong, readwrite) UIButton *addButton;
@property (nonatomic, strong) NSMutableArray<TGChecklistTaskRowView *> *tasks;

@end

@implementation TGChecklistBubbleCell

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

	self.addButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.addButton.hidden = YES;
	self.addButton.titleLabel.font = [UIFont systemFontOfSize:14];
	[self.addButton setTitle:TGL(@"CreateTodo.AddTitle", @"Add a Task")
					forState:UIControlStateNormal];
	[self.addButton setTitleColor:[[TGTheme shared] accentColour] forState:UIControlStateNormal];
	[self.addButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];
	[self.addButton addTarget:self action:@selector(tg_addTapped)
			 forControlEvents:UIControlEventTouchUpInside];
	[self.bubble addSubview:self.addButton];

	self.tasks = [NSMutableArray array];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.checklistMessageId = 0;
	self.checklistTaskIds = nil;
	self.body.richLayout = nil;
}

- (NSUInteger)taskCount {
	return self.tasks.count;
}

- (TGChecklistTaskRowView *)taskAtIndex:(NSUInteger)index {
	while (self.tasks.count <= index) {
		TGChecklistTaskRowView *task = [[TGChecklistTaskRowView alloc] init];
		task.tag = (NSInteger)self.tasks.count;
		[task addTarget:self action:@selector(tg_taskTapped:)
			forControlEvents:UIControlEventTouchUpInside];
		UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self action:@selector(tg_taskHeld:)];
		hold.minimumPressDuration = 0.24;
		[task addGestureRecognizer:hold];
		[self.bubble addSubview:task];
		[self.tasks addObject:task];
	}
	return self.tasks[index];
}

- (void)applyItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout {
	[super applyItem:item layout:layout];

	self.checklistMessageId = item.messageId;

	self.body.hidden = !(layout.parts & TGMessageLayoutPartBody);
	if (layout.parts & TGMessageLayoutPartBody) {
		self.body.frame = layout.bubble.body;
		self.body.text = item.checklistTitleText;
	}

	self.addButton.hidden = YES;
	NSInteger visibleTasks = 0;
	NSInteger count = layout.repeatedRowCount;
	for (NSInteger i = 0; i < count; i++) {
		TGMessageLayoutRepeatedRow row = [layout repeatedRowAtIndex:i];
		if (row.kind == TGMessageLayoutRowChecklistTask) {
			TGChecklistTaskRowView *task = [self taskAtIndex:row.index];
			task.frame = row.frame;
			task.hidden = NO;
			NSString *title = [self.delegate respondsToSelector:
									  @selector(bubbleCell:checklistTaskTitleAtIndex:atRow:)]
				? [self.delegate bubbleCell:self
					  checklistTaskTitleAtIndex:row.index
										  atRow:self.appliedRow]
				: @"";
			BOOL checked = [self.delegate respondsToSelector:
								   @selector(bubbleCell:checklistTaskIsCheckedAtIndex:atRow:)]
				? [self.delegate bubbleCell:self
					  checklistTaskIsCheckedAtIndex:row.index
											  atRow:self.appliedRow]
				: NO;
			NSString *completedBy = [self.delegate respondsToSelector:
								   @selector(bubbleCell:checklistTaskCompletedByAtIndex:atRow:)]
				? [self.delegate bubbleCell:self
					  checklistTaskCompletedByAtIndex:row.index
											  atRow:self.appliedRow]
				: @"";
			[task setChecked:checked title:title completedByName:completedBy];
			visibleTasks++;
		} else if (row.kind == TGMessageLayoutRowChecklistAdd) {
			self.addButton.hidden = NO;
			self.addButton.frame = row.frame;
		}
	}
	for (NSInteger i = visibleTasks; i < self.tasks.count; i++)
		self.tasks[i].hidden = YES;
}

- (void)tg_taskTapped:(TGChecklistTaskRowView *)task {
	if (![self.delegate respondsToSelector:@selector(bubbleCell:didTapChecklistTaskAtIndex:atRow:)])
		return;
	[self.delegate bubbleCell:self
		didTapChecklistTaskAtIndex:(NSUInteger)task.tag
							 atRow:self.appliedRow];
}

- (void)tg_taskHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	if (![self.delegate respondsToSelector:@selector(bubbleCell:didLongPressChecklistTaskAtIndex:atRow:)])
		return;
	[self.delegate bubbleCell:self
		didLongPressChecklistTaskAtIndex:(NSUInteger)hold.view.tag
									atRow:self.appliedRow];
}

- (void)tg_addTapped {
	[self.delegate bubbleCell:self didTapPart:TGBubbleCellPartChecklistAdd atRow:self.appliedRow];
}

@end
