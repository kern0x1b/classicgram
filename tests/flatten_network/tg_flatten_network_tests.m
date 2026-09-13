#import "tg_flatten_network_tests.h"
#import "../../src/Wire/Flatten/TGFlattenNetwork.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenNetworkTestNetworkTypeNameMapsKnownKinds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGNetNetworkTypeName(@"none") isEqualToString:@"networkTypeNone"],
			"\"none\" must map to networkTypeNone");
	TGTestExpectTrue(&outcome, [TGNetNetworkTypeName(@"mobile") isEqualToString:@"networkTypeMobile"],
			"\"mobile\" must map to networkTypeMobile");
	TGTestExpectTrue(&outcome,
			[TGNetNetworkTypeName(@"mobileroaming") isEqualToString:@"networkTypeMobileRoaming"],
			"\"mobileroaming\" must map to networkTypeMobileRoaming");
	TGTestExpectTrue(&outcome, [TGNetNetworkTypeName(@"roaming") isEqualToString:@"networkTypeMobileRoaming"],
			"\"roaming\" is an alias for mobileroaming and must map to networkTypeMobileRoaming");
	TGTestExpectTrue(&outcome, [TGNetNetworkTypeName(@"wifi") isEqualToString:@"networkTypeWiFi"],
			"\"wifi\" must map to networkTypeWiFi");
	TGTestExpectTrue(&outcome, [TGNetNetworkTypeName(@"WiFi") isEqualToString:@"networkTypeWiFi"],
			"the mapper must be case-insensitive on its input, so \"WiFi\" also maps to networkTypeWiFi");
	TGTestExpectTrue(&outcome, [TGNetNetworkTypeName(@"MOBILE") isEqualToString:@"networkTypeMobile"],
			"the mapper must be case-insensitive on its input, so \"MOBILE\" also maps to networkTypeMobile");

	return outcome;
}

TGTestOutcome TGFlattenNetworkTestNetworkTypeNameFallsBackForUnknownOrNilKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGNetNetworkTypeName(@"cellular") isEqualToString:@"networkTypeOther"],
			"an unrecognised network kind must fall back to networkTypeOther, not crash");
	TGTestExpectTrue(&outcome, [TGNetNetworkTypeName(@"") isEqualToString:@"networkTypeOther"],
			"an empty network kind must fall back to networkTypeOther");
	TGTestExpectTrue(&outcome, [TGNetNetworkTypeName(nil) isEqualToString:@"networkTypeOther"],
			"a nil network kind must fall back to networkTypeOther, not crash");

	return outcome;
}

TGTestOutcome TGFlattenNetworkTestProxyTypeObjectBuildsMtproto(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *full = @{@"type" : @"mtproto", @"secret" : @"deadbeef"};
	NSDictionary *object = TGNetProxyTypeObject(full);

	TGTestExpectTrue(&outcome, [object[@"@type"] isEqualToString:@"proxyTypeMtproto"],
			"a flat proxy of type \"mtproto\" must build a proxyTypeMtproto TDLib object");
	TGTestExpectTrue(&outcome, [object[@"secret"] isEqualToString:@"deadbeef"],
			"the mtproto object's secret must round-trip verbatim from the flat dict");

	NSDictionary *missing = @{@"type" : @"mtproto"};
	NSDictionary *missingObject = TGNetProxyTypeObject(missing);
	TGTestExpectTrue(&outcome, [missingObject[@"secret"] isEqualToString:@""],
			"a missing secret must default to an empty string, not nil or crash");

	return outcome;
}

TGTestOutcome TGFlattenNetworkTestProxyTypeObjectBuildsHttp(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *full = @{@"type" : @"http",
		@"username" : @"alice",
		@"password" : @"s3cret",
		@"httpOnly" : @YES};
	NSDictionary *object = TGNetProxyTypeObject(full);

	TGTestExpectTrue(&outcome, [object[@"@type"] isEqualToString:@"proxyTypeHttp"],
			"a flat proxy of type \"http\" must build a proxyTypeHttp TDLib object");
	TGTestExpectTrue(&outcome, [object[@"username"] isEqualToString:@"alice"],
			"the http object's username must round-trip verbatim");
	TGTestExpectTrue(&outcome, [object[@"password"] isEqualToString:@"s3cret"],
			"the http object's password must round-trip verbatim");
	TGTestExpectTrue(&outcome, [object[@"http_only"] boolValue],
			"the http object's http_only must round-trip from httpOnly when YES");

	NSDictionary *missing = @{@"type" : @"http"};
	NSDictionary *missingObject = TGNetProxyTypeObject(missing);
	TGTestExpectTrue(&outcome, [missingObject[@"username"] isEqualToString:@""],
			"a missing username must default to an empty string");
	TGTestExpectTrue(&outcome, [missingObject[@"password"] isEqualToString:@""],
			"a missing password must default to an empty string");
	TGTestExpectTrue(&outcome, ![missingObject[@"http_only"] boolValue],
			"a missing httpOnly must default to NO");

	return outcome;
}

