#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGMessageRowCell.h"
#import "TGBubbleCellBase.h"
#import "TGQuoteBadgeView.h"
#import "TGPhotoBubbleCell.h"
#import "TGServiceRowCell.h"
#import "TGStickerBubbleCell.h"
#import "TGFileBubbleCell.h"
#import "TGVideoNoteBubbleCell.h"
#import "TGVoiceBubbleCell.h"
#import "TGAlbumBubbleCell.h"
#import "TGMapBubbleCell.h"
#import "TGAudioMetadata.h"
#import "TGLinkPreviewView.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGMusicPlayer.h"
#import "TGLocalization.h"

static UIColor *TGBitmapDiscColour(void) {
	return [UIColor colorWithWhite:0 alpha:0.45f];
}

@implementation TGChatViewController (LayoutBitmaps)

- (void)tg_configureBaseBitmapsForCell:(TGBubbleCellBase *)cell message:(NSDictionary *)m {
	if (!cell.senderAvatar.hidden) {
		NSString *forwardName = m[@"forward"];
		NSString *avatarName = forwardName.length ? forwardName : cell.sender.text;
		cell.senderAvatar.image = cell.avatarChatId != 0
			? [self avatarForChat:cell.avatarChatId name:avatarName]
			: [self avatarForUser:cell.avatarUserId name:avatarName];
	}

	[self tg_configureLinkPreviewBitmapsForCell:cell message:m];
	[self tg_configureQuoteBitmapForCell:cell message:m];
}

- (void)tg_configureLinkPreviewBitmapsForCell:(TGBubbleCellBase *)cell message:(NSDictionary *)m {
	NSDictionary *preview = [self previewFor:m];
	BOOL isRichMessage = [m[@"kind"] isEqualToString:@"messageRichMessage"];
	if (!preview)
		return;
	if (!isRichMessage && ![preview[@"url"] length])
		return;

	BOOL mine = [m[@"outgoing"] boolValue];
	__weak typeof(self) weakSelf = self;
	cell.linkPreview.buttonTitleOverride = isRichMessage
		? TGL(@"Conversation.ReadMore", @"READ MORE")
		: nil;
	[cell.linkPreview configureWithPreview:preview
									 image:[self previewImageFor:preview]
								  outgoing:mine
								  maxWidth:cell.linkPreview.frame.size.width];
	if (isRichMessage) {
		NSDictionary *capturedMessage = m;
		void (^openReader)(NSString *) = ^(NSString *unusedUrl) {
			(void)unusedUrl;
			[weakSelf openRichMessage:capturedMessage];
		};
		cell.linkPreview.onOpen = openReader;
		cell.linkPreview.onInstantView = openReader;
		cell.linkPreview.onOpenMedia = nil;
	} else {
		NSDictionary *capturedPreview = preview;
		cell.linkPreview.onOpen = ^(NSString *url) { [weakSelf openLink:url]; };
		cell.linkPreview.onInstantView = ^(NSString *url) { [weakSelf openInstantView:url]; };
		cell.linkPreview.onOpenMedia = [capturedPreview[@"photoFileId"] isKindOfClass:NSNumber.class]
			? ^(NSString *unusedUrl) {
				(void)unusedUrl;
				[weakSelf showGalleryForLinkPreview:capturedPreview];
			}
			: nil;
	}
}

- (void)tg_configureQuoteBitmapForCell:(TGBubbleCellBase *)cell message:(NSDictionary *)m {
	TGQuoteBadgeView *badge = cell.quoteBadge;
	if (badge.hidden || badge.thumbnail.hidden)
		return;

	UIImage *thumb = [self quoteThumbnailFor:m];
	if (!thumb) {
		badge.thumbnail.image = nil;
		return;
	}

	BOOL round = [self quoteIsVideoNoteFor:m];
	badge.thumbnail.image = thumb;
	badge.thumbnail.layer.cornerRadius = round ? 16 : 3;
	badge.thumbnail.contentMode = round
		? UIViewContentModeScaleAspectFit
		: UIViewContentModeScaleAspectFill;
}

