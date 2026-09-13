#import "tg_flatten_storage_tests.h"
#import "../../src/Wire/Flatten/TGFlattenStorage.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenStorageTestNetworkTypeNameRoundTripsWifi(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStorageNetworkTypeName(@"wifi") isEqualToString:@"networkTypeWiFi"],
			"the short name wifi must map to the TDLib networkTypeWiFi type name");
	TGTestExpectTrue(&outcome,
			[TGStorageNetworkShortName(@"networkTypeWiFi") isEqualToString:@"wifi"],
			"the TDLib networkTypeWiFi type name must map back to the short name wifi");

	return outcome;
}

TGTestOutcome TGFlattenStorageTestNetworkTypeNameRoundTripsMobile(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStorageNetworkTypeName(@"mobile") isEqualToString:@"networkTypeMobile"],
			"the short name mobile must map to the TDLib networkTypeMobile type name");
	TGTestExpectTrue(&outcome,
			[TGStorageNetworkTypeName(@"cellular") isEqualToString:@"networkTypeMobile"],
			"the short name cellular must also map to the TDLib networkTypeMobile type name");
	TGTestExpectTrue(&outcome,
			[TGStorageNetworkShortName(@"networkTypeMobile") isEqualToString:@"mobile"],
			"the TDLib networkTypeMobile type name must map back to the short name mobile");

	return outcome;
}

TGTestOutcome TGFlattenStorageTestNetworkTypeNameRoundTripsRoaming(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStorageNetworkTypeName(@"roaming") isEqualToString:@"networkTypeMobileRoaming"],
			"the short name roaming must map to the TDLib networkTypeMobileRoaming type name");
	TGTestExpectTrue(&outcome,
			[TGStorageNetworkShortName(@"networkTypeMobileRoaming") isEqualToString:@"roaming"],
			"the TDLib networkTypeMobileRoaming type name must map back to the short name roaming");

	return outcome;
}

TGTestOutcome TGFlattenStorageTestNetworkTypeNameRoundTripsNone(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStorageNetworkTypeName(@"none") isEqualToString:@"networkTypeNone"],
			"the short name none must map to the TDLib networkTypeNone type name");
	TGTestExpectTrue(&outcome,
			[TGStorageNetworkShortName(@"networkTypeNone") isEqualToString:@"none"],
			"the TDLib networkTypeNone type name must map back to the short name none");

	return outcome;
}

TGTestOutcome TGFlattenStorageTestNetworkTypeNameFallsBackForUnknownOrNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStorageNetworkTypeName(@"satellite") isEqualToString:@"networkTypeOther"],
			"an unrecognised short name must fall back to the TDLib networkTypeOther type name");
	TGTestExpectTrue(&outcome,
			[TGStorageNetworkTypeName(nil) isEqualToString:@"networkTypeOther"],
			"a nil short name must fall back to the TDLib networkTypeOther type name, not crash");
	TGTestExpectTrue(&outcome,
			[TGStorageNetworkShortName(@"networkTypeSomethingElse") isEqualToString:@"other"],
			"an unrecognised TDLib type name must fall back to the short name other");

	return outcome;
}

TGTestOutcome TGFlattenStorageTestFreedBytesAggregatesNestedArray(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *stats = @{
		@"by_chat" : @[
			@{
				@"chat_id" : @1,
				@"by_file_type" : @[
					@{@"file_type" : @{@"@type" : @"fileTypePhoto"}, @"size" : @1000, @"count" : @2},
					@{@"file_type" : @{@"@type" : @"fileTypeVideo"}, @"size" : @2000, @"count" : @1},
				],
			},
			@{
				@"chat_id" : @2,
				@"by_file_type" : @[
					@{@"file_type" : @{@"@type" : @"fileTypeDocument"}, @"size" : @3000, @"count" : @3},
				],
			},
			@{
				@"chat_id" : @3,
				@"by_file_type" : @[
					@{@"file_type" : @{@"@type" : @"fileTypeAudio"}, @"size" : @4000, @"count" : @1},
					@{@"file_type" : @{@"@type" : @"fileTypeSticker"}, @"size" : @5000, @"count" : @7},
				],
			},
		],
	};

	TGTestExpectEqualLongLong(&outcome, TGStorageFreedBytes(stats), 15000,
			"the freed byte total must sum every by_file_type entry across every by_chat entry");

	return outcome;
}

