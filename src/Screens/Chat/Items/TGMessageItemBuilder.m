#import "TGMessageItemBuilder.h"
#import "TGLocalization.h"
#import "TGMessageItem.h"
#import "TGMessageItemResolvedInputs.h"
#import "TGBubbleCellCatalogue.h"
#import "TGMessage.h"
#import "TGTextContent.h"
#import "TGPhotoContent.h"
#import "TGVideoContent.h"
#import "TGAnimationContent.h"
#import "TGDocumentContent.h"
#import "TGAudioContent.h"
#import "TGContactContent.h"
#import "TGVoiceNoteContent.h"
#import "TGVideoNoteContent.h"
#import "TGServiceContent.h"
#import "TGCallContent.h"
#import "TGRichMessageContent.h"
#import "TGPollContent.h"
#import "TGPollOption.h"
#import "TGChecklistContent.h"
#import "TGChecklistTask.h"
#import "TGLocationContent.h"
#import "TGVenueContent.h"
#import "TGLiveLocationContent.h"

static NSInteger TGFlatInteger(NSDictionary *flat, NSString *key) {
	id value = flat[key];
	return [value isKindOfClass:NSNumber.class] ? [value integerValue] : 0;
}

static long long TGFlatLongLong(NSDictionary *flat, NSString *key) {
	id value = flat[key];
	return [value isKindOfClass:NSNumber.class] ? [value longLongValue] : 0;
}

static double TGFlatDouble(NSDictionary *flat, NSString *key) {
	id value = flat[key];
	return [value isKindOfClass:NSNumber.class] ? [value doubleValue] : 0;
}

static TGMessageContentKind TGMessageItemBuilderKind(NSDictionary *flat, BOOL isService) {
	if (isService)
		return TGMessageContentKindService;
	NSString *restrictionReason = flat[@"restrictionReason"];
	if ([restrictionReason isKindOfClass:NSString.class] && restrictionReason.length)
		return TGMessageContentKindText;
	NSString *kind = flat[@"kind"];
	if ([kind isEqualToString:@"messageText"])
		return TGMessageContentKindText;
	if ([kind isEqualToString:@"messagePhoto"])
		return TGMessageContentKindPhoto;
	if ([kind isEqualToString:@"messageVideo"])
		return TGMessageContentKindVideo;
	if ([kind isEqualToString:@"messageAnimation"])
		return TGMessageContentKindAnimation;
	if ([kind isEqualToString:@"messageDocument"])
		return TGMessageContentKindDocument;
	if ([kind isEqualToString:@"messageAudio"])
		return TGMessageContentKindAudio;
	if ([kind isEqualToString:@"messageContact"])
		return TGMessageContentKindContact;
	if ([kind isEqualToString:@"messageVoiceNote"])
		return TGMessageContentKindVoiceNote;
	if ([kind isEqualToString:@"messageVideoNote"])
		return TGMessageContentKindVideoNote;
	if ([kind isEqualToString:@"messageCall"] || [kind isEqualToString:@"messageGroupCall"])
		return TGMessageContentKindCall;
	if ([kind isEqualToString:@"messageRichMessage"])
		return TGMessageContentKindRichMessage;
	if ([kind isEqualToString:@"messagePoll"])
		return TGMessageContentKindPoll;
	if ([kind isEqualToString:@"messageChecklist"])
		return TGMessageContentKindChecklist;
	if ([kind isEqualToString:@"messageLocation"])
		return TGMessageContentKindLocation;
	if ([kind isEqualToString:@"messageVenue"])
		return TGMessageContentKindVenue;
	if ([kind isEqualToString:@"messageLiveLocation"])
		return TGMessageContentKindLiveLocation;
	if ([kind isEqualToString:@"messageExpiredPhoto"] ||
		[kind isEqualToString:@"messageExpiredVideo"] ||
		[kind isEqualToString:@"messageExpiredVoiceNote"] ||
		[kind isEqualToString:@"messageExpiredVideoNote"])
		return TGMessageContentKindExpiredMedia;
	return TGMessageContentKindUnsupported;
}