- (void)tg_configurePhotoBitmapsForCell:(TGPhotoBubbleCell *)cell message:(NSDictionary *)m {
	if (!cell.picture.hidden)
		[self applyPictureTo:cell.picture message:m atSize:cell.picture.bounds.size];

	if (!cell.disc.hidden)
		cell.disc.image = [self retryGlyphOfSide:cell.disc.bounds.size.width];

	if (!cell.fileStatus.hidden) {
		NSDictionary *state = [self fileStateFor:m];
		cell.fileStatus.discColour = TGBitmapDiscColour();
		cell.fileStatus.glyphColour = [UIColor whiteColor];
		cell.fileStatus.extensionText = nil;
		[cell.fileStatus setKind:[self mediaStatusKindFor:m state:state]
						progress:[state[@"progress"] floatValue]];
	}
}

- (void)tg_configureMapBitmapsForCell:(TGMapBubbleCell *)cell message:(NSDictionary *)m {
	if (!cell.picture.hidden)
		[self applyPictureTo:cell.picture message:m atSize:cell.picture.bounds.size];
}

- (void)tg_configureStickerBitmapsForCell:(TGStickerBubbleCell *)cell message:(NSDictionary *)m {
	if (!cell.picture.hidden)
		[self applyPictureTo:cell.picture message:m atSize:cell.picture.bounds.size];
}

- (void)tg_configureServiceBitmapsForCell:(TGServiceRowCell *)cell message:(NSDictionary *)m {
	if (!cell.picture.hidden)
		[self applyPictureTo:cell.picture message:m atSize:cell.picture.bounds.size];
}

- (void)tg_configureFileBitmapsForCell:(TGFileBubbleCell *)cell message:(NSDictionary *)m {
	TGTheme *theme = [TGTheme shared];
	NSString *kind = m[@"kind"];
	BOOL isContact = [kind isEqualToString:@"messageContact"];
	BOOL isAudio = [kind isEqualToString:@"messageAudio"];
	BOOL mine = [m[@"outgoing"] boolValue];
	BOOL hasThumb = [self fileCellShowsThumbnailFor:m];

	UIImage *cover = isAudio
		? [TGAudioMetadata artworkTileOfSide:cell.picture.bounds.size.width
								cornerRadius:4
									   scrim:NO
								 forMetadata:[self audioTagsFor:m]]
		: nil;
	BOOL hasCover = (cover != nil);

	if (!cell.picture.hidden) {
		if (isContact) {
			int64_t contactId = [m[@"contactUserId"] longLongValue];
			NSString *name = [self contactNameFor:m];
			UIImage *avatar = [self avatarForUser:contactId name:name];
			cell.picture.image = avatar;
			cell.picture.backgroundColor = avatar ? [UIColor clearColor] : [theme mediaCircleColour];
			cell.picture.layer.cornerRadius = cell.picture.bounds.size.width / 2;
		} else if (isAudio) {
			cell.picture.layer.cornerRadius = 4.0f;
			if (hasCover) {
				cell.picture.image = cover;
				cell.picture.backgroundColor = [UIColor clearColor];
			}
		} else {
			cell.picture.layer.cornerRadius = 4.0f;
			[self applyPictureTo:cell.picture message:m atSize:cell.picture.bounds.size];
		}
	}

	if (!cell.fileStatus.hidden) {
		NSDictionary *state = [self fileStateFor:m];
		BOOL playing = isAudio &&
			[m[@"id"] longLongValue] == [self playingMessageId] &&
			[TGMusicPlayer shared].playing;
		TGFileStatusKind statusKind = [self statusKindForFileState:state playable:isAudio playing:playing];
		if (hasCover) {
			cell.fileStatus.discColour = [UIColor colorWithWhite:0 alpha:0.42f];
			cell.fileStatus.glyphColour = [UIColor whiteColor];
		} else if (hasThumb) {
			cell.fileStatus.discColour = TGBitmapDiscColour();
			cell.fileStatus.glyphColour = [UIColor whiteColor];
		} else if (mine) {
			cell.fileStatus.discColour = [UIColor whiteColor];
			cell.fileStatus.glyphColour = [theme bubbleMineColour];
		} else {
			cell.fileStatus.discColour = [theme accentColour];
			cell.fileStatus.glyphColour = [UIColor whiteColor];
		}
		cell.fileStatus.extensionText = (hasThumb || statusKind != TGFileStatusKindFile)
			? nil
			: m[@"docExtension"];
		[cell.fileStatus setKind:statusKind progress:[state[@"progress"] floatValue]];
	}

	if (!cell.audioTime.hidden) {
		BOOL current = [m[@"id"] longLongValue] == [self playingMessageId];
		cell.audioTime.textColor = [theme fileMetaColour];
		cell.audioTime.text = [self audioClockTextFor:m current:current];

		cell.audioProgress.hidden = !current;
		if (current) {
			CGSize lineSize = cell.audioProgress.bounds.size;
			CGFloat played = [self playedFraction];
			cell.audioProgress.image = [TGIcons progressLineOfSize:lineSize played:played colour:[theme accentColour]];
		}
	}
}