TGTestOutcome TGFlattenNetworkTestProxyTypeObjectFallsBackToSocks5(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *explicit = @{@"type" : @"socks5", @"username" : @"bob", @"password" : @"hunter2"};
	NSDictionary *explicitObject = TGNetProxyTypeObject(explicit);
	TGTestExpectTrue(&outcome, [explicitObject[@"@type"] isEqualToString:@"proxyTypeSocks5"],
			"a flat proxy of type \"socks5\" must build a proxyTypeSocks5 TDLib object");
	TGTestExpectTrue(&outcome, [explicitObject[@"username"] isEqualToString:@"bob"],
			"the socks5 object's username must round-trip verbatim");

	NSDictionary *unknown = @{@"type" : @"wireguard"};
	NSDictionary *unknownObject = TGNetProxyTypeObject(unknown);
	TGTestExpectTrue(&outcome, [unknownObject[@"@type"] isEqualToString:@"proxyTypeSocks5"],
			"an unrecognised proxy type must fall back to proxyTypeSocks5, not crash");

	NSDictionary *missingType = @{@"username" : @"carol"};
	NSDictionary *missingTypeObject = TGNetProxyTypeObject(missingType);
	TGTestExpectTrue(&outcome, [missingTypeObject[@"@type"] isEqualToString:@"proxyTypeSocks5"],
			"a missing proxy type must also fall back to proxyTypeSocks5");

	return outcome;
}

TGTestOutcome TGFlattenNetworkTestProxyDictParsesMtprotoFromTDLibObject(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *proxy = @{@"server" : @"1.2.3.4",
		@"port" : @443,
		@"type" : @{@"@type" : @"proxyTypeMtproto", @"secret" : @"cafebabe"}};
	NSDictionary *flat = TGNetProxyDict(proxy, nil);

	TGTestExpectTrue(&outcome, [flat[@"server"] isEqualToString:@"1.2.3.4"],
			"the flat dict's server must round-trip from the TDLib proxy's server");
	TGTestExpectEqualInteger(&outcome, [flat[@"port"] integerValue], 443,
			"the flat dict's port must round-trip from the TDLib proxy's port");
	TGTestExpectTrue(&outcome, [flat[@"type"] isEqualToString:@"mtproto"],
			"a proxyTypeMtproto TDLib type must flatten to the \"mtproto\" kind string");
	TGTestExpectTrue(&outcome, [flat[@"secret"] isEqualToString:@"cafebabe"],
			"the flat dict's secret must round-trip from the mtproto type's secret");
	TGTestExpectTrue(&outcome, [flat[@"username"] isEqualToString:@""],
			"an mtproto proxy has no username, so it must flatten to an empty string, not nil");
	TGTestExpectTrue(&outcome, flat[@"id"] == nil,
			"with no added-proxy metadata, the flat dict must carry no id key at all");

	return outcome;
}