static TGMessageContent *TGMessageItemBuilderContent(NSDictionary *flat, TGMessageContentKind kind) {
	switch (kind) {
		case TGMessageContentKindText:
			return [TGTextContent new];
		case TGMessageContentKindPhoto: {
			NSNumber *fileId = [flat[@"photoId"] isKindOfClass:NSNumber.class] ? flat[@"photoId"] : nil;
			TGPhotoContent *photoContent = [TGPhotoContent alloc];
			return [photoContent initWithFileId:fileId ? fileId.longLongValue : 0
										  width:TGFlatInteger(flat, @"photoWidth")
										 height:TGFlatInteger(flat, @"photoHeight")
										  sizes:@[]
								  minithumbnail:nil];
		}
		case TGMessageContentKindVideo: {
			NSNumber *fileId = [flat[@"docId"] isKindOfClass:NSNumber.class] ? flat[@"docId"] : nil;
			NSNumber *thumbId = [flat[@"photoId"] isKindOfClass:NSNumber.class] ? flat[@"photoId"] : nil;
			TGVideoContent *videoContent = [TGVideoContent alloc];
			return [videoContent initWithFileId:fileId ? fileId.longLongValue : 0
								thumbnailFileId:thumbId ? thumbId.longLongValue : 0
									   fileName:flat[@"docName"] ?: @""
									   mimeType:flat[@"docMime"] ?: @""
										  width:TGFlatInteger(flat, @"photoWidth")
										 height:TGFlatInteger(flat, @"photoHeight")
									   duration:[flat[@"duration"] integerValue]
								  minithumbnail:nil
							  supportsStreaming:[flat[@"supportsStreaming"] boolValue]];
		}
		case TGMessageContentKindAnimation: {
			NSNumber *fileId = [flat[@"docId"] isKindOfClass:NSNumber.class] ? flat[@"docId"] : nil;
			NSNumber *thumbId = [flat[@"photoId"] isKindOfClass:NSNumber.class] ? flat[@"photoId"] : nil;
			TGAnimationContent *animationContent = [TGAnimationContent alloc];
			return [animationContent initWithFileId:fileId ? fileId.longLongValue : 0
									thumbnailFileId:thumbId ? thumbId.longLongValue : 0
										   fileName:flat[@"docName"] ?: @""
										   mimeType:flat[@"docMime"] ?: @""
											  width:TGFlatInteger(flat, @"photoWidth")
											 height:TGFlatInteger(flat, @"photoHeight")
										   duration:[flat[@"duration"] integerValue]
									  minithumbnail:nil];
		}
		case TGMessageContentKindDocument: {
			NSNumber *fileId = [flat[@"docId"] isKindOfClass:NSNumber.class] ? flat[@"docId"] : nil;
			NSNumber *thumbId = [flat[@"photoId"] isKindOfClass:NSNumber.class] ? flat[@"photoId"] : nil;
			TGDocumentContent *documentContent = [TGDocumentContent alloc];
			return [documentContent initWithFileId:fileId ? fileId.longLongValue : 0
								   thumbnailFileId:thumbId ? thumbId.longLongValue : 0
										  fileName:flat[@"docName"] ?: @""
										  mimeType:flat[@"docMime"] ?: @""
									 fileExtension:flat[@"docExtension"] ?: @""
											  size:[flat[@"docSize"] longLongValue]
									downloadedSize:[flat[@"docDownloadedSize"] longLongValue]
									  isDownloaded:[flat[@"docLocal"] boolValue]
									 isDownloading:[flat[@"docDownloading"] boolValue]
										 localPath:flat[@"docPath"] ?: @""
									 minithumbnail:nil];
		}
		case TGMessageContentKindAudio: {
			NSNumber *fileId = [flat[@"docId"] isKindOfClass:NSNumber.class] ? flat[@"docId"] : nil;
			NSNumber *coverId = [flat[@"albumCoverId"] isKindOfClass:NSNumber.class] ? flat[@"albumCoverId"] : nil;
			TGAudioContent *audioContent = [TGAudioContent alloc];
			return [audioContent initWithFileId:fileId ? fileId.longLongValue : 0
									   fileName:flat[@"docName"] ?: @""
									   mimeType:flat[@"docMime"] ?: @""
							   albumCoverFileId:coverId ? coverId.longLongValue : 0
										   size:[flat[@"docSize"] longLongValue]
										isLocal:[flat[@"docLocal"] boolValue]
										  title:flat[@"audioTitle"] ?: @""
									  performer:flat[@"audioPerformer"] ?: @""
									   duration:[flat[@"duration"] integerValue]];
		}
		case TGMessageContentKindContact: {
			TGContactContent *contactContent = [TGContactContent alloc];
			return [contactContent initWithFirstName:flat[@"contactFirstName"] ?: @""
											lastName:flat[@"contactLastName"] ?: @""
										 phoneNumber:flat[@"contactPhone"] ?: @""
											  userId:[flat[@"contactUserId"] longLongValue]
											   vcard:flat[@"contactVcard"] ?: @""];
		}
		case TGMessageContentKindVoiceNote: {
			NSData *waveform = [flat[@"waveform"] isKindOfClass:NSData.class] ? flat[@"waveform"] : nil;
			TGVoiceNoteContent *voiceNoteContent = [TGVoiceNoteContent alloc];
			return [voiceNoteContent initWithFileId:[flat[@"docId"] longLongValue]
										   duration:[flat[@"duration"] integerValue]
										   waveform:waveform];
		}
		case TGMessageContentKindVideoNote: {
			NSNumber *thumbId = [flat[@"photoId"] isKindOfClass:NSNumber.class] ? flat[@"photoId"] : nil;
			TGVideoNoteContent *videoNoteContent = [TGVideoNoteContent alloc];
			return [videoNoteContent initWithFileId:[flat[@"docId"] longLongValue]
									thumbnailFileId:thumbId ? thumbId.longLongValue : 0
										   duration:[flat[@"duration"] integerValue]
									  minithumbnail:nil];
		}
		case TGMessageContentKindCall: {
			NSString *state = [flat[@"callState"] isKindOfClass:NSString.class] ? flat[@"callState"] : @"";
			TGCallContentState callState = TGCallContentStateAnswered;
			if ([state isEqualToString:@"missed"])
				callState = TGCallContentStateMissed;
			else if ([state isEqualToString:@"declined"])
				callState = TGCallContentStateDeclined;
			BOOL isGroupCall = [flat[@"kind"] isEqualToString:@"messageGroupCall"];
			return [[TGCallContent alloc] initWithState:callState isGroupCall:isGroupCall];
		}
		case TGMessageContentKindRichMessage: {
			NSNumber *coverFileId = [flat[@"richCoverFileId"] isKindOfClass:NSNumber.class]
				? flat[@"richCoverFileId"]
				: nil;
			NSNumber *coverW = [flat[@"richCoverW"] isKindOfClass:NSNumber.class]
				? flat[@"richCoverW"]
				: nil;
			NSNumber *coverH = [flat[@"richCoverH"] isKindOfClass:NSNumber.class]
				? flat[@"richCoverH"]
				: nil;
			NSArray *rawBlocks = [flat[@"richMessageBlocks"] isKindOfClass:NSArray.class]
				? flat[@"richMessageBlocks"]
				: @[];
			TGRichMessageContent *richMessageContent = [TGRichMessageContent alloc];
			return [richMessageContent initWithRawBlocks:rawBlocks
											  isFullView:[flat[@"richMessageIsFull"] boolValue]
										   isRightToLeft:[flat[@"richMessageIsRtl"] boolValue]
												  kicker:flat[@"richKicker"] ?: @""
												   title:flat[@"richTitle"] ?: @""
												subtitle:flat[@"richSubtitle"] ?: @""
												 snippet:flat[@"richSnippet"] ?: @""
											 coverFileId:coverFileId ? coverFileId.longLongValue : 0
											  coverWidth:coverW ? coverW.integerValue : 0
											 coverHeight:coverH ? coverH.integerValue : 0];
		}
		case TGMessageContentKindPoll: {
			NSArray *rawOptions = [flat[@"pollOptions"] isKindOfClass:NSArray.class]
				? flat[@"pollOptions"]
				: @[];
			NSMutableArray<TGPollOption *> *options = [NSMutableArray arrayWithCapacity:rawOptions.count];
			for (NSDictionary *option in rawOptions) {
				if (![option isKindOfClass:NSDictionary.class])
					continue;
				id optionText = option[@"text"];
				if ([optionText isKindOfClass:NSDictionary.class])
					optionText = optionText[@"text"];
				NSString *optionId = [option[@"id"] isKindOfClass:NSString.class]
					? option[@"id"]
					: [option[@"id"] description];
				TGPollOption *pollOption = [TGPollOption alloc];
				pollOption = [pollOption initWithOptionId:optionId ?: @""
													 text:[optionText isKindOfClass:NSString.class] ? optionText : @""
										   votePercentage:[option[@"vote_percentage"] integerValue]
												 isChosen:[option[@"is_chosen"] boolValue]];
				[options addObject:pollOption];
			}
			TGPollContent *pollContent = [TGPollContent alloc];
			return [pollContent initWithQuestion:flat[@"pollQuestion"] ?: @""
										 options:options
								 totalVoterCount:[flat[@"pollTotal"] integerValue]
										isClosed:[flat[@"pollClosed"] boolValue]
									 isAnonymous:[flat[@"pollAnonymous"] boolValue]
									canAddOption:[flat[@"pollCanAddOption"] boolValue]
										  isQuiz:[flat[@"pollIsQuiz"] boolValue]
						   allowsMultipleAnswers:[flat[@"pollAllowsMultipleAnswers"] boolValue]
							  allowsRevoting:[flat[@"pollAllowsRevoting"] boolValue]
								 correctOptionId:[flat[@"pollCorrectOptionId"] integerValue]
									 explanation:[flat[@"pollExplanation"] isKindOfClass:NSString.class]
					? flat[@"pollExplanation"]
					: @""
							 explanationEntities:[flat[@"pollExplanationEntities"] isKindOfClass:NSArray.class]
					? flat[@"pollExplanationEntities"]
					: @[]];
		}
		case TGMessageContentKindChecklist: {
			NSArray *rawTasks = [flat[@"checklistTasks"] isKindOfClass:NSArray.class]
				? flat[@"checklistTasks"]
				: @[];
			NSMutableArray<TGChecklistTask *> *tasks = [NSMutableArray arrayWithCapacity:rawTasks.count];
			for (NSDictionary *task in rawTasks) {
				if (![task isKindOfClass:NSDictionary.class])
					continue;
				[tasks addObject:[[TGChecklistTask alloc]
									 initWithTaskId:[task[@"id"] longLongValue]
											   text:[task[@"text"] isKindOfClass:NSString.class] ? task[@"text"] : @""
											 isDone:[task[@"done"] boolValue]]];
			}
			TGChecklistContent *checklistContent = [TGChecklistContent alloc];
			return [checklistContent initWithTitle:flat[@"checklistTitle"] ?: TGL(@"Attachment.Todo", @"Checklist")
											 tasks:tasks
									   canAddTasks:[flat[@"checklistCanAdd"] boolValue]
								canMarkTasksAsDone:[flat[@"checklistCanMark"] boolValue]
								 othersCanAddTasks:[flat[@"checklistOthersCanAdd"] boolValue]
						  othersCanMarkTasksAsDone:[flat[@"checklistOthersCanMark"] boolValue]];
		}
		case TGMessageContentKindLocation: {
			TGLocationContent *locationContent = [TGLocationContent alloc];
			return [locationContent initWithLatitude:TGFlatDouble(flat, @"lat")
										   longitude:TGFlatDouble(flat, @"lon")];
		}
		case TGMessageContentKindVenue: {
			TGVenueContent *venueContent = [TGVenueContent alloc];
			return [venueContent initWithLatitude:TGFlatDouble(flat, @"lat")
										longitude:TGFlatDouble(flat, @"lon")
											title:flat[@"venueTitle"] ?: @""
										  address:flat[@"venueAddress"] ?: @""];
		}
		case TGMessageContentKindLiveLocation: {
			TGLiveLocationContent *liveLocationContent = [TGLiveLocationContent alloc];
			return [liveLocationContent initWithLatitude:TGFlatDouble(flat, @"lat")
											   longitude:TGFlatDouble(flat, @"lon")
												  period:TGFlatInteger(flat, @"livePeriod")
											   expiresIn:TGFlatInteger(flat, @"liveExpiresIn")
												 heading:TGFlatInteger(flat, @"liveHeading")];
		}
		case TGMessageContentKindExpiredMedia:
			return [TGTextContent new];
		case TGMessageContentKindService:
		default:
			return [TGServiceContent new];
	}
}