TGTestOutcome TGFlattenStorageTestFreedBytesReturnsZeroForEmptyArray(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualLongLong(&outcome, TGStorageFreedBytes(@{@"by_chat" : @[]}), 0,
			"an empty by_chat array must aggregate to zero freed bytes");
	TGTestExpectEqualLongLong(&outcome, TGStorageFreedBytes(@{}), 0,
			"a stats dictionary with no by_chat key must aggregate to zero freed bytes, not crash");
	TGTestExpectEqualLongLong(&outcome, TGStorageFreedBytes(nil), 0,
			"a nil stats dictionary must aggregate to zero freed bytes, not crash");

	return outcome;
}

TGTestOutcome TGFlattenStorageTestSizesByFileTypeSumsAcrossChats(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *stats = @{
		@"by_chat" : @[
			@{
				@"chat_id" : @1,
				@"by_file_type" : @[
					@{@"file_type" : @{@"@type" : @"fileTypePhoto"}, @"size" : @1000, @"count" : @2},
					@{@"file_type" : @{@"@type" : @"fileTypeVideo"}, @"size" : @2000, @"count" : @1},
				],
			},
			@{
				@"chat_id" : @2,
				@"by_file_type" : @[
					@{@"file_type" : @{@"@type" : @"fileTypePhoto"}, @"size" : @500, @"count" : @1},
					@{@"file_type" : @{@"@type" : @"fileTypeDocument"}, @"size" : @3000, @"count" : @3},
				],
			},
		],
	};

	NSDictionary *sizes = TGStorageSizesByFileType(stats);

	TGTestExpectEqualLongLong(&outcome, [sizes[@"fileTypePhoto"][@"size"] longLongValue], 1500,
			"fileTypePhoto sizes from every by_chat entry must be summed together");
	TGTestExpectEqualLongLong(&outcome, [sizes[@"fileTypePhoto"][@"count"] longLongValue], 3,
			"fileTypePhoto counts from every by_chat entry must be summed together");
	TGTestExpectEqualLongLong(&outcome, [sizes[@"fileTypeVideo"][@"size"] longLongValue], 2000,
			"a file type present in only one chat must still be carried through");
	TGTestExpectEqualLongLong(&outcome, [sizes[@"fileTypeDocument"][@"size"] longLongValue], 3000,
			"a file type present in only one chat must still be carried through");

	return outcome;
}

TGTestOutcome TGFlattenStorageTestSizesByFileTypeMatchesRegardlessOfChatGrouping(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *ungrouped = @{
		@"by_chat" : @[
			@{
				@"chat_id" : @1,
				@"by_file_type" : @[
					@{@"file_type" : @{@"@type" : @"fileTypePhoto"}, @"size" : @1000, @"count" : @2},
				],
			},
			@{
				@"chat_id" : @2,
				@"by_file_type" : @[
					@{@"file_type" : @{@"@type" : @"fileTypePhoto"}, @"size" : @500, @"count" : @1},
					@{@"file_type" : @{@"@type" : @"fileTypeVideo"}, @"size" : @700, @"count" : @1},
				],
			},
			@{
				@"chat_id" : @3,
				@"by_file_type" : @[
					@{@"file_type" : @{@"@type" : @"fileTypeVideo"}, @"size" : @300, @"count" : @1},
				],
			},
		],
	};

	NSDictionary *groupedAsChatLimitWouldReturnIt = @{
		@"by_chat" : @[
			@{
				@"chat_id" : @1,
				@"by_file_type" : @[
					@{@"file_type" : @{@"@type" : @"fileTypePhoto"}, @"size" : @1000, @"count" : @2},
				],
			},
			@{
				@"chat_id" : @0,
				@"by_file_type" : @[
					@{@"file_type" : @{@"@type" : @"fileTypePhoto"}, @"size" : @500, @"count" : @1},
					@{@"file_type" : @{@"@type" : @"fileTypeVideo"}, @"size" : @1000, @"count" : @2},
				],
			},
		],
	};

	NSDictionary *ungroupedSizes = TGStorageSizesByFileType(ungrouped);
	NSDictionary *groupedSizes = TGStorageSizesByFileType(groupedAsChatLimitWouldReturnIt);

	TGTestExpectTrue(&outcome, [ungroupedSizes isEqualToDictionary:groupedSizes],
			"chats grouped by TDLib under chat_id 0 past the chat_limit must still fold into the same"
			" by-file-type totals as when every chat is reported separately, since TDLib merges the"
			" overflow rather than dropping it");

	return outcome;
}