TGTestOutcome TGFlattenNetworkTestProxyDictParsesHttpFromTDLibObject(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *proxy = @{@"server" : @"proxy.example.com",
		@"port" : @8080,
		@"type" : @{@"@type" : @"proxyTypeHttp",
			@"username" : @"alice",
			@"password" : @"s3cret",
			@"http_only" : @YES}};
	NSDictionary *flat = TGNetProxyDict(proxy, nil);

	TGTestExpectTrue(&outcome, [flat[@"type"] isEqualToString:@"http"],
			"a proxyTypeHttp TDLib type must flatten to the \"http\" kind string");
	TGTestExpectTrue(&outcome, [flat[@"username"] isEqualToString:@"alice"],
			"the flat dict's username must round-trip from the http type's username");
	TGTestExpectTrue(&outcome, [flat[@"password"] isEqualToString:@"s3cret"],
			"the flat dict's password must round-trip from the http type's password");
	TGTestExpectTrue(&outcome, [flat[@"httpOnly"] boolValue],
			"the flat dict's httpOnly must round-trip from the http type's http_only when YES");
	TGTestExpectTrue(&outcome, [flat[@"secret"] isEqualToString:@""],
			"an http proxy has no secret, so it must flatten to an empty string, not nil");

	NSDictionary *missingFields = @{@"server" : @"proxy.example.com",
		@"port" : @8080,
		@"type" : @{@"@type" : @"proxyTypeHttp"}};
	NSDictionary *missingFlat = TGNetProxyDict(missingFields, nil);
	TGTestExpectTrue(&outcome, [missingFlat[@"username"] isEqualToString:@""],
			"a missing http username must flatten to an empty string");
	TGTestExpectTrue(&outcome, ![missingFlat[@"httpOnly"] boolValue],
			"a missing http_only must flatten to NO");

	return outcome;
}

TGTestOutcome TGFlattenNetworkTestProxyDictParsesSocks5FromTDLibObject(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *proxy = @{@"server" : @"10.0.0.1",
		@"port" : @1080,
		@"type" : @{@"@type" : @"proxyTypeSocks5", @"username" : @"bob", @"password" : @"hunter2"}};
	NSDictionary *flat = TGNetProxyDict(proxy, nil);

	TGTestExpectTrue(&outcome, [flat[@"type"] isEqualToString:@"socks5"],
			"a proxyTypeSocks5 TDLib type must flatten to the \"socks5\" kind string");
	TGTestExpectTrue(&outcome, [flat[@"username"] isEqualToString:@"bob"],
			"the flat dict's username must round-trip from the socks5 type's username");
	TGTestExpectTrue(&outcome, [flat[@"password"] isEqualToString:@"hunter2"],
			"the flat dict's password must round-trip from the socks5 type's password");

	NSDictionary *noType = @{@"server" : @"10.0.0.1", @"port" : @1080};
	NSDictionary *noTypeFlat = TGNetProxyDict(noType, nil);
	TGTestExpectTrue(&outcome, [noTypeFlat[@"type"] isEqualToString:@"socks5"],
			"a proxy with no type sub-object at all must flatten to the \"socks5\" kind as a safe default");
	TGTestExpectTrue(&outcome, [noTypeFlat[@"username"] isEqualToString:@""],
			"a proxy with no type sub-object must still produce an empty username, not crash");

	return outcome;
}

TGTestOutcome TGFlattenNetworkTestProxyDictReturnsNilForNonDictionaryInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGNetProxyDict(nil, nil) == nil,
			"a nil TDLib proxy must flatten to nil, not crash or fabricate a dictionary");
	TGTestExpectTrue(&outcome, TGNetProxyDict((NSDictionary *)@"not a dictionary", nil) == nil,
			"a non-dictionary TDLib proxy must flatten to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenNetworkTestAddedProxyDictMergesAddedFields(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *added = @{@"id" : @7,
		@"is_enabled" : @YES,
		@"comment" : @"work proxy",
		@"last_used_date" : @123456,
		@"proxy" : @{@"server" : @"1.2.3.4",
			@"port" : @443,
			@"type" : @{@"@type" : @"proxyTypeMtproto", @"secret" : @"cafebabe"}}};
	NSDictionary *flat = TGNetAddedProxyDict(added);

	TGTestExpectEqualInteger(&outcome, [flat[@"id"] integerValue], 7,
			"the merged dict's id must round-trip from the added proxy's id");
	TGTestExpectTrue(&outcome, [flat[@"isEnabled"] boolValue],
			"the merged dict's isEnabled must round-trip from is_enabled when YES");
	TGTestExpectTrue(&outcome, [flat[@"comment"] isEqualToString:@"work proxy"],
			"the merged dict's comment must round-trip verbatim");
	TGTestExpectEqualInteger(&outcome, [flat[@"lastUsedDate"] integerValue], 123456,
			"the merged dict's lastUsedDate must round-trip from last_used_date");
	TGTestExpectTrue(&outcome, [flat[@"secret"] isEqualToString:@"cafebabe"],
			"the merged dict must still carry the inner proxy's own fields, like secret");

	NSDictionary *sparse = @{@"proxy" : @{@"server" : @"1.2.3.4",
		@"port" : @443,
		@"type" : @{@"@type" : @"proxyTypeSocks5"}}};
	NSDictionary *sparseFlat = TGNetAddedProxyDict(sparse);
	TGTestExpectEqualInteger(&outcome, [sparseFlat[@"id"] integerValue], 0,
			"a missing id on the added proxy must default to 0");
	TGTestExpectTrue(&outcome, ![sparseFlat[@"isEnabled"] boolValue],
			"a missing is_enabled on the added proxy must default to NO");
	TGTestExpectTrue(&outcome, [sparseFlat[@"comment"] isEqualToString:@""],
			"a missing comment on the added proxy must default to an empty string");

	return outcome;
}