@implementation TGMessageItemBuilder

+ (TGMessageItem *)itemFromFlatMessage:(NSDictionary *)flat
								chatId:(int64_t)chatId
					   reuseIdentifier:(NSString *)reuseIdentifier
						  albumMembers:(NSArray *)albumMembers
							  resolved:(TGMessageItemResolvedInputs *)resolved {
	int64_t messageId = [flat[@"id"] longLongValue];
	int64_t senderId = [flat[@"senderId"] longLongValue];
	int64_t senderChatId = resolved.senderChatId;
	BOOL isService = [flat[@"service"] boolValue];
	BOOL isOutgoing = [flat[@"outgoing"] boolValue];

	TGMessageContentKind kind = TGMessageItemBuilderKind(flat, isService);
	TGMessageContent *content = TGMessageItemBuilderContent(flat, kind);

	NSString *reactionsSummaryText = [flat[@"reactions"] isKindOfClass:NSString.class]
		? flat[@"reactions"]
		: @"";

	TGMessage *message = [TGMessage alloc];
	message = [message initWithMessageId:messageId
								  chatId:chatId
							   chatTitle:@""
								senderId:senderId
									date:[flat[@"date"] doubleValue]
							  isOutgoing:isOutgoing
						   isChannelPost:[flat[@"channelPost"] boolValue]
						 authorSignature:flat[@"signature"] ?: @""
								isEdited:[flat[@"edited"] boolValue]
							   isService:isService
					  serviceNamesAuthor:[flat[@"serviceNamesAuthor"] boolValue]
						serviceActorName:flat[@"serviceActor"] ?: @""
				   pinnedTargetMessageId:TGFlatLongLong(flat, @"pinnedId")
				  oldBackgroundMessageId:TGFlatLongLong(flat, @"oldBackgroundMessageId")
									text:flat[@"text"] ?: @""
								entities:@[]
							 captionText:flat[@"caption"] ?: @""
								 albumId:@""
							   viewCount:[flat[@"views"] integerValue]
							   reactions:@[]
					reactionsSummaryText:reactionsSummaryText
							   sendState:resolved.sendState
								canRetry:[flat[@"canRetry"] boolValue]
							  isViewOnce:[flat[@"viewOnce"] boolValue]
						   destructTimer:[flat[@"destructTimer"] integerValue]
							  destructIn:[flat[@"destructIn"] doubleValue]
						   isSecretMedia:[flat[@"secretMedia"] boolValue]
							  hasSpoiler:[flat[@"hasSpoiler"] boolValue]
						   factCheckText:@""
							   replyInfo:nil
							 forwardInfo:nil
					   suggestedPostInfo:nil
									kind:kind
								 content:content];

	Class cellClass = [TGBubbleCellCatalogue cellClassForReuseIdentifier:reuseIdentifier];

	TGMessageItem *messageItem = [TGMessageItem alloc];
	return [messageItem initWithMessageId:messageId
								   chatId:chatId
								 senderId:senderId
							 senderChatId:senderChatId
								  message:message
							 albumMembers:albumMembers
						  reuseIdentifier:reuseIdentifier
								cellClass:cellClass
							  opensNewDay:resolved.opensNewDay
						carriesUnreadBand:resolved.carriesUnreadBand
						  deliveryWasRead:resolved.deliveryWasRead
								  dayText:resolved.dayText
						senderDisplayName:resolved.senderDisplayName
					   forwardDisplayName:resolved.forwardDisplayName
					    viaBotDisplayName:resolved.viaBotDisplayName
				 forwardOriginIsReachable:resolved.forwardOriginIsReachable
					  forwardAvatarUserId:resolved.forwardAvatarUserId
					  forwardAvatarChatId:resolved.forwardAvatarChatId
								 bodyText:resolved.bodyText
						   bodyRichLayout:resolved.bodyRichLayout
								stampText:resolved.stampText
							viewCountText:resolved.viewCountText
							signatureText:flat[@"signature"] ?: @""
						  serviceLineText:resolved.serviceLineText
						  quoteAuthorText:resolved.quoteAuthorText
							quoteBodyText:resolved.quoteBodyText
						  quoteRichLayout:resolved.quoteRichLayout
						   quoteIsMissing:NO
					   quoteThumbnailSize:resolved.quoteThumbnailSize
						   transcriptText:resolved.transcriptText
						  translationText:nil
							  summaryText:nil
							reactionChips:resolved.reactionChips
						  reactionRowSize:resolved.reactionRowSize
							 commentCount:[flat[@"commentCount"] integerValue]
					 commentLastMessageId:[flat[@"commentLastMessageId"] longLongValue]
						commentReplierIds:flat[@"commentReplierIds"] ?: @[]
						 hasCommentThread:[flat[@"hasCommentThread"] boolValue]
							  linkPreview:resolved.linkPreview
					 linkPreviewImageSize:resolved.linkPreviewImageSize
					   richCoverImageSize:CGSizeZero
							  pictureSize:resolved.pictureSize
						pictureLoadFailed:resolved.pictureLoadFailed
						   mediaBadgeText:resolved.mediaBadgeText
					   fileShowsThumbnail:resolved.fileShowsThumbnail
							 fileTileSide:resolved.fileTileSide
							fileTitleText:resolved.fileTitleText
							 fileMetaText:resolved.fileMetaText
						  fileCaptionText:resolved.fileCaptionText
						  fileHasCoverArt:resolved.fileHasCoverArt
					   audioClockTemplate:resolved.audioClockTemplate
					roundNoteDurationText:resolved.roundNoteDurationText
						voiceDurationText:resolved.voiceDurationText
							callTitleText:resolved.callTitleText
						   callDetailText:resolved.callDetailText
						 pollQuestionText:resolved.pollQuestionText
						 pollSubtitleText:resolved.pollSubtitleText
					   checklistTitleText:resolved.checklistTitleText
							   lottiePath:resolved.lottiePath
							   mosaicSize:resolved.mosaicSize
						 mosaicTileFrames:resolved.mosaicTileFrames ?: @[]
					  mosaicTilePositions:resolved.mosaicTilePositions ?: @[]
							 sideRevision:resolved.sideRevision];
}

@end