TGTestOutcome TGFlattenStorageTestNormalizedAutoDownloadFillsDefaultsForEmptyInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flat = TGStorageNormalizedAutoDownload(nil);

	TGTestExpectTrue(&outcome, [flat[@"enabled"] boolValue] == NO,
			"an empty auto-download input must default enabled to NO");
	TGTestExpectEqualLongLong(&outcome, [flat[@"maxPhotoSize"] longLongValue], 1024 * 1024,
			"an empty auto-download input must default maxPhotoSize to 1MB");
	TGTestExpectEqualLongLong(&outcome, [flat[@"maxVideoSize"] longLongValue], 0,
			"an empty auto-download input must default maxVideoSize to 0");
	TGTestExpectEqualLongLong(&outcome, [flat[@"maxOtherSize"] longLongValue], 0,
			"an empty auto-download input must default maxOtherSize to 0");
	TGTestExpectEqualLongLong(&outcome, [flat[@"videoUploadBitrate"] longLongValue], 0,
			"an empty auto-download input must default videoUploadBitrate to 0");
	TGTestExpectTrue(&outcome, [flat[@"preloadLargeVideos"] boolValue] == NO,
			"an empty auto-download input must default preloadLargeVideos to NO");
	TGTestExpectTrue(&outcome, [flat[@"preloadNextAudio"] boolValue] == NO,
			"an empty auto-download input must default preloadNextAudio to NO");
	TGTestExpectTrue(&outcome, [flat[@"preloadStories"] boolValue] == NO,
			"an empty auto-download input must default preloadStories to NO");
	TGTestExpectTrue(&outcome, [flat[@"useLessDataForCalls"] boolValue] == YES,
			"an empty auto-download input must default useLessDataForCalls to YES");

	return outcome;
}

TGTestOutcome TGFlattenStorageTestNormalizedAutoDownloadPreservesPartialInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *partial = @{
		@"enabled" : @YES,
		@"maxPhotoSize" : @(500000),
		@"preloadStories" : @YES,
	};

	NSDictionary *flat = TGStorageNormalizedAutoDownload(partial);

	TGTestExpectTrue(&outcome, [flat[@"enabled"] boolValue] == YES,
			"a partial auto-download input must keep the caller's enabled value");
	TGTestExpectEqualLongLong(&outcome, [flat[@"maxPhotoSize"] longLongValue], 500000,
			"a partial auto-download input must keep the caller's maxPhotoSize value");
	TGTestExpectTrue(&outcome, [flat[@"preloadStories"] boolValue] == YES,
			"a partial auto-download input must keep the caller's preloadStories value");
	TGTestExpectEqualLongLong(&outcome, [flat[@"maxVideoSize"] longLongValue], 0,
			"a partial auto-download input must still default the fields it did not supply");
	TGTestExpectTrue(&outcome, [flat[@"useLessDataForCalls"] boolValue] == YES,
			"a partial auto-download input must still default useLessDataForCalls to YES");

	return outcome;
}

TGTestOutcome TGFlattenStorageTestAutoDownloadFromPresetFillsDefaultsForEmptyInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flat = TGStorageAutoDownloadFromPreset(nil);

	TGTestExpectTrue(&outcome, [flat[@"enabled"] boolValue] == NO,
			"an empty preset must default enabled to NO");
	TGTestExpectEqualLongLong(&outcome, [flat[@"maxPhotoSize"] longLongValue], 0,
			"an empty preset must default maxPhotoSize to 0, unlike the normalized-settings default");
	TGTestExpectEqualLongLong(&outcome, [flat[@"maxVideoSize"] longLongValue], 0,
			"an empty preset must default maxVideoSize to 0");
	TGTestExpectEqualLongLong(&outcome, [flat[@"maxOtherSize"] longLongValue], 0,
			"an empty preset must default maxOtherSize to 0");
	TGTestExpectEqualLongLong(&outcome, [flat[@"videoUploadBitrate"] longLongValue], 0,
			"an empty preset must default videoUploadBitrate to 0");
	TGTestExpectTrue(&outcome, [flat[@"preloadLargeVideos"] boolValue] == NO,
			"an empty preset must default preloadLargeVideos to NO");
	TGTestExpectTrue(&outcome, [flat[@"preloadNextAudio"] boolValue] == NO,
			"an empty preset must default preloadNextAudio to NO");
	TGTestExpectTrue(&outcome, [flat[@"preloadStories"] boolValue] == NO,
			"an empty preset must default preloadStories to NO");
	TGTestExpectTrue(&outcome, [flat[@"useLessDataForCalls"] boolValue] == YES,
			"an empty preset must default useLessDataForCalls to YES");

	return outcome;
}