TGTestOutcome TGFlattenNetworkTestAddedProxyDictReturnsNilForNonDictionaryInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGNetAddedProxyDict(nil) == nil,
			"a nil added-proxy payload must flatten to nil, not crash");
	TGTestExpectTrue(&outcome, TGNetAddedProxyDict((NSDictionary *)@17) == nil,
			"a non-dictionary added-proxy payload must flatten to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenNetworkTestProxyRoundTripsThroughBothDirectionsForEachKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flatMtproto = @{@"type" : @"mtproto", @"secret" : @"topsecret"};
	NSDictionary *mtprotoTypeObject = TGNetProxyTypeObject(flatMtproto);
	NSDictionary *mtprotoProxyObject = @{@"server" : @"a.example.com", @"port" : @443, @"type" : mtprotoTypeObject};
	NSDictionary *mtprotoRoundTrip = TGNetProxyDict(mtprotoProxyObject, nil);
	TGTestExpectTrue(&outcome, [mtprotoRoundTrip[@"type"] isEqualToString:@"mtproto"],
			"an mtproto flat dict sent through TGNetProxyTypeObject and back through TGNetProxyDict must still read as \"mtproto\"");
	TGTestExpectTrue(&outcome, [mtprotoRoundTrip[@"secret"] isEqualToString:@"topsecret"],
			"an mtproto secret must survive the round trip through both directions unchanged");

	NSDictionary *flatHttp = @{@"type" : @"http", @"username" : @"alice", @"password" : @"pw", @"httpOnly" : @YES};
	NSDictionary *httpTypeObject = TGNetProxyTypeObject(flatHttp);
	NSDictionary *httpProxyObject = @{@"server" : @"b.example.com", @"port" : @8080, @"type" : httpTypeObject};
	NSDictionary *httpRoundTrip = TGNetProxyDict(httpProxyObject, nil);
	TGTestExpectTrue(&outcome, [httpRoundTrip[@"type"] isEqualToString:@"http"],
			"an http flat dict sent through both directions must still read as \"http\"");
	TGTestExpectTrue(&outcome, [httpRoundTrip[@"username"] isEqualToString:@"alice"],
			"an http username must survive the round trip through both directions unchanged");
	TGTestExpectTrue(&outcome, [httpRoundTrip[@"httpOnly"] boolValue],
			"an http httpOnly flag must survive the round trip through both directions unchanged");

	NSDictionary *flatSocks5 = @{@"type" : @"socks5", @"username" : @"bob", @"password" : @"pw2"};
	NSDictionary *socks5TypeObject = TGNetProxyTypeObject(flatSocks5);
	NSDictionary *socks5ProxyObject = @{@"server" : @"c.example.com", @"port" : @1080, @"type" : socks5TypeObject};
	NSDictionary *socks5RoundTrip = TGNetProxyDict(socks5ProxyObject, nil);
	TGTestExpectTrue(&outcome, [socks5RoundTrip[@"type"] isEqualToString:@"socks5"],
			"a socks5 flat dict sent through both directions must still read as \"socks5\"");
	TGTestExpectTrue(&outcome, [socks5RoundTrip[@"username"] isEqualToString:@"bob"],
			"a socks5 username must survive the round trip through both directions unchanged");

	return outcome;
}

