#import "TGGroupedCaption.h"
#import "TGTextFieldStyle.h"
#import "TGClient+ChatState.h"
#import "TGFoldersViewController.h"
#import "TGFoldersInternal.h"
#import "TGLocalization.h"
#import "TGClient+ChatList.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGFileDownloadService.h"
#import "TGImageDecode.h"
#import "TGHexColour.h"

@implementation TGFoldersViewController (Cells)

#pragma mark - cells

- (UIImage *)avatarForChatId:(int64_t)chatId title:(NSString *)title {
	NSNumber *key = @(chatId);
	UIImage *cached = self.avatarImages[key];
	if (cached)
		return cached;

	NSString *initials = [self initialsForTitle:title];
	UIImage *placeholder = [TGIcons avatarWithInitials:initials size:40 colourId:chatId];
	self.avatarImages[key] = placeholder;

	if ([self.avatarsRequested containsObject:key])
		return placeholder;
	[self.avatarsRequested addObject:key];

	__weak typeof(self) weakSelf = self;
	void (^fetch)(NSNumber *) = ^(NSNumber *fileId){
		if (!fileId || [fileId longLongValue] <= 0)
			return;
		[TGFileDownloadService downloadFile:[fileId longLongValue] completion:^(NSString *path){
			if (!path.length)
				return;
			dispatch_async(TGImageDecodeQueue(), ^{
				UIImage *photo = TGDecodeSquareThumbnail(path, 40);
				if (!photo)
					return;
				dispatch_async(dispatch_get_main_queue(), ^{
					TGFoldersViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					strongSelf.avatarImages[key] = photo;
					if (!strongSelf.avatarReload)
						strongSelf.avatarReload = [[TGTableReloadCoalescer alloc]
							initWithTableView:strongSelf.tableView];
					[strongSelf.avatarReload setNeedsReload];
				});
			});
		}];
	};

	NSNumber *cachedFile = [[TGClient shared] photoFileIdForChat:chatId];
	if (cachedFile && cachedFile.integerValue > 0){
		fetch(cachedFile);
		return placeholder;
	}
	[[TGClient shared] photoFileIdForChat:chatId completion:fetch];
	return placeholder;
}

- (UIView *)disclosureAccessory {
	UIImage *art = TGLocalizedDirectionalImage([UIImage imageNamed:@"MenuDisclosureIndicator.png"]);
	if (!art)
		return nil;
	UIImage *highlighted = [UIImage imageNamed:@"MenuDisclosureIndicator_Highlighted.png"];
	UIImageView *view = [[UIImageView alloc] initWithImage:art
										  highlightedImage:highlighted];
	view.frame = CGRectMake(0, 0, art.size.width, art.size.height);
	return view;
}

- (void)markDisclosure:(UITableViewCell *)cell {
	UIView *chevron = [self disclosureAccessory];
	if (chevron) {
		cell.accessoryView = chevron;
		cell.accessoryType = UITableViewCellAccessoryNone;
	} else {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
}

- (void)markChecked:(BOOL)checked on:(UITableViewCell *)cell {
	cell.accessoryView = nil;
	cell.textLabel.textColor = checked ? [[TGTheme shared] groupedInfoColour]
									   : [[TGTheme shared] groupedTitleColour];
	if (!checked) {
		cell.accessoryType = UITableViewCellAccessoryNone;
		return;
	}
	UIImage *art = [UIImage imageNamed:@"ListCheck.png"];
	if (art) {
		UIImageView *view = [[UIImageView alloc] initWithImage:art];
		view.frame = CGRectMake(0, 0, art.size.width, art.size.height);
		cell.accessoryView = view;
		cell.accessoryType = UITableViewCellAccessoryNone;
	} else {
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	}
}

- (UITableViewCell *)plainCellFor:(UITableView *)tableView identifier:(NSString *)identifier
							style:(UITableViewCellStyle)style {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:identifier];
	cell.accessoryView = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.imageView.image = nil;
	cell.detailTextLabel.text = nil;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	[[TGTheme shared] styleCell:cell];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	switch (self.page) {
		case TGFoldersPageEditor:
			return [self editorCellFor:tableView at:indexPath];
		case TGFoldersPageChatPicker:
			return [self pickerCellFor:tableView at:indexPath];
		case TGFoldersPageIconPicker:
			return [self iconCellFor:tableView at:indexPath];
		default:
			return [self listCellFor:tableView at:indexPath];
	}
}

- (NSString *)glyphForIconName:(NSString *)name {
	if (![name isKindOfClass:[NSString class]] || !name.length)
		return nil;
	NSString *symbol = [[TGClient shared] symbolForFolderIconName:name];
	return symbol.length ? symbol : nil;
}

