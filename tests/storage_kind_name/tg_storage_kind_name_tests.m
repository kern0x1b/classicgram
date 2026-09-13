#import "tg_storage_kind_name_tests.h"
#import "../../src/Utilities/TGStorageKindName.h"

TGTestOutcome TGStorageKindNameTestNamesEveryFileTypeTheSchemaHas(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *schemaTypes = @[
		@"fileTypeNone", @"fileTypeAnimation", @"fileTypeAudio", @"fileTypeDocument",
		@"fileTypeLivePhotoVideo", @"fileTypeNotificationSound", @"fileTypePhoto",
		@"fileTypePhotoStory", @"fileTypeProfilePhoto", @"fileTypeSecret",
		@"fileTypeSecretThumbnail", @"fileTypeSecure", @"fileTypeSelfDestructingLivePhotoVideo",
		@"fileTypeSelfDestructingPhoto", @"fileTypeSelfDestructingVideo",
		@"fileTypeSelfDestructingVideoNote", @"fileTypeSelfDestructingVoiceNote",
		@"fileTypeSticker", @"fileTypeThumbnail", @"fileTypeUnknown", @"fileTypeVideo",
		@"fileTypeVideoNote", @"fileTypeVideoStory", @"fileTypeVoiceNote", @"fileTypeWallpaper",
	];

	for (NSString *type in schemaTypes) {
		NSString *name = TGStorageKindName(type);
		TGTestExpectTrue(&outcome, name.length > 0,
				"every file type the schema can report must have a name to show");
		TGTestExpectTrue(&outcome, ![name hasPrefix:@"fileType"] &&
					![name isEqualToString:[type substringFromIndex:8]],
				"no row may show the schema's own constructor name");
	}

	TGTestExpectTrue(&outcome, [TGStorageKindName(@"fileTypePhotoStory") isEqualToString:@"Photos"],
			"a story photo is counted as a photo");
	TGTestExpectTrue(&outcome,
			[TGStorageKindName(@"fileTypeSelfDestructingVoiceNote")
				isEqualToString:@"Voice Messages"],
			"a self-destructing voice note is counted as a voice message");
	TGTestExpectTrue(&outcome,
			[TGStorageKindName(@"fileTypeNotificationSound") isEqualToString:@"Sounds"],
			"a notification sound is named as a sound");
	TGTestExpectTrue(&outcome,
			[TGStorageKindName(@"fileTypeUnknown") isEqualToString:@"Other files"],
			"a type this build has never heard of falls back to other files");
	TGTestExpectTrue(&outcome, [TGStorageKindName(@"tgLocalThumbnails")
				isEqualToString:@"tgLocalThumbnails"],
			"a kind that is not a schema file type is passed through for its own caller to name");

		TGTestExpectTrue(&outcome,
			[TGStorageKindName(@"fileTypeSelfDestructingVideo") isEqualToString:
					TGStorageKindName(@"fileTypeVideo")],
			"the Data Usage screen feeds these straight from TDLib, so a self-destructing video "
			"has to read as a video rather than as Filetypeselfdestructingvideo");
	TGTestExpectTrue(&outcome,
			[TGStorageKindName(@"fileTypeNone") rangeOfString:@"iletype"].location == NSNotFound,
			"and no wire spelling survives into a row title");

return outcome;
}
