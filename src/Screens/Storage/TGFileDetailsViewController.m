#import "TGListBackground.h"
#import "TGFileDetailsViewController.h"
#import "TGActionSheet.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGByteFormat.h"
#import "TGProgressIndicatorView.h"
#import "TGFileDownloadService.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGChatViewController.h"

static const long long TGMediaExportChunk = 256 * 1024;
static const long long TGMediaExportLimit = 12 * 1024 * 1024;

@implementation TGFileDetailsViewController

- (id)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_infoRows = [[NSMutableArray alloc] init];
		_prefixSize = -1;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	self.title = self.fileName.length ? self.fileName : TGL(@"Attachment.File", @"File");
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	[self reloadFile];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)setBusy:(BOOL)busy {
	_busy = busy;
	if (busy) {
		UIActivityIndicatorView *spinner = [[TGProgressIndicatorView alloc]
			initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		[spinner startAnimating];
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithCustomView:spinner];
	} else {
		self.navigationItem.rightBarButtonItem = nil;
	}
	self.tableView.userInteractionEnabled = !busy;
}

- (void)showAlert:(NSString *)message {
	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:@""
						 message:message
						delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

- (void)reloadFile {
	if (self.fileId <= 0) {
		[self rebuildInfoRows];
		return;
	}

	self.busy = YES;
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService fileInfo:self.fileId completion:^(NSDictionary *file) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || !strongSelf.isViewLoaded)
			return;
		strongSelf.busy = NO;
		if (!file) {
			[strongSelf rebuildInfoRows];
			[strongSelf showAlert:TGL(@"Media.FileNoLongerAvailable",
							  @"This file is no longer available on this device.")];
			return;
		}
		strongSelf.file = file;
		[strongSelf rebuildInfoRows];
		[strongSelf loadPrefixSize];
		[strongSelf loadExtension];
	}];
}

- (void)loadPrefixSize {
	if (self.fileId <= 0)
		return;
	__weak typeof(self) weakSelf = self;
	void (^apply)(long long) = ^(long long size) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || !strongSelf.isViewLoaded)
			return;
		strongSelf.prefixSize = size;
		[strongSelf rebuildInfoRows];
	};
	[TGFileDownloadService downloadedPrefixSizeForFile:self.fileId offset:0 completion:apply];
}

- (void)loadExtension {
	if (self.mimeType.length == 0)
		return;
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService fileExtensionForMimeType:self.mimeType
										 completion:^(NSString *extension) {
											 typeof(self) strongSelf = weakSelf;
											 if (!strongSelf || !strongSelf.isViewLoaded || extension.length == 0)
												 return;
											 strongSelf.extension = extension;
											 [strongSelf rebuildInfoRows];
										 }];
}

- (void)addInfoRow:(NSString *)title value:(NSString *)value {
	if (value.length == 0)
		return;
	[self.infoRows addObject:@{@"title" : title, @"value" : value}];
}

- (void)rebuildInfoRows {
	[self.infoRows removeAllObjects];

	NSDictionary *file = self.file;
	long long total = [file[@"size"] longLongValue];
	if (total <= 0)
		total = [file[@"expectedSize"] longLongValue];
	long long got = [file[@"downloadedSize"] longLongValue];

	NSString *status = TGL(@"Media.NotDownloaded", @"Not downloaded");
	if ([file[@"isDownloaded"] boolValue])
		status = TGL(@"Storage.Downloaded", @"Downloaded");
	else if ([file[@"isDownloading"] boolValue])
		status = TGL(@"DownloadList.DownloadingHeader", @"Downloading");
	else if (got > 0)
		status = TGL(@"Media.PartlyDownloaded", @"Partly downloaded");

	[self addInfoRow:TGL(@"Media.FileStatus", @"Status")
			   value:file ? status : TGL(@"Media.FileStatusUnknown", @"Unknown")];
	if (self.extension.length)
		[self addInfoRow:TGL(@"Media.FileKind", @"Kind") value:[self.extension uppercaseString]];
	else if (self.mimeType.length)
		[self addInfoRow:TGL(@"Media.FileKind", @"Kind") value:self.mimeType];
	if (total > 0)
		[self addInfoRow:TGL(@"Media.FileSize", @"Size") value:TGMediaFormatBytes(total)];
	if (got > 0)
		[self addInfoRow:TGL(@"Media.OnThisDevice", @"On this device")
				   value:TGMediaFormatBytes(got)];
	if (self.prefixSize >= 0)
		[self addInfoRow:TGL(@"Media.PlayableFromStart", @"Playable from start")
				   value:TGMediaFormatBytes(self.prefixSize)];

	[self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (BOOL)canShowInChat {
	return self.chatId != 0 && self.messageId != 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return (NSInteger)self.infoRows.count;
	return [self canShowInChat] ? 4 : 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return section == 0 ? TGL(@"Attachment.File", @"File") : nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *infoIdentifier = @"TGFileInfo";
	static NSString *actionIdentifier = @"TGFileAction";

	if (indexPath.section == 0) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:infoIdentifier];
		if (!cell) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
										  reuseIdentifier:infoIdentifier];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
		[[TGTheme shared] styleCell:cell];
		NSDictionary *row = self.infoRows[indexPath.row];
		cell.textLabel.text = row[@"title"];
		cell.detailTextLabel.text = row[@"value"];
		cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		return cell;
	}

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:actionIdentifier];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:actionIdentifier];
	}
	[[TGTheme shared] styleCell:cell];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();

	if (indexPath.row == 0) {
		cell.textLabel.text = TGL(@"Media.OpenACopy", @"Open a Copy");
	} else if (indexPath.row == 1) {
		cell.textLabel.text = TGL(@"Media.DownloadPriority", @"Download Priority");
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	} else if (indexPath.row == 2) {
		cell.textLabel.text = TGL(@"Media.FetchAgain", @"Fetch Again");
	} else {
		cell.textLabel.text = TGL(@"MediaPlayer.ContextMenu.ShowInChat", @"Show in Chat");
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section != 1)
		return;

	if (indexPath.row == 3) {
		[self showInChat];
		return;
	}
	if (self.fileId <= 0)
		return;

	if (indexPath.row == 0) {
		[self exportCopy];
	} else if (indexPath.row == 1) {
		[self askPriority];
	} else {
		[self fetchAgain];
	}
}