- (UITableViewCell *)listCellFor:(UITableView *)tableView at:(NSIndexPath *)indexPath {
	if (indexPath.section == 2) {
		UITableViewCell *cell = [self plainCellFor:tableView identifier:@"TGFolderSuggested"
											 style:UITableViewCellStyleValue1];
		NSDictionary *entry = self.recommended[indexPath.row];
		NSString *title = entry[@"title"];
		NSString *glyph = [self glyphForIconName:entry[@"icon"]];
		if (![title isKindOfClass:[NSString class]] || !title.length)
			title = TGL(@"ChatListFolder.DefaultTitle", @"Folder");
		cell.textLabel.text = glyph
				? [NSString stringWithFormat:@"%@  %@", glyph, title] : title;
		cell.detailTextLabel.text = TGL(@"Contacts.AddContact", @"Add");
		cell.detailTextLabel.textColor = [[TGTheme shared] groupedActionColour];
		return cell;
	}

	if (indexPath.section == 1 && indexPath.row == 1) {
		UITableViewCell *cell = [self plainCellFor:tableView identifier:@"TGFolderTags"
											 style:UITableViewCellStyleDefault];
		cell.textLabel.text = TGL(@"Premium.FolderTags", @"Chat Folder Tags");
		cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		UISwitch *toggle = [[UISwitch alloc] init];
		toggle.on = [TGClient shared].folderTagsEnabled;
		[toggle addTarget:self action:@selector(folderTagsToggled:)
		 forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
		return cell;
	}

	if (indexPath.section == 1) {
		UITableViewCell *cell = [self plainCellFor:tableView identifier:@"TGFolderAction"
											 style:UITableViewCellStyleDefault];
		cell.textLabel.text = TGL(@"ChatListFolderSettings.NewFolder", @"Create New Folder");
		cell.textLabel.textColor = [[TGTheme shared] groupedActionColour];
		return cell;
	}

	NSInteger folderIndex = [self folderIndexForRow:indexPath.row];
	if (folderIndex < 0) {
		UITableViewCell *cell = [self plainCellFor:tableView identifier:@"TGFolderAllChats"
											 style:UITableViewCellStyleValue1];
		cell.textLabel.text = TGL(@"HashtagSearch.AllChats", @"All Chats");
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}
	if (folderIndex >= (NSInteger)self.folders.count)
		return [self plainCellFor:tableView identifier:@"TGFolderRow"
							style:UITableViewCellStyleValue1];

	UITableViewCell *cell = [self plainCellFor:tableView identifier:@"TGFolderRow"
										 style:UITableViewCellStyleValue1];
	NSDictionary *folder = self.folders[folderIndex];
	NSString *title = folder[@"title"];
	if (![title isKindOfClass:[NSString class]] || !title.length)
		title = TGL(@"ChatListFolder.DefaultTitle", @"Folder");
	NSString *glyph = [self glyphForIconName:self.icons[folder[@"id"]]];
	cell.textLabel.text = glyph ? [NSString stringWithFormat:@"%@  %@", glyph, title] : title;
	NSNumber *count = self.counts[folder[@"id"]];
	if (count)
		cell.detailTextLabel.text = TGLPlural(@"FolderLinkPreview.TextAddChatsCount", count.integerValue, @"%d chat", @"%d chats");
	[self markDisclosure:cell];
	return cell;
}

- (UITableViewCell *)editorCellFor:(UITableView *)tableView at:(NSIndexPath *)indexPath {
	if (indexPath.section == 0 && indexPath.row == 0) {
		UITableViewCell *cell = [self plainCellFor:tableView identifier:@"TGFolderName"
											 style:UITableViewCellStyleDefault];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		if (!self.nameField) {
			CGFloat width = tableView.bounds.size.width;
			self.nameField = [[UITextField alloc] initWithFrame:
					CGRectMake(15, 12, width - 30 - 15, 22)];
			self.nameField.placeholder = TGL(@"ChatListFolder.NamePlaceholder", @"Folder Name");
			self.nameField.font = TGTextFieldFont();
			self.nameField.textColor = [[TGTheme shared] primaryTextColour];
			self.nameField.delegate = self;
			self.nameField.returnKeyType = UIReturnKeyDone;
			self.nameField.clearButtonMode = UITextFieldViewModeWhileEditing;
			self.nameField.autocorrectionType = UITextAutocorrectionTypeNo;
			self.nameField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
			TGStyleTextField(self.nameField);
			[self.nameField addTarget:self action:@selector(nameChanged:)
					 forControlEvents:UIControlEventEditingChanged];
			NSString *title = self.draft[@"title"];
			self.nameField.text = [title isKindOfClass:[NSString class]] ? title : @"";
		}
		if (self.nameField.superview != cell.contentView)
			[cell.contentView addSubview:self.nameField];
		return cell;
	}

	if (indexPath.section == 0 && indexPath.row == 2) {
		UITableViewCell *cell = [self plainCellFor:tableView identifier:@"TGFolderColour"
											 style:UITableViewCellStyleDefault];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		[self layoutColourSwatchesInCell:cell width:tableView.bounds.size.width];
		return cell;
	}

	if (indexPath.section == 0) {
		UITableViewCell *cell = [self plainCellFor:tableView identifier:@"TGFolderIcon"
											 style:UITableViewCellStyleValue1];
		cell.textLabel.text = TGL(@"Folders.Icon", @"Icon");
		NSString *icon = self.draft[@"icon"];
		BOOL explicit = [icon isKindOfClass:[NSString class]] && icon.length;
		NSString *shown = explicit ? icon : self.defaultIconName;
		NSString *glyph = [self glyphForIconName:shown];
		if (!shown.length)
			cell.detailTextLabel.text = TGL(@"UserInfo.NotificationsDefault", @"Default");
		else if (glyph)
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  %@", glyph, shown];
		else
			cell.detailTextLabel.text = shown;
		[self markDisclosure:cell];
		return cell;
	}

	if (indexPath.section == 3) {
		if (indexPath.row < (NSInteger)self.inviteLinks.count) {
			UITableViewCell *cell = [self plainCellFor:tableView identifier:@"TGFolderLink"
												 style:UITableViewCellStyleSubtitle];
			NSDictionary *link = self.inviteLinks[indexPath.row];
			NSString *name = link[@"name"];
			NSString *url = link[@"link"];
			cell.textLabel.font = TGGroupedRowTitleFont();
			cell.textLabel.text = ([name isKindOfClass:[NSString class]] && name.length)
					? name : url;
			NSArray *chatIds = link[@"chatIds"];
			NSInteger count = [chatIds isKindOfClass:[NSArray class]]
					? (NSInteger)chatIds.count : 0;
			cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
			cell.detailTextLabel.text = TGLPlural(@"FolderLinkPreview.TextAddChatsCount", count, @"%d chat", @"%d chats");
			[self markDisclosure:cell];
			return cell;
		}
		UITableViewCell *cell = [self plainCellFor:tableView identifier:@"TGFolderAddLink"
											 style:UITableViewCellStyleDefault];
		cell.textLabel.text = TGL(@"ChatListFilter.CreateLinkNew", @"Create an Invite Link");
		cell.textLabel.textColor = [self draftHasExcludeOrFilterSet]
			? [[TGTheme shared] groupedDisabledColour]
			: [[TGTheme shared] groupedActionColour];
		return cell;
	}

	if (indexPath.section == 4) {
		UITableViewCell *cell = [self plainCellFor:tableView identifier:@"TGFolderDelete"
											 style:UITableViewCellStyleDefault];
		[TGIcons actionButtonInCell:cell
							  title:TGL(@"ChatList.AlertDeleteFolderTitle", @"Delete Folder")
							   kind:TGActionButtonKindDestructive
							 target:self
							 action:@selector(confirmDeleteFolder)];
		return cell;
	}

	BOOL included = (indexPath.section == 1);
	NSArray *keys = included ? [self includeKeys] : [self excludeKeys];
	NSArray *titles = included ? [self includeTitles] : [self excludeTitles];
	NSArray *chatIds = self.draft[included ? @"includedChatIds" : @"excludedChatIds"];

	if (indexPath.row < (NSInteger)keys.count) {
		UITableViewCell *cell = [self plainCellFor:tableView identifier:@"TGFolderToggle"
											 style:UITableViewCellStyleDefault];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.textLabel.text = titles[indexPath.row];
		UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
		NSInteger flatIndex = included
				? indexPath.row : [self includeKeys].count + indexPath.row;
		toggle.tag = flatIndex;
		toggle.on = [self.draft[keys[indexPath.row]] boolValue];
		[toggle addTarget:self action:@selector(toggleChanged:)
		 forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
		return cell;
	}

	NSInteger chatIndex = indexPath.row - keys.count;
	if (chatIndex < (NSInteger)chatIds.count) {
		UITableViewCell *cell = [self plainCellFor:tableView identifier:@"TGFolderChat"
											 style:UITableViewCellStyleDefault];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.textLabel.font = TGGroupedRowTitleFont();
		NSString *title = [self titleForChatId:chatIds[chatIndex]];
		cell.textLabel.text = title;
		cell.imageView.image = [self avatarForChatId:[chatIds[chatIndex] longLongValue] title:title];
		return cell;
	}

	UITableViewCell *cell = [self plainCellFor:tableView identifier:@"TGFolderAddChats"
										 style:UITableViewCellStyleDefault];
	cell.textLabel.text = included ? TGL(@"ChatList.AddChatsToFolder", @"Add Chats") : TGL(@"ChatListFolder.ExcludeChatsTitle", @"Exclude Chats");
	cell.textLabel.textColor = [[TGTheme shared] groupedActionColour];
	return cell;
}

- (UITableViewCell *)pickerCellFor:(UITableView *)tableView at:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [self plainCellFor:tableView identifier:@"TGFolderPick"
										 style:UITableViewCellStyleDefault];
	NSDictionary *row = self.pickerChats[indexPath.row];
	NSString *title = row[@"title"];
	if (![title isKindOfClass:[NSString class]] || !title.length)
		title = TGL(@"ChatList.UnnamedChat", @"Chat");
	cell.textLabel.text = title;
	cell.textLabel.font = [UIFont systemFontOfSize:19];
	NSNumber *identifier = row[@"id"];
	cell.imageView.image = [self avatarForChatId:[identifier longLongValue] title:title];
	[self markChecked:[self.pickerSelection containsObject:identifier] on:cell];
	return cell;
}

- (UITableViewCell *)iconCellFor:(UITableView *)tableView at:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [self plainCellFor:tableView identifier:@"TGFolderIconName"
										 style:UITableViewCellStyleDefault];
	if (indexPath.row == 0) {
		cell.textLabel.text = TGL(@"UserInfo.NotificationsDefault", @"Default");
		cell.textLabel.font = TGGroupedRowTitleFont();
		[self markChecked:!(self.currentIcon.length) on:cell];
		return cell;
	}
	NSString *name = self.iconNames[indexPath.row - 1];
	NSString *glyph = [self glyphForIconName:name];
	cell.textLabel.text = glyph ? [NSString stringWithFormat:@"%@  %@", glyph, name] : name;
	cell.textLabel.font = TGGroupedRowTitleFont();
	[self markChecked:[name isEqualToString:self.currentIcon ?: @""] on:cell];
	return cell;
}