TGTestOutcome TGFlattenNetworkTestSettingsDictComposesFromTDLibObject(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *settings = @{
		@"is_auto_download_enabled" : @YES,
		@"max_photo_file_size" : @1048576,
		@"max_video_file_size" : @15728640,
		@"max_other_file_size" : @1048576,
		@"video_upload_bitrate" : @64,
		@"preload_large_videos" : @NO,
		@"preload_next_audio" : @YES,
		@"preload_stories" : @NO,
		@"use_less_data_for_calls" : @YES,
	};
	NSDictionary *flat = TGNetSettingsDict(settings);

	TGTestExpectTrue(&outcome, flat != nil, "a well-formed autoDownloadSettings must compose to a dictionary");
	TGTestExpectTrue(&outcome, [flat[@"enabled"] boolValue],
			"the composed dict's enabled must round-trip from is_auto_download_enabled");
	TGTestExpectEqualInteger(&outcome, [flat[@"maxPhotoSize"] integerValue], 1048576,
			"the composed dict's maxPhotoSize must round-trip from max_photo_file_size");
	TGTestExpectEqualInteger(&outcome, [flat[@"maxVideoSize"] integerValue], 15728640,
			"the composed dict's maxVideoSize must round-trip from max_video_file_size");
	TGTestExpectEqualInteger(&outcome, [flat[@"maxOtherSize"] integerValue], 1048576,
			"the composed dict's maxOtherSize must round-trip from max_other_file_size");
	TGTestExpectEqualInteger(&outcome, [flat[@"videoUploadBitrate"] integerValue], 64,
			"the composed dict's videoUploadBitrate must round-trip from video_upload_bitrate");
	TGTestExpectTrue(&outcome, ![flat[@"preloadLargeVideos"] boolValue],
			"the composed dict's preloadLargeVideos must round-trip from preload_large_videos when NO");
	TGTestExpectTrue(&outcome, [flat[@"preloadNextAudio"] boolValue],
			"the composed dict's preloadNextAudio must round-trip from preload_next_audio when YES");
	TGTestExpectTrue(&outcome, ![flat[@"preloadStories"] boolValue],
			"the composed dict's preloadStories must round-trip from preload_stories when NO");
	TGTestExpectTrue(&outcome, [flat[@"useLessDataForCalls"] boolValue],
			"the composed dict's useLessDataForCalls must round-trip from use_less_data_for_calls when YES");

	NSDictionary *sparse = @{@"is_auto_download_enabled" : @YES};
	NSDictionary *sparseFlat = TGNetSettingsDict(sparse);
	TGTestExpectEqualInteger(&outcome, [sparseFlat[@"maxPhotoSize"] integerValue], 0,
			"a missing max_photo_file_size must default to 0, not crash");
	TGTestExpectTrue(&outcome, ![sparseFlat[@"preloadLargeVideos"] boolValue],
			"a missing preload_large_videos must default to NO");

	return outcome;
}

TGTestOutcome TGFlattenNetworkTestSettingsDictReturnsNilForNonDictionaryInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGNetSettingsDict(nil) == nil,
			"a nil autoDownloadSettings must compose to nil, not crash or fabricate a dictionary");
	TGTestExpectTrue(&outcome, TGNetSettingsDict((NSDictionary *)@"not a dictionary") == nil,
			"a non-dictionary autoDownloadSettings must compose to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenNetworkTestSettingsObjectComposesFromFlatDict(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flat = @{
		@"enabled" : @YES,
		@"maxPhotoSize" : @2097152,
		@"maxVideoSize" : @31457280,
		@"maxOtherSize" : @2097152,
		@"videoUploadBitrate" : @128,
		@"preloadLargeVideos" : @YES,
		@"preloadNextAudio" : @NO,
		@"preloadStories" : @YES,
		@"useLessDataForCalls" : @NO,
	};
	NSDictionary *object = TGNetSettingsObject(flat);

	TGTestExpectTrue(&outcome, [object[@"@type"] isEqualToString:@"autoDownloadSettings"],
			"the composed TDLib object must carry the autoDownloadSettings discriminator");
	TGTestExpectTrue(&outcome, [object[@"is_auto_download_enabled"] boolValue],
			"the composed object's is_auto_download_enabled must round-trip from enabled");
	TGTestExpectEqualInteger(&outcome, [object[@"max_photo_file_size"] integerValue], 2097152,
			"the composed object's max_photo_file_size must round-trip from maxPhotoSize");
	TGTestExpectEqualInteger(&outcome, [object[@"max_video_file_size"] integerValue], 31457280,
			"the composed object's max_video_file_size must round-trip from maxVideoSize");
	TGTestExpectEqualInteger(&outcome, [object[@"video_upload_bitrate"] integerValue], 128,
			"the composed object's video_upload_bitrate must round-trip from videoUploadBitrate");
	TGTestExpectTrue(&outcome, [object[@"preload_large_videos"] boolValue],
			"the composed object's preload_large_videos must round-trip from preloadLargeVideos when YES");
	TGTestExpectTrue(&outcome, ![object[@"preload_next_audio"] boolValue],
			"the composed object's preload_next_audio must round-trip from preloadNextAudio when NO");
	TGTestExpectTrue(&outcome, [object[@"preload_stories"] boolValue],
			"the composed object's preload_stories must round-trip from preloadStories when YES");
	TGTestExpectTrue(&outcome, ![object[@"use_less_data_for_calls"] boolValue],
			"the composed object's use_less_data_for_calls must round-trip from useLessDataForCalls when NO");

	NSDictionary *sparse = @{@"enabled" : @NO};
	NSDictionary *sparseObject = TGNetSettingsObject(sparse);
	TGTestExpectEqualInteger(&outcome, [sparseObject[@"max_photo_file_size"] integerValue], 0,
			"a missing maxPhotoSize must default to 0, not crash");
	TGTestExpectTrue(&outcome, ![sparseObject[@"preload_stories"] boolValue],
			"a missing preloadStories must default to NO");

	return outcome;
}