TGTestOutcome TGFlattenStorageTestAutoDownloadFromPresetMapsFullInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *preset = @{
		@"is_auto_download_enabled" : @YES,
		@"max_photo_file_size" : @(1024 * 1024),
		@"max_video_file_size" : @(10 * 1024 * 1024),
		@"max_other_file_size" : @(2 * 1024 * 1024),
		@"video_upload_bitrate" : @64,
		@"preload_large_videos" : @YES,
		@"preload_next_audio" : @YES,
		@"preload_stories" : @YES,
		@"use_less_data_for_calls" : @NO,
	};

	NSDictionary *flat = TGStorageAutoDownloadFromPreset(preset);

	TGTestExpectTrue(&outcome, [flat[@"enabled"] boolValue] == YES,
			"a full preset's is_auto_download_enabled must map to enabled");
	TGTestExpectEqualLongLong(&outcome, [flat[@"maxPhotoSize"] longLongValue], 1024 * 1024,
			"a full preset's max_photo_file_size must map to maxPhotoSize");
	TGTestExpectEqualLongLong(&outcome, [flat[@"maxVideoSize"] longLongValue], 10 * 1024 * 1024,
			"a full preset's max_video_file_size must map to maxVideoSize");
	TGTestExpectEqualLongLong(&outcome, [flat[@"maxOtherSize"] longLongValue], 2 * 1024 * 1024,
			"a full preset's max_other_file_size must map to maxOtherSize");
	TGTestExpectEqualLongLong(&outcome, [flat[@"videoUploadBitrate"] longLongValue], 64,
			"a full preset's video_upload_bitrate must map to videoUploadBitrate");
	TGTestExpectTrue(&outcome, [flat[@"preloadLargeVideos"] boolValue] == YES,
			"a full preset's preload_large_videos must map to preloadLargeVideos");
	TGTestExpectTrue(&outcome, [flat[@"preloadNextAudio"] boolValue] == YES,
			"a full preset's preload_next_audio must map to preloadNextAudio");
	TGTestExpectTrue(&outcome, [flat[@"preloadStories"] boolValue] == YES,
			"a full preset's preload_stories must map to preloadStories");
	TGTestExpectTrue(&outcome, [flat[@"useLessDataForCalls"] boolValue] == NO,
			"a full preset's use_less_data_for_calls must map to useLessDataForCalls, overriding its YES default");

	return outcome;
}

TGTestOutcome TGFlattenStorageTestNetworkTypeNameFoldsCaseAndAliases(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGStorageNetworkTypeName(@"WiFi") isEqualToString:@"networkTypeWiFi"],
			"the settings screen stores its network kind in whatever case it likes, so the mapping folds case "
			"before matching");
	TGTestExpectTrue(&outcome, [TGStorageNetworkTypeName(@"ROAMING") isEqualToString:@"networkTypeMobileRoaming"],
			"upper case matches too");
	TGTestExpectTrue(&outcome, [TGStorageNetworkTypeName(@"cellular") isEqualToString:@"networkTypeMobile"],
			"cellular is an accepted alias of mobile, since both spellings appear in this codebase");
	TGTestExpectTrue(&outcome, [TGStorageNetworkTypeName(@"none") isEqualToString:@"networkTypeNone"],
			"none maps to its own schema constructor rather than falling through to other");
	TGTestExpectTrue(&outcome, [TGStorageNetworkTypeName(@"satellite") isEqualToString:@"networkTypeOther"],
			"an unrecognised kind maps to networkTypeOther, a real schema constructor, not to nil");
	TGTestExpectTrue(&outcome, [TGStorageNetworkTypeName(nil) isEqualToString:@"networkTypeOther"],
			"a nil kind must not crash while building a statistics request");

	return outcome;
}