#pragma mark - colour swatches

- (void)layoutColourSwatchesInCell:(UITableViewCell *)cell width:(CGFloat)width {
	static const CGFloat kSwatchSide = 26.0f;
	static const CGFloat kSwatchSpacing = 12.0f;
	static const NSInteger kSwatchTagBase = 9100;
	NSInteger count = 8;
	CGFloat totalWidth = count * kSwatchSide + (count - 1) * kSwatchSpacing;
	CGFloat startX = (CGFloat)(int)((width - totalWidth) / 2.0f);
	CGFloat y = (CGFloat)(int)((kRowHeight - kSwatchSide) / 2.0f);
	NSInteger selected = [self draftColourId];

	for (NSInteger i = 0; i < count; i++) {
		NSInteger colourId = i - 1;
		UIButton *swatch = (UIButton *)[cell.contentView viewWithTag:kSwatchTagBase + i];
		if (!swatch) {
			swatch = [UIButton buttonWithType:UIButtonTypeCustom];
			swatch.tag = kSwatchTagBase + i;
			[swatch addTarget:self action:@selector(colourSwatchTapped:)
				forControlEvents:UIControlEventTouchUpInside];
			[cell.contentView addSubview:swatch];
		}
		swatch.frame = CGRectMake(startX + i * (kSwatchSide + kSwatchSpacing), y,
			kSwatchSide, kSwatchSide);
		swatch.layer.cornerRadius = kSwatchSide / 2.0f;
		swatch.layer.masksToBounds = YES;
		swatch.backgroundColor = colourId < 0
				? [UIColor clearColor]
				: TGColourFromHex(kFolderTagColours[colourId]);
		BOOL isSelected = (colourId == selected);
		swatch.layer.borderWidth = isSelected ? 2.5f : (colourId < 0 ? 1.5f : 0.0f);
		swatch.layer.borderColor = isSelected
				? [[TGTheme shared] accentColour].CGColor
				: [[TGTheme shared] cellDetailColour].CGColor;
	}
}

- (void)colourSwatchTapped:(UIButton *)sender {
	NSInteger colourId = sender.tag - 9100 - 1;
	[self selectDraftColourId:colourId];
}

@end