- (void)tg_configureVideoNoteBitmapsForCell:(TGVideoNoteBubbleCell *)cell message:(NSDictionary *)m {
	[self applyPictureTo:cell.picture message:m atSize:cell.picture.bounds.size];
}

- (void)tg_configureVoiceBitmapsForCell:(TGVoiceBubbleCell *)cell message:(NSDictionary *)m {
	int64_t messageId = [m[@"id"] longLongValue];
	BOOL playing = messageId != 0 && messageId == [self playingMessageId];
	NSDictionary *state = [self fileStateFor:m];
	BOOL local = [state[@"local"] boolValue];
	BOOL active = [state[@"active"] boolValue];

	if (!cell.disc.hidden) {
		TGFileStatusKind kind = playing
			? TGFileStatusKindPause
			: ((active && !local) ? TGFileStatusKindProgress
				: (local ? TGFileStatusKindPlay : TGFileStatusKindDownload));
		cell.disc.discColour = [[TGTheme shared] mediaCircleColour];
		cell.disc.glyphColour = [UIColor whiteColor];
		cell.disc.extensionText = nil;
		[cell.disc setKind:kind progress:[state[@"progress"] floatValue]];
	}

	if (!cell.wave.hidden) {
		NSData *waveform = [m[@"waveform"] isKindOfClass:NSData.class] ? m[@"waveform"] : nil;
		cell.waveformData = waveform;
		CGFloat played = playing ? [self playedFraction] : 0;
		cell.wave.image = [TGIcons waveform:waveform
									   size:cell.wave.bounds.size
									 played:played
									 colour:[[TGTheme shared] mediaCircleColour]];
	}

	if (playing) {
		NSDictionary *track = [TGMusicPlayer shared].currentTrack;
		[cell updateVoicePlaybackText:[self audioLiveClockTextWithDuration:
											  [track[TGMusicTrackDuration] integerValue]]];
	}
}

- (void)tg_configureAlbumBitmapsForCell:(TGAlbumBubbleCell *)cell atRow:(NSInteger)row {
	NSArray *album = [self albumAtRow:row];
	NSInteger count = MIN(cell.tileCount, album.count);
	for (NSInteger i = 0; i < count; i++) {
		UIImageView *tile = [cell tileAtIndex:i];
		if (!tile.hidden)
			[self applyPictureTo:tile message:album[i] atSize:tile.bounds.size];
	}
}

- (void)configureBitmapsForCell:(TGMessageRowCell *)cell atRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	if (!m)
		return;

	if ([cell isKindOfClass:[TGBubbleCellBase class]])
		[self tg_configureBaseBitmapsForCell:(TGBubbleCellBase *)cell message:m];

	if ([cell isKindOfClass:[TGPhotoBubbleCell class]])
		[self tg_configurePhotoBitmapsForCell:(TGPhotoBubbleCell *)cell message:m];
	else if ([cell isKindOfClass:[TGMapBubbleCell class]])
		[self tg_configureMapBitmapsForCell:(TGMapBubbleCell *)cell message:m];
	else if ([cell isKindOfClass:[TGServiceRowCell class]])
		[self tg_configureServiceBitmapsForCell:(TGServiceRowCell *)cell message:m];
	else if ([cell isKindOfClass:[TGStickerBubbleCell class]])
		[self tg_configureStickerBitmapsForCell:(TGStickerBubbleCell *)cell message:m];
	else if ([cell isKindOfClass:[TGFileBubbleCell class]])
		[self tg_configureFileBitmapsForCell:(TGFileBubbleCell *)cell message:m];
	else if ([cell isKindOfClass:[TGVideoNoteBubbleCell class]])
		[self tg_configureVideoNoteBitmapsForCell:(TGVideoNoteBubbleCell *)cell message:m];
	else if ([cell isKindOfClass:[TGVoiceBubbleCell class]])
		[self tg_configureVoiceBitmapsForCell:(TGVoiceBubbleCell *)cell message:m];
	else if ([cell isKindOfClass:[TGAlbumBubbleCell class]])
		[self tg_configureAlbumBitmapsForCell:(TGAlbumBubbleCell *)cell atRow:row];
}

@end