TGTestOutcome TGFlattenNetworkTestSettingsObjectFallsBackForNonDictionaryInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *fromNil = TGNetSettingsObject(nil);
	TGTestExpectTrue(&outcome, [fromNil[@"@type"] isEqualToString:@"autoDownloadSettings"],
			"a nil settings input must still compose a well-formed autoDownloadSettings object, not nil or crash");
	TGTestExpectTrue(&outcome, ![fromNil[@"is_auto_download_enabled"] boolValue],
			"a nil settings input must default every flag to NO");

	NSDictionary *fromGarbage = TGNetSettingsObject((NSDictionary *)@3.14);
	TGTestExpectTrue(&outcome, [fromGarbage[@"@type"] isEqualToString:@"autoDownloadSettings"],
			"a non-dictionary settings input must still compose a well-formed autoDownloadSettings object, not crash");

	return outcome;
}

TGTestOutcome TGFlattenNetworkTestSettingsRoundTripsThroughBothDirections(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flat = @{
		@"enabled" : @YES,
		@"maxPhotoSize" : @999,
		@"maxVideoSize" : @888,
		@"maxOtherSize" : @777,
		@"videoUploadBitrate" : @55,
		@"preloadLargeVideos" : @YES,
		@"preloadNextAudio" : @NO,
		@"preloadStories" : @YES,
		@"useLessDataForCalls" : @NO,
	};
	NSDictionary *object = TGNetSettingsObject(flat);
	NSDictionary *roundTripped = TGNetSettingsDict(object);

	TGTestExpectTrue(&outcome, [roundTripped[@"enabled"] boolValue] == [flat[@"enabled"] boolValue],
			"enabled must survive a round trip through TGNetSettingsObject and back through TGNetSettingsDict");
	TGTestExpectEqualInteger(&outcome, [roundTripped[@"maxPhotoSize"] integerValue],
			[flat[@"maxPhotoSize"] integerValue],
			"maxPhotoSize must survive the round trip unchanged");
	TGTestExpectEqualInteger(&outcome, [roundTripped[@"maxVideoSize"] integerValue],
			[flat[@"maxVideoSize"] integerValue],
			"maxVideoSize must survive the round trip unchanged");
	TGTestExpectEqualInteger(&outcome, [roundTripped[@"videoUploadBitrate"] integerValue],
			[flat[@"videoUploadBitrate"] integerValue],
			"videoUploadBitrate must survive the round trip unchanged");
	TGTestExpectTrue(&outcome,
			[roundTripped[@"preloadLargeVideos"] boolValue] == [flat[@"preloadLargeVideos"] boolValue],
			"preloadLargeVideos must survive the round trip unchanged");
	TGTestExpectTrue(&outcome,
			[roundTripped[@"useLessDataForCalls"] boolValue] == [flat[@"useLessDataForCalls"] boolValue],
			"useLessDataForCalls must survive the round trip unchanged");

	return outcome;
}