#pragma mark - show in chat

- (void)showInChat {
	if (![self canShowInChat] || !self.navigationController)
		return;

	for (UIViewController *existing in self.navigationController.viewControllers) {
		if (![existing isKindOfClass:[TGChatViewController class]])
			continue;
		TGChatViewController *chat = (TGChatViewController *)existing;
		if (chat.chatId != self.chatId)
			continue;
		[self.navigationController popToViewController:existing animated:YES];
		[chat scrollToMessageId:self.messageId];
		return;
	}

	TGChatViewController *controller = [[TGChatViewController alloc] init];
	controller.chatId = self.chatId;
	controller.focusMessageId = self.messageId;
	[self.navigationController pushViewController:controller animated:YES];
}

#pragma mark - priority

- (void)askPriority {
	self.sheetActions = @[ @(32), @(16), @(1) ];
	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"Media.DownloadPriority", @"Download Priority")
					  delegate:self
				   otherTitles:@[ TGL(@"AutoDownloadSettings.DataUsageHigh", @"High"), TGL(@"AutoDownloadSettings.DataUsageMedium", @"Medium"), TGL(@"AutoDownloadSettings.DataUsageLow", @"Low") ]
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.sheetActions.count)
		return;

	NSInteger priority = [self.sheetActions[index] integerValue];
	self.busy = YES;
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService startDownloadingFile:self.fileId
									   priority:priority
									 completion:^(NSDictionary *file) {
										 typeof(self) strongSelf = weakSelf;
										 if (!strongSelf || !strongSelf.isViewLoaded)
											 return;
										 strongSelf.busy = NO;
										 if (!file) {
											 [strongSelf showAlert:TGL(@"Media.CouldNotChangePriority",
																@"Could not change the priority.")];
											 return;
										 }
										 strongSelf.file = file;
										 [strongSelf rebuildInfoRows];
									 }];
}

#pragma mark - fetch again

- (void)fetchAgain {
	self.busy = YES;
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService fileInfo:self.fileId completion:^(NSDictionary *file) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || !strongSelf.isViewLoaded)
			return;

		if (file && [file[@"canBeDownloaded"] boolValue]) {
			strongSelf.file = file;
			[strongSelf startDownloadOfFile:strongSelf.fileId];
			return;
		}

		NSString *remoteId = file[@"remoteId"];
		NSString *type = strongSelf.fileType.length ? strongSelf.fileType : [TGFileDownloadService fileTypeDocument];
		if (![remoteId isKindOfClass:NSString.class] || remoteId.length == 0) {
			strongSelf.busy = NO;
			[strongSelf showAlert:TGL(@"Media.FileCannotBeDownloadedAgain",
							  @"This file cannot be downloaded again.")];
			return;
		}

		[TGFileDownloadService resolveRemoteFileId:remoteId type:type
										completion:^(NSDictionary *resolved) {
											typeof(self) innerSelf = weakSelf;
											if (!innerSelf || !innerSelf.isViewLoaded)
												return;
											if (!resolved) {
												innerSelf.busy = NO;
												[innerSelf showAlert:TGL(@"Media.FileCannotBeDownloadedAgain",
																	 @"This file cannot be downloaded again.")];
												return;
											}
											innerSelf.file = resolved;
											innerSelf.fileId = [resolved[@"id"] longLongValue];
											[innerSelf startDownloadOfFile:innerSelf.fileId];
										}];
	}];
}

