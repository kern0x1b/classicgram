#import "TGMediaViewControllerInternal.h"
#import "TGClient+Files.h"
#import "TGMusicPlayer.h"
#import "TGWebViewController.h"
#import "TGLocalization.h"
#import "TGLazyFramework.h"
#import "TGFileDetailsViewController.h"

#import <MediaPlayer/MediaPlayer.h>

@implementation TGMediaViewController (Actions)

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (TGMediaScopeIsGrid(self.scope) || indexPath.row >= (NSInteger)self.items.count)
		return;

	NSDictionary *item = self.items[indexPath.row];

	if (self.scope == TGMediaScopeLinks) {
		NSString *url = item[@"url"];
		if (![url isKindOfClass:NSString.class] || url.length == 0)
			return;
		NSURL *target = [NSURL URLWithString:url];
		if (!target.scheme.length) {
			url = [@"http://" stringByAppendingString:url];
			target = [NSURL URLWithString:url];
		}
		if (target)
			[TGWebViewController openURLString:url fromViewController:self];
		return;
	}

	long long fileId = [item[@"fileId"] longLongValue];
	if (fileId <= 0)
		return;

	if (self.scope == TGMediaScopeVoice && ![item[@"isVideoNote"] boolValue]) {
		BOOL outgoing = [item[@"outgoing"] boolValue];
		NSString *sender = outgoing ? @"" : ([item[@"senderName"] isKindOfClass:NSString.class] ? item[@"senderName"] : @"");
		[[TGMusicPlayer shared] playVoiceMessageId:[item[@"messageId"] longLongValue]
											chatId:[item[@"chatId"] longLongValue]
											fileId:fileId
										  duration:[item[@"duration"] integerValue]
											sender:sender
											  date:[item[@"date"] longLongValue]];
		return;
	}

	if ([self.pendingDownloadFileIds containsObject:@(fileId)])
		return;
	[self.pendingDownloadFileIds addObject:@(fileId)];

	[self.spinner startAnimating];
	[[TGClient shared] startDownloadingFile:fileId priority:32 completion:nil];

	BOOL isMusic = (self.scope == TGMediaScopeMusic) ||
		(self.scope == TGMediaScopeVoice && [item[@"isVideoNote"] boolValue]);
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:fileId completion:^(NSString *path) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf.pendingDownloadFileIds removeObject:@(fileId)];
		if (!strongSelf.isViewLoaded)
			return;
		if (strongSelf.pendingDownloadFileIds.count == 0)
			[strongSelf.spinner stopAnimating];
		if (path.length == 0) {
			[strongSelf showAlertMessage:TGL(@"Media.CouldNotStartDownload", @"Could not start the download.")];
			return;
		}
		if (isMusic) {
			MPMoviePlayerViewController *player = [[TGMPClass(MPMoviePlayerViewController) alloc]
				initWithContentURL:[NSURL fileURLWithPath:path]];
			[strongSelf presentMoviePlayerViewControllerAnimated:player];
			return;
		}
		[strongSelf previewFileAtPath:path];
	}];
}

- (void)loadExtensionForMime:(NSString *)mime {
	if (mime.length == 0 || self.extensionCache[mime])
		return;
	self.extensionCache[mime] = @"";

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] fileExtensionForMimeType:mime completion:^(NSString *extension) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || !strongSelf.isViewLoaded)
			return;
		if (extension.length == 0)
			return;
		strongSelf.extensionCache[mime] = extension;
		if (strongSelf.scope == TGMediaScopeFiles)
			[strongSelf.tableView reloadData];
	}];
}

- (void)handleRowLongPress:(UILongPressGestureRecognizer *)recognizer {
	if (recognizer.state != UIGestureRecognizerStateBegan)
		return;
	if (TGMediaScopeIsGrid(self.scope) || self.scope == TGMediaScopeLinks)
		return;

	CGPoint point = [recognizer locationInView:self.tableView];
	NSIndexPath *path = [self.tableView indexPathForRowAtPoint:point];
	if (!path || path.row >= (NSInteger)self.items.count)
		return;

	NSDictionary *item = self.items[path.row];
	long long fileId = [item[@"fileId"] longLongValue];
	if (fileId <= 0)
		return;

	TGFileDetailsViewController *details = [[TGFileDetailsViewController alloc] init];
	details.fileId = fileId;
	details.fileName = item[@"title"];
	details.mimeType = item[@"mime"];
	details.fileType = item[@"fileType"];
	details.chatId = self.chatId;
	details.messageId = [item[@"messageId"] longLongValue];
	if (self.navigationController)
		[self.navigationController pushViewController:details animated:YES];
}

- (void)showAlertMessage:(NSString *)message {
	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:@""
						 message:message
						delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

- (void)previewFileAtPath:(NSString *)path {
	self.documentController = [UIDocumentInteractionController
		interactionControllerWithURL:[NSURL fileURLWithPath:path]];
	self.documentController.delegate = self;
	if ([self.documentController presentPreviewAnimated:YES])
		return;
	[self.documentController presentOpenInMenuFromRect:self.view.bounds
												inView:self.view
											  animated:YES];
}

- (UIViewController *)documentInteractionControllerViewControllerForPreview:
	(UIDocumentInteractionController *)controller {
	return self;
}

@end