- (void)startDownloadOfFile:(long long)fileId {
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService startDownloadingFile:fileId priority:16 completion:^(NSDictionary *file) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || !strongSelf.isViewLoaded)
			return;
		strongSelf.busy = NO;
		if (!file) {
			[strongSelf showAlert:TGL(@"Media.CouldNotStartDownload", @"Could not start the download.")];
			return;
		}
		strongSelf.file = file;
		[strongSelf rebuildInfoRows];
		[strongSelf loadPrefixSize];
	}];
}

#pragma mark - export a copy

- (void)exportCopy {
	long long total = [self.file[@"size"] longLongValue];
	if (total <= 0)
		total = [self.file[@"expectedSize"] longLongValue];
	if (total <= 0) {
		[self showAlert:TGL(@"Media.FileSizeNotKnownYet",
							@"The size of this file is not known yet.")];
		return;
	}
	if (total > TGMediaExportLimit) {
		[self showAlert:TGL(@"Media.FileTooLargeToOpen",
							@"This file is too large to open here. Play or save it instead.")];
		return;
	}

	NSString *name = self.fileName.length ? [self.fileName lastPathComponent] : @"file";
	if (self.extension.length && [[name pathExtension] length] == 0)
		name = [name stringByAppendingPathExtension:self.extension];

	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
	[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
	if (![[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil]) {
		[self showAlert:TGL(@"Media.CouldNotOpenACopy", @"Could not open a copy.")];
		return;
	}

	self.exportPath = path;
	self.exportHandle = [NSFileHandle fileHandleForWritingAtPath:path];
	self.exportOffset = 0;
	self.exportTotal = total;
	if (!self.exportHandle) {
		[self showAlert:TGL(@"Media.CouldNotOpenACopy", @"Could not open a copy.")];
		return;
	}

	self.busy = YES;
	[self pullNextChunk];
}

- (void)finishExportWithError:(NSString *)message {
	[self.exportHandle closeFile];
	self.exportHandle = nil;
	self.busy = NO;

	if (message.length) {
		[[NSFileManager defaultManager] removeItemAtPath:self.exportPath error:NULL];
		self.exportPath = nil;
		[self showAlert:message];
		return;
	}

	self.documentController = [UIDocumentInteractionController
		interactionControllerWithURL:[NSURL fileURLWithPath:self.exportPath]];
	self.documentController.delegate = self;
	if ([self.documentController presentPreviewAnimated:YES])
		return;
	if (![self.documentController presentOpenInMenuFromRect:self.view.bounds inView:self.view animated:YES])
		[self showAlert:TGL(@"Media.NothingCanOpenThatFile",
							@"Nothing on this device can open that file.")];
}

- (void)pullNextChunk {
	long long remaining = self.exportTotal - self.exportOffset;
	if (remaining <= 0) {
		[self finishExportWithError:nil];
		return;
	}

	long long count = remaining < TGMediaExportChunk ? remaining : TGMediaExportChunk;
	long long offset = self.exportOffset;
	BOOL onDisk = [self.file[@"isDownloaded"] boolValue];

	__weak typeof(self) weakSelf = self;
	void (^handleData)(NSData *) = ^(NSData *data) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || !strongSelf.isViewLoaded)
			return;
		if (data.length == 0) {
			[strongSelf finishExportWithError:TGL(@"Media.CouldNotReadTheWholeFile",
										  @"Could not read the whole file.")];
			return;
		}
		@try {
			[strongSelf.exportHandle writeData:data];
		} @catch (NSException *exception) {
			[strongSelf finishExportWithError:TGL(@"Media.CouldNotWriteTheCopy",
										  @"Could not write the copy.")];
			return;
		}
		strongSelf.exportOffset += (long long)data.length;
		[strongSelf pullNextChunk];
	};

	if (onDisk)
		[TGFileDownloadService readFile:self.fileId offset:offset count:count
							 completion:handleData];
	else
		[TGFileDownloadService streamFile:self.fileId offset:offset count:count
							   completion:handleData];
}

- (UIViewController *)documentInteractionControllerViewControllerForPreview:
	(UIDocumentInteractionController *)controller {
	return self;
}

- (void)documentInteractionControllerDidEndPreview:(UIDocumentInteractionController *)controller {
	if (self.exportPath.length) {
		[[NSFileManager defaultManager] removeItemAtPath:self.exportPath error:NULL];
		self.exportPath = nil;
	}
}

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller {
	if (self.exportPath.length) {
		[[NSFileManager defaultManager] removeItemAtPath:self.exportPath error:NULL];
		self.exportPath = nil;
	}
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
	return orientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (void)dealloc {
	[_exportHandle closeFile];
	if (_exportPath.length)
		[[NSFileManager defaultManager] removeItemAtPath:_exportPath error:NULL];
}

@end
