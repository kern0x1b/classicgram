#import "TGGroupedCaption.h"
#import "TGWallpaperListText.h"
#import "TGImageDecode.h"
#import "TGAccountUsernamesViewController.h"
#import "TGAccountSettingsViewController.h"
#import "TGLocalization.h"
#import "TGNotificationManager.h"
#import "TGSettingsViewController.h"
#import "TGEmoji.h"
#import "RootViewController.h"
#import "TGTheme.h"
#import "TGSessionsViewController.h"
#import "TGDeviceViewController.h"
#import "TGWebBrowserSettingsViewController.h"
#import "TGDevice.h"
#import "TGFoldersViewController.h"
#import "TGProxyViewController.h"
#import "TGPrivacyViewController.h"
#import "TGPrivacyViewController.h"
#import "TGTabBar.h"
#import "TGSettingsService.h"
#import "TGSnackbar.h"
#import "TGPreferenceFlags.h"
#import "TGCapabilities.h"
#import "TGAccountManager.h"
#import "TGPhoneFormat.h"
#import "TGIcons.h"
#import <QuartzCore/QuartzCore.h>
#import "TGSettingsViewControllerInternal.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGWallpaperRowText.h"
#import "TGHexColour.h"

@implementation TGSettingsViewController (AutoDownload)

#pragma mark - account switch

+ (void)resetDataSaverCacheForAccountSwitch {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:@"TGDataSaver"];
	[defaults removeObjectForKey:TGSettingsSavedPresetsKey];
	[defaults removeObjectForKey:TGSettingsSavedCustomSettingsKey];
	[defaults removeObjectForKey:TGSettingsLessCallDataKey];
	[defaults removeObjectForKey:TGSettingsWallpaperBlurKey];
	[defaults synchronize];
}

#pragma mark - auto-download, one network at a time

+ (NSArray *)autoDownloadKindKeys {
	static NSArray *keys = nil;
	if (!keys)
		keys = @[ @"maxPhotoSize", @"maxVideoSize", @"maxOtherSize" ];
	return keys;
}

+ (NSArray *)autoDownloadKindTitles {
	return @[ TGL(@"AutoDownloadSettings.Photos", @"Photos"),
		TGL(@"AutoDownloadSettings.Videos", @"Videos"),
		TGL(@"AutoDownloadSettings.FilesAndGifs", @"Files and GIFs") ];
}

+ (NSArray *)autoDownloadPreloadKeys {
	static NSArray *keys = nil;
	if (!keys)
		keys = @[ @"preloadLargeVideos", @"preloadStories", @"preloadNextAudio" ];
	return keys;
}

+ (NSArray *)autoDownloadPreloadTitles {
	return @[ TGL(@"AutoDownloadSettings.PreloadVideo", @"Preload larger videos"),
		TGL(@"Settings.PreloadStories", @"Preload stories"),
		TGL(@"AutoDownloadSettings.PreloadNextAudioTitle", @"Preload Next Audio Track") ];
}

+ (NSArray *)autoDownloadPhotoLimits {
	static NSArray *limits = nil;
	if (!limits)
		limits = @[ @0, @(102400), @(524288), @(1048576), @(5242880) ];
	return limits;
}

+ (NSArray *)autoDownloadFileLimits {
	static NSArray *limits = nil;
	if (!limits)
		limits = @[ @0, @(524288), @(1048576), @(5242880),
			@(10485760), @(52428800) ];
	return limits;
}

+ (NSArray *)autoDownloadLimitsForKey:(NSString *)key {
	return [key isEqualToString:@"maxPhotoSize"]
		? [TGSettingsViewController autoDownloadPhotoLimits]
		: [TGSettingsViewController autoDownloadFileLimits];
}

+ (NSString *)autoDownloadLimitTitle:(long long)bytes {
	return bytes <= 0 ? TGL(@"PrivacySettings.PasscodeOff", @"Off") : TGSettingsBytes(bytes);
}

+ (NSString *)titleForNetworkKind:(NSString *)kind {
	NSInteger index = [[TGSettingsViewController networkKinds] indexOfObject:kind ?: @""];
	if (index == NSNotFound)
		return TGL(@"AutoDownloadSettings.Title", @"Auto-Download");
	return [TGSettingsViewController networkTitles][index];
}

- (void)loadAutoDownloadKindPage {
	self.autoDownloadValues = [NSMutableDictionary dictionary];
	NSDictionary *mirror = [TGSettingsService autoDownloadSettingsForNetworkType:self.autoDownloadKind];
	if ([mirror isKindOfClass:[NSDictionary class]] && mirror.count) {
		[self.autoDownloadValues addEntriesFromDictionary:mirror];
		[self.tableView reloadData];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[TGSettingsService autoDownloadPresetNamed:@"medium"
									completion:^(NSDictionary *preset) {
										__strong typeof(weakSelf) strongSelf = weakSelf;
										if (!strongSelf)
											return;
										if ([preset isKindOfClass:[NSDictionary class]])
											[strongSelf.autoDownloadValues addEntriesFromDictionary:preset];
										[strongSelf.tableView reloadData];
									}];
}

- (BOOL)autoDownloadFlagForKey:(NSString *)key {
	return [self.autoDownloadValues[key] boolValue];
}

- (long long)autoDownloadLimitForKey:(NSString *)key {
	return [self.autoDownloadValues[key] longLongValue];
}

- (void)commitAutoDownloadValuesFrom:(NSDictionary *)previousValues {
	[self rememberPreset:nil forNetwork:self.autoDownloadKind];
	[self.tableView reloadData];

	NSDictionary *values = [self.autoDownloadValues copy];
	NSString *kind = self.autoDownloadKind;
	__weak typeof(self) weakSelf = self;
	[TGSettingsService setAutoDownloadSettings:values
								forNetworkType:kind
									completion:^(BOOL ok) {
		if (ok)
			return;
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.autoDownloadValues = [previousValues mutableCopy];
		[strongSelf.tableView reloadData];
		[TGSnackbar showInView:strongSelf.view
						   text:TGL(@"Toast.CouldNotChangeAutoDownloadSettings", @"Could not change auto-download settings")
						seconds:2
					   onCommit:nil];
	}];
}

- (NSInteger)autoDownloadKindRowsInSection:(NSInteger)section {
	if (section == 0)
		return 1;
	if (section == 1)
		return (NSInteger)[TGSettingsViewController autoDownloadKindKeys].count;
	if (section == 2)
		return (NSInteger)[TGSettingsViewController autoDownloadPreloadKeys].count;
	return 1;
}

- (NSString *)autoDownloadKindHeaderForSection:(NSInteger)section {
	if (section == 1)
		return TGL(@"AutoDownloadSettings.MediaTypes", @"TYPES OF MEDIA");
	if (section == 2)
		return TGL(@"AutoDownloadSettings.WhileLoading", @"While loading");
	return nil;
}

- (NSString *)autoDownloadKindFooterForSection:(NSInteger)section {
	if (section == 0)
		return TGL(@"AutoDownloadSettings.OffFooter", @"Off, nothing on this network arrives until you tap it.");
	if (section == 1)
		return TGL(@"AutoDownloadSettings.MediaTypesFooter",
			@"A ceiling per kind: anything larger waits for a tap. GIFs "
			@"travel as files, so they share that ceiling.");
	if (section == 2)
		return TGL(@"AutoDownloadSettings.WhileLoadingFooter",
			@"Larger videos start loading before you open them, the next "
			@"track queued after an audio file loads while you listen, and "
			@"the first frames of stories are fetched in advance.");
	return TGL(@"AutoDownloadSettings.PresetFooter", @"Telegram's own three presets, written onto this network only.");
}

- (UITableViewCell *)fillAutoDownloadKindCell:(UITableViewCell *)cell
										   at:(NSIndexPath *)path {
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.enabled = YES;
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	BOOL on = [self autoDownloadFlagForKey:@"enabled"];

	if (path.section == 0) {
		cell.textLabel.text = TGL(@"ChatSettings.AutoDownloadEnabled", @"Auto-Download Media");
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		UISwitch *toggle = [[UISwitch alloc] init];
		toggle.on = on;
		[toggle addTarget:self action:@selector(autoDownloadEnabledToggled:)
			forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
		return cell;
	}

	if (path.section == 1) {
		NSString *key = [TGSettingsViewController autoDownloadKindKeys][path.row];
		cell.textLabel.text = [TGSettingsViewController autoDownloadKindTitles][path.row];
		cell.textLabel.enabled = on;
		cell.detailTextLabel.text = [TGSettingsViewController
			autoDownloadLimitTitle:[self autoDownloadLimitForKey:key]];
		[self markDisclosure:cell];
		return cell;
	}

	if (path.section == 2) {
		NSString *key = [TGSettingsViewController autoDownloadPreloadKeys][path.row];
		cell.textLabel.text = [TGSettingsViewController autoDownloadPreloadTitles][path.row];
		cell.textLabel.enabled = on;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		UISwitch *toggle = [[UISwitch alloc] init];
		toggle.on = [self autoDownloadFlagForKey:key];
		toggle.enabled = on;
		toggle.tag = 100 + path.row;
		[toggle addTarget:self action:@selector(autoDownloadPreloadToggled:)
			forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
		return cell;
	}

	cell.textLabel.text = TGL(@"Settings.UseAPreset", @"Use a preset");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	[self markDisclosure:cell];
	return cell;
}

- (void)autoDownloadEnabledToggled:(UISwitch *)toggle {
	NSDictionary *previousValues = [self.autoDownloadValues copy];
	self.autoDownloadValues[@"enabled"] = @(toggle.on);
	[self commitAutoDownloadValuesFrom:previousValues];
}

- (void)autoDownloadPreloadToggled:(UISwitch *)toggle {
	NSArray *keys = [TGSettingsViewController autoDownloadPreloadKeys];
	NSInteger row = toggle.tag - 100;
	if (row < 0 || row >= (NSInteger)keys.count)
		return;
	NSDictionary *previousValues = [self.autoDownloadValues copy];
	self.autoDownloadValues[keys[row]] = @(toggle.on);
	[self commitAutoDownloadValuesFrom:previousValues];
}

- (void)tapAutoDownloadKind:(NSIndexPath *)path {
	if (path.section == 3) {
		NSInteger cancelIndex;
		UIActionSheet *sheet = [TGActionSheetIndexBuilder
					sheetWithTitle:[TGSettingsViewController
									   titleForNetworkKind:self.autoDownloadKind]
						  delegate:self
					   otherTitles:@[ TGL(@"AutoDownloadSettings.DataUsageLow", @"Low"),
						   TGL(@"PhotoEditor.QualityMedium", @"Medium"),
						   TGL(@"AutoDownloadSettings.DataUsageHigh", @"High") ]
				  destructiveIndex:-1
					   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
			destructiveButtonIndex:NULL
				 cancelButtonIndex:&cancelIndex];
		sheet.tag = 179;
		[self showSheet:sheet];
		return;
	}
	if (path.section != 1 || ![self autoDownloadFlagForKey:@"enabled"])
		return;
	NSString *key = [TGSettingsViewController autoDownloadKindKeys][path.row];

	NSMutableArray *titles = [NSMutableArray array];
	for (NSNumber *limit in [TGSettingsViewController autoDownloadLimitsForKey:key])
		[titles addObject:[TGSettingsViewController autoDownloadLimitTitle:limit.longLongValue]];
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:[TGSettingsViewController autoDownloadKindTitles][path.row]
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 170 + (NSInteger)[[TGSettingsViewController autoDownloadKindKeys] indexOfObject:key];
	[self showSheet:sheet];
}

- (void)applyAutoDownloadLimitFromSheet:(UIActionSheet *)sheet atIndex:(NSInteger)index {
	NSInteger row = sheet.tag - 170;
	NSArray *keys = [TGSettingsViewController autoDownloadKindKeys];
	if (row < 0 || row >= (NSInteger)keys.count)
		return;
	NSString *key = keys[row];
	NSArray *limits = [TGSettingsViewController autoDownloadLimitsForKey:key];
	if (index < 0 || index >= (NSInteger)limits.count)
		return;
	NSDictionary *previousValues = [self.autoDownloadValues copy];
	self.autoDownloadValues[key] = limits[index];
	[self commitAutoDownloadValuesFrom:previousValues];
}

- (void)applyAutoDownloadPresetFromSheetAtIndex:(NSInteger)index {
	NSArray *names = [TGSettingsViewController presetNames];
	if (index < 0 || index >= (NSInteger)names.count)
		return;
	__weak typeof(self) weakSelf = self;
	[TGSettingsService autoDownloadPresetNamed:names[index]
									completion:^(NSDictionary *preset) {
										__strong typeof(weakSelf) strongSelf = weakSelf;
										if (!strongSelf)
											return;
										if (![preset isKindOfClass:[NSDictionary class]])
											return;
										NSDictionary *previousValues = [strongSelf.autoDownloadValues copy];
										NSString *previousPresetName = [strongSelf presetNameForNetwork:strongSelf.autoDownloadKind];
										id calls = strongSelf.autoDownloadValues[@"useLessDataForCalls"];
										[strongSelf.autoDownloadValues addEntriesFromDictionary:preset];
										if (calls)
											strongSelf.autoDownloadValues[@"useLessDataForCalls"] = calls;
										[strongSelf rememberPreset:names[index] forNetwork:strongSelf.autoDownloadKind];
										[strongSelf.tableView reloadData];

										NSDictionary *values = strongSelf.autoDownloadValues;
										NSString *networkType = strongSelf.autoDownloadKind;
										[TGSettingsService setAutoDownloadSettings:values
																	forNetworkType:networkType
																		completion:^(BOOL ok) {
											if (ok)
												return;
											__strong typeof(weakSelf) innerSelf = weakSelf;
											if (!innerSelf)
												return;
											innerSelf.autoDownloadValues = [previousValues mutableCopy];
											[innerSelf rememberPreset:previousPresetName forNetwork:innerSelf.autoDownloadKind];
											[innerSelf.tableView reloadData];
											[TGSnackbar showInView:innerSelf.view
															   text:TGL(@"Toast.CouldNotChangeAutoDownloadSettings", @"Could not change auto-download settings")
															seconds:2
														   onCommit:nil];
										}];
									}];
}

- (UITableViewCell *)fillUsageCell:(UITableViewCell *)cell at:(NSIndexPath *)path {
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;

	if (path.section == TGSettingsUsageSectionTotal)
		return [self fillUsageTotalCell:cell at:path];

	if (path.section == TGSettingsUsageSectionMedia)
		return [self fillUsageMediaCell:cell at:path];

	if (path.section == TGSettingsUsageSectionCalls)
		return [self fillUsageCallsCell:cell at:path];

	cell.textLabel.text = TGL(@"NetworkUsageSettings.ResetStats", @"Reset statistics");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedDestructiveColour];
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

- (UITableViewCell *)fillUsageTotalCell:(UITableViewCell *)cell at:(NSIndexPath *)path {
	if (path.row == 0) {
		cell.textLabel.text = TGL(@"NetworkUsageSettings.BytesSent", @"Sent");
		cell.detailTextLabel.text = TGSettingsBytes(self.usageSent);
		return cell;
	}
	if (path.row == 1) {
		cell.textLabel.text = TGL(@"NetworkUsageSettings.BytesReceived", @"Received");
		cell.detailTextLabel.text = TGSettingsBytes(self.usageReceived);
		return cell;
	}
	NSInteger index = (NSUInteger)(path.row - 2);
	if (index >= self.usageNetworks.count)
		return cell;
	NSDictionary *entry = self.usageNetworks[index];
	cell.textLabel.text = [TGSettingsViewController
		usageNetworkTitle:entry[@"name"]];
	cell.detailTextLabel.text =
		TGSettingsBytes([entry[@"bytes"] longLongValue]);
	return cell;
}

- (UITableViewCell *)fillUsageMediaCell:(UITableViewCell *)cell at:(NSIndexPath *)path {
	if (!self.usageMedia.count) {
		cell.textLabel.text = TGL(@"Channel.NotificationLoading", @"Loading…");
		cell.textLabel.font = [UIFont systemFontOfSize:15];
		cell.textLabel.textColor = [[TGTheme shared] secondaryTextColour];
		return cell;
	}
	NSDictionary *entry = self.usageMedia[path.row];
	cell.textLabel.text = entry[@"title"];
	cell.detailTextLabel.text =
		TGSettingsBytes([entry[@"bytes"] longLongValue]);
	return cell;
}

- (UITableViewCell *)fillUsageCallsCell:(UITableViewCell *)cell at:(NSIndexPath *)path {
	if (path.row == 0) {
		cell.textLabel.text = TGL(@"NetworkUsageSettings.BytesSent", @"Sent");
		cell.detailTextLabel.text =
			TGSettingsBytes([self.usageCalls[@"sent"] longLongValue]);
	} else {
		cell.textLabel.text = TGL(@"NetworkUsageSettings.BytesReceived", @"Received");
		cell.detailTextLabel.text =
			TGSettingsBytes([self.usageCalls[@"received"] longLongValue]);
	}
	return cell;
}

- (UITableViewCell *)fillAutosaveCell:(UITableViewCell *)cell at:(NSIndexPath *)path {
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];

	if (path.section == 3)
		return [self fillAutosaveExceptionCell:cell at:path];

	if (path.section == 4) {
		cell.textLabel.text = TGL(@"Notifications.DeleteAllExceptions", @"Delete All Exceptions");
		cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
		cell.textLabel.textColor = [[TGTheme shared] groupedDestructiveColour];
		return cell;
	}

	NSString *scope = [TGSettingsViewController autosaveScopes][path.section];
	NSDictionary *settings = self.autosave[scope];
	cell.textLabel.text = path.row == 0 ? TGL(@"Cache.Photos", @"Photos") : TGL(@"Cache.Videos", @"Videos");
	UISwitch *toggle = [[UISwitch alloc] init];
	toggle.on = [settings[path.row == 0 ? @"photos" : @"videos"] boolValue];
	toggle.tag = path.section * 10 + path.row;
	[toggle addTarget:self action:@selector(autosaveToggled:)
		forControlEvents:UIControlEventValueChanged];
	cell.accessoryView = toggle;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

- (UITableViewCell *)fillAutosaveExceptionCell:(UITableViewCell *)cell
											at:(NSIndexPath *)path {
	if (!self.autosaveExceptions.count) {
		NSString *loading = TGL(@"Channel.NotificationLoading", @"Loading…");
		cell.textLabel.text = self.autosaveExceptionsLoaded ? TGL(@"Notifications.ExceptionsNone", @"No exceptions") : loading;
		cell.textLabel.textColor = [[TGTheme shared] secondaryTextColour];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}
	NSDictionary *entry = self.autosaveExceptions[path.row];
	if (![entry isKindOfClass:[NSDictionary class]])
		return cell;
	int64_t chatId = [entry[@"chatId"] longLongValue];
	NSString *title = self.chatTitles[@(chatId)];
	cell.textLabel.text = title.length ? title : TGL(@"ChatList.UnnamedChat", @"Chat");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	NSMutableArray *parts = [NSMutableArray array];
	if ([entry[@"photos"] boolValue])
		[parts addObject:TGL(@"Cache.Photos", @"Photos")];
	if ([entry[@"videos"] boolValue])
		[parts addObject:TGL(@"Cache.Videos", @"Videos")];
	cell.detailTextLabel.text = parts.count
		? [parts componentsJoinedByString:@", "]
		: TGL(@"Autosave.NothingSaved", @"Nothing saved");
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

+ (NSString *)kindOfBackground:(NSDictionary *)background {
	return TGWallpaperKindOfBackground(background);
}

+ (NSString *)colourWord:(NSDictionary *)background {
	return TGWallpaperColourWord(background);
}

+ (NSString *)titleForBackground:(NSDictionary *)background at:(NSInteger)index {
	return TGWallpaperTitleForBackground(background, index);
}

+ (NSString *)detailForBackground:(NSDictionary *)background {
	return TGWallpaperDetailForBackground(background);
}

- (UIImage *)swatchForBackground:(NSDictionary *)background size:(CGSize)size {
	NSNumber *top = background[@"topColor"];
	NSNumber *bottom = background[@"bottomColor"];
	if (![top isKindOfClass:[NSNumber class]])
		return nil;
	UIColor *topColour = TGColourFromHex((unsigned int)[top unsignedIntValue]);
	UIColor *bottomColour = [bottom isKindOfClass:[NSNumber class]]
		? TGColourFromHex((unsigned int)[bottom unsignedIntValue])
		: topColour;
	CGFloat rotation = [background[@"rotation"] isKindOfClass:[NSNumber class]]
		? [background[@"rotation"] floatValue]
		: 0.0f;

	UIGraphicsBeginImageContextWithOptions(size, YES, 1.0f);
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context) {
		UIGraphicsEndImageContext();
		return nil;
	}
	CGFloat locations[2] = {0.0f, 1.0f};
	NSArray *colours = @[ (id)topColour.CGColor, (id)bottomColour.CGColor ];
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGGradientRef gradient = CGGradientCreateWithColors(space,
		(__bridge CFArrayRef)colours, locations);
	if (gradient) {
		CGPoint startPoint, endPoint;
		TGWallpaperGradientPoints(rotation, size, &startPoint, &endPoint);
		CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
		CGGradientRelease(gradient);
	} else {
		CGContextSetFillColorWithColor(context, topColour.CGColor);
		CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
	}
	CGColorSpaceRelease(space);
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

- (UIImage *)compositePatternImage:(UIImage *)pattern
					overBackground:(NSDictionary *)background
							  size:(CGSize)size {
	UIImage *fill = [self swatchForBackground:background size:size];
	if (!pattern)
		return fill;
	if (!fill) {
		UIGraphicsBeginImageContextWithOptions(size, YES, 1.0f);
		CGContextRef context = UIGraphicsGetCurrentContext();
		if (context) {
			CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
			CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
			fill = UIGraphicsGetImageFromCurrentImageContext();
		}
		UIGraphicsEndImageContext();
	}

	NSInteger intensity = [background[@"intensity"] isKindOfClass:[NSNumber class]]
		? [background[@"intensity"] integerValue]
		: 50;
	BOOL inverted = [background[@"isInverted"] boolValue];
	return TGCompositeWallpaperPattern(fill, pattern, intensity, inverted) ?: fill;
}

+ (NSArray *)builtinWallpaperNames {
	return @[ TGL(@"WallpaperPreview.Pattern", @"Pattern"),
		TGL(@"Wallpaper.BuiltinBoards", @"Boards"),
		TGL(@"Wallpaper.BuiltinUmbrella", @"Umbrella"),
		TGL(@"Wallpaper.BuiltinSkyline", @"Skyline"),
		TGL(@"Wallpaper.BuiltinMountains", @"Mountains") ];
}

+ (NSString *)builtinWallpaperFileAtIndex:(NSInteger)index {
	return [NSString stringWithFormat:@"builtin-wallpaper-%d", (int)index];
}

- (UITableViewCell *)fillWallpaperCell:(UITableViewCell *)cell at:(NSIndexPath *)path {
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];

	if (path.section == 3) {
		[TGIcons actionButtonInCell:cell
							  title:TGL(@"Wallpaper.ResetWallpapers", @"Reset Chat Backgrounds")
							   kind:TGActionButtonKindDestructive
							 target:self
							 action:@selector(confirmClearBackgroundList)];
		return cell;
	}

	if (path.section == 0)
		return [self fillWallpaperChooserCell:cell at:path];

	if (path.section == 1)
		return [self fillBuiltinWallpaperCell:cell at:path];

	if (!self.backgrounds.count) {
		cell.textLabel.text = TGWallpaperListText(self.backgroundsLoaded, self.backgroundsFailed);
		cell.textLabel.font = [UIFont systemFontOfSize:15];
		cell.textLabel.textColor = [[TGTheme shared] secondaryTextColour];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}

	NSDictionary *background = self.backgrounds[path.row];
	if (![background isKindOfClass:[NSDictionary class]])
		return cell;
	cell.textLabel.text = [TGSettingsViewController
		titleForBackground:background
						at:[self ordinalOfBackgroundAtRow:path.row]];
	cell.detailTextLabel.text = [TGSettingsViewController detailForBackground:background];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	CGSize swatch = CGSizeMake(30, 30);
	cell.imageView.image = [self swatchForBackground:background size:swatch]
		?: [self blankSwatchOfSize:swatch];
	NSString *backgroundId = [background[@"id"] isKindOfClass:[NSString class]] ? background[@"id"] : nil;
	[self markChecked:self.wallpaperBackgroundId.length > 0 && [self.wallpaperBackgroundId isEqualToString:backgroundId]
					on:cell];
	return cell;
}

- (UITableViewCell *)fillBuiltinWallpaperCell:(UITableViewCell *)cell
										   at:(NSIndexPath *)path {
	NSArray *names = [TGSettingsViewController builtinWallpaperNames];
	if ((NSUInteger)path.row >= names.count)
		return cell;
	cell.textLabel.text = names[path.row];

	NSString *file = [TGSettingsViewController builtinWallpaperFileAtIndex:path.row];
	CGSize swatch = CGSizeMake(30, 30);
	UIImage *thumb = [UIImage imageNamed:
			[file stringByAppendingString:@"-thumbnail.jpg"]];
	cell.imageView.image = thumb
		? [self swatchFromImage:thumb size:swatch]
		: [self blankSwatchOfSize:swatch];

	[self markChecked:[[TGTheme shared].builtinWallpaperName isEqualToString:file]
				   on:cell];
	return cell;
}

- (UIImage *)swatchFromImage:(UIImage *)image size:(CGSize)size {
	if (!image)
		return nil;
	UIGraphicsBeginImageContextWithOptions(size, YES, 0.0f);
	CGFloat scale = MAX(size.width / image.size.width,
		size.height / image.size.height);
	CGSize drawn = CGSizeMake(image.size.width * scale, image.size.height * scale);
	[image drawInRect:CGRectMake((size.width - drawn.width) / 2.0f,
						  (size.height - drawn.height) / 2.0f, drawn.width, drawn.height)];
	UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return result;
}

- (NSInteger)ordinalOfBackgroundAtRow:(NSInteger)row {
	if ((NSUInteger)row >= self.backgrounds.count)
		return 0;
	NSString *kind = [TGSettingsViewController kindOfBackground:self.backgrounds[row]];
	NSInteger ordinal = 0;
	for (NSInteger index = 0; index < row; index++)
		if ([[TGSettingsViewController kindOfBackground:self.backgrounds[index]]
				isEqualToString:kind])
			ordinal++;
	return ordinal;
}

- (UIImage *)blankSwatchOfSize:(CGSize)size {
	static UIImage *cached = nil;
	if (cached && CGSizeEqualToSize(cached.size, size))
		return cached;
	UIGraphicsBeginImageContextWithOptions(size, YES, 1.0f);
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context) {
		UIGraphicsEndImageContext();
		return nil;
	}
	CGContextSetFillColorWithColor(context, TGColourFromHex(0xd6dae0).CGColor);
	CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
	CGContextSetStrokeColorWithColor(context, TGColourFromHex(0xb0b6be).CGColor);
	CGContextStrokeRect(context, CGRectMake(0.5f, 0.5f, size.width - 1, size.height - 1));
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	cached = image;
	return image;
}

- (UITableViewCell *)fillWallpaperChooserCell:(UITableViewCell *)cell
										   at:(NSIndexPath *)path {
	if (path.row == 0) {
		cell.textLabel.text = TGL(@"Wallpaper.SetCustomBackground", @"Choose from library");
		cell.detailTextLabel.text = [TGTheme shared].wallpaper ? TGL(@"Wallpaper.Set", @"Set") : TGL(@"Stickers.SuggestNone", @"None");
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		[self markDisclosure:cell];
		return cell;
	}
	if (path.row == 1) {
		cell.textLabel.text = TGL(@"Wallpaper.SetColor", @"Set a Color");
		[self markDisclosure:cell];
		return cell;
	}
	if (path.row == 2) {
		cell.textLabel.text = TGL(@"Wallpaper.Gradient", @"Gradient");
		[self markDisclosure:cell];
		return cell;
	}
	if (path.row == 3) {
		cell.textLabel.text = TGL(@"Story.Editor.Blur.Title", @"Blur");
		UISwitch *toggle = [[UISwitch alloc] init];
		toggle.on = self.wallpaperBlurred;
		[toggle addTarget:self action:@selector(wallpaperBlurToggled:)
			forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}
	[TGIcons actionButtonInCell:cell
						  title:TGL(@"Conversation.Theme.ResetWallpaper", @"Remove wallpaper")
						   kind:TGActionButtonKindDestructive
						 target:self
						 action:@selector(removeChatWallpaperPressed)];
	return cell;
}

+ (NSArray *)archiveKeys {
	static NSArray *keys = nil;
	if (!keys)
		keys = @[ @"archiveUnknownSenders", @"keepUnmutedArchived",
			@"keepFoldersArchived" ];
	return keys;
}

+ (NSArray *)archiveTitles {
	return @[ TGL(@"PrivacySettings.AutoArchive", @"Archive and mute new chats"),
		TGL(@"ArchiveSettings.KeepUnmuted", @"Unmuted Chats"),
		TGL(@"ArchiveSettings.KeepFolders", @"Chats from Folders") ];
}

- (UITableViewCell *)fillDataCell:(UITableViewCell *)cell at:(NSIndexPath *)indexPath {
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];

	if (indexPath.section == 0)
		return [self fillDataMainCell:cell at:indexPath];

	if (indexPath.section == 1)
		return [self fillDataPrivacyCell:cell at:indexPath];

	if (indexPath.section == 2)
		return [self fillArchiveCell:cell at:indexPath];

	[TGIcons actionButtonInCell:cell
						  title:TGL(@"Cache.ClearCache", @"Clear local database")
						   kind:TGActionButtonKindDestructive
						 target:self
						 action:@selector(confirmClearDatabase)];
	return cell;
}

- (UITableViewCell *)fillDataMainCell:(UITableViewCell *)cell
								   at:(NSIndexPath *)indexPath {
	if (indexPath.row == 0) {
		cell.textLabel.text = TGL(@"ChatSettings.Cache", @"Storage Usage");
		[self markDisclosure:cell];
		return cell;
	}
	if (indexPath.row == 1) {
		cell.textLabel.text = TGL(@"DataUsage.Header", @"Data Usage");
		[self markDisclosure:cell];
		return cell;
	}
	if (indexPath.row == 2) {
		cell.textLabel.text = TGL(@"ChatSettings.AutoDownloadEnabled", @"Auto-Download Media");
		[self markDisclosure:cell];
		return cell;
	}
	if (indexPath.row == 3) {
		cell.textLabel.text = TGL(@"Preview.SaveToCameraRoll", @"Save to Camera Roll");
		[self markDisclosure:cell];
		return cell;
	}
	if (indexPath.row == 4) {
		cell.textLabel.text = TGL(@"Settings.DeviceInformation", @"Device Information");
		[self markDisclosure:cell];
		return cell;
	}
	if (indexPath.row == 5) {
		cell.textLabel.text = TGL(@"WebBrowser.Title", @"Web Browser");
		[self markDisclosure:cell];
		return cell;
	}
	cell.textLabel.text = TGL(@"Settings.DataSaver", @"Data Saver");
	UISwitch *toggle = [[UISwitch alloc] init];
	toggle.on = self.dataSaver;
	[toggle addTarget:self action:@selector(dataSaverToggled:)
		forControlEvents:UIControlEventValueChanged];
	cell.accessoryView = toggle;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

- (UITableViewCell *)fillDataPrivacyCell:(UITableViewCell *)cell
									  at:(NSIndexPath *)indexPath {
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;

	if (indexPath.row == 3) {
		[TGIcons actionButtonInCell:cell
							  title:TGL(@"Privacy.ContactsReset", @"Delete Synced Contacts")
							   kind:TGActionButtonKindDestructive
							 target:self
							 action:@selector(confirmDeleteSyncedContacts)];
		return cell;
	}

	UISwitch *toggle = [[UISwitch alloc] init];
	cell.accessoryView = toggle;

	if (indexPath.row == 0) {
		cell.textLabel.text = TGL(@"Privacy.ContactsSync", @"Sync Contacts");
		toggle.on = [TGPreferenceFlags syncContactsEnabled];
		[toggle addTarget:self action:@selector(syncContactsToggled:)
			forControlEvents:UIControlEventValueChanged];
		return cell;
	}
	if (indexPath.row == 1) {
		cell.textLabel.text = TGL(@"Privacy.TopPeers", @"Suggest Frequent Contacts");
		toggle.on = !self.topChatsDisabled;
		toggle.enabled = self.topChatsLoaded;
		[toggle addTarget:self action:@selector(frequentContactsToggled:)
			forControlEvents:UIControlEventValueChanged];
		return cell;
	}
	cell.textLabel.text = TGL(@"Privacy.SecretChatsLinkPreviews", @"Secret Chat Link Previews");
	toggle.on = [TGPreferenceFlags secretChatLinkPreviewsEnabled];
	[toggle addTarget:self action:@selector(secretLinkPreviewsToggled:)
		forControlEvents:UIControlEventValueChanged];
	return cell;
}

- (void)syncContactsToggled:(UISwitch *)toggle {
	[TGPreferenceFlags setSyncContactsEnabled:toggle.on];
}

- (void)secretLinkPreviewsToggled:(UISwitch *)toggle {
	[TGPreferenceFlags setSecretChatLinkPreviewsEnabled:toggle.on];
}

- (void)frequentContactsToggled:(UISwitch *)toggle {
	self.topChatsDisabled = !toggle.on;
	[TGSettingsService setOptionNamed:TGSettingsTopChatsOption
								value:@(self.topChatsDisabled)
							isBoolean:YES];
}

- (UITableViewCell *)fillArchiveCell:(UITableViewCell *)cell
								  at:(NSIndexPath *)indexPath {
	NSString *key = [TGSettingsViewController archiveKeys][indexPath.row];
	cell.textLabel.text = [TGSettingsViewController archiveTitles][indexPath.row];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	UISwitch *toggle = [[UISwitch alloc] init];
	toggle.on = [self.archive[key] boolValue];
	toggle.tag = indexPath.row;
	[toggle addTarget:self action:@selector(archiveToggled:)
		forControlEvents:UIControlEventValueChanged];
	cell.accessoryView = toggle;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

- (void)dataSaverToggled:(UISwitch *)toggle {
	BOOL enabled = toggle.on;
	__weak typeof(self) weakSelf = self;
	[TGSettingsService setDataSaverEnabled:enabled completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[strongSelf.tableView reloadData];
			[TGSnackbar showInView:strongSelf.view
							  text:TGL(@"Toast.CouldNotChangeDataSaver", @"Could not change data saver")
						   seconds:2
						  onCommit:nil];
			return;
		}
		[strongSelf applyDataSaver:enabled];
	}];
}

- (void)applyDataSaver:(BOOL)on {
	self.dataSaver = on;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:on forKey:@"TGDataSaver"];

	__weak typeof(self) weakSelf = self;
	void (^reportFailure)(void) = ^{
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[TGSnackbar showInView:strongSelf.view
						   text:TGL(@"Toast.CouldNotChangeAutoDownloadSettings", @"Could not change auto-download settings")
						seconds:2
					   onCommit:nil];
	};

	if (on) {
		NSDictionary *current = [defaults objectForKey:TGSettingsPresetDefaultsKey];
		[defaults setObject:([current isKindOfClass:[NSDictionary class]] ? current : @{})
					 forKey:TGSettingsSavedPresetsKey];
		NSMutableDictionary *customSettings = [NSMutableDictionary dictionary];
		for (NSString *kind in [TGSettingsViewController networkKinds]) {
			NSString *name = ([current isKindOfClass:[NSDictionary class]] && [current[kind] isKindOfClass:[NSString class]])
				? current[kind]
				: nil;
			if (name)
				continue;
			NSDictionary *mirror = [TGSettingsService autoDownloadSettingsForNetworkType:kind];
			if ([mirror isKindOfClass:[NSDictionary class]] && mirror.count)
				customSettings[kind] = mirror;
		}
		[defaults setObject:customSettings forKey:TGSettingsSavedCustomSettingsKey];
		[defaults synchronize];
		for (NSString *kind in [TGSettingsViewController networkKinds])
			[self rememberPreset:@"low" forNetwork:kind];
		[TGSettingsService applyAutoDownloadPresetNamed:@"low"
										 toNetworkTypes:[TGSettingsViewController networkKinds]
											 completion:^(BOOL ok) {
			if (!ok)
				reportFailure();
		}];
		return;
	}

	NSDictionary *saved = [defaults objectForKey:TGSettingsSavedPresetsKey];
	NSDictionary *savedCustom = [defaults objectForKey:TGSettingsSavedCustomSettingsKey];
	[defaults synchronize];

	NSArray *kinds = [TGSettingsViewController networkKinds];
	if (!kinds.count)
		return;

	__block NSInteger remaining = (NSInteger)kinds.count;
	__block BOOL anyFailed = NO;
	void (^finishOne)(BOOL) = ^(BOOL ok) {
		if (!ok)
			anyFailed = YES;
		remaining--;
		if (remaining > 0)
			return;
		if (anyFailed)
			reportFailure();
	};

	for (NSString *kind in kinds) {
		NSDictionary *customSettings = ([savedCustom isKindOfClass:[NSDictionary class]] && [savedCustom[kind] isKindOfClass:[NSDictionary class]])
			? savedCustom[kind]
			: nil;
		if (customSettings) {
			[self rememberPreset:nil forNetwork:kind];
			[TGSettingsService setAutoDownloadSettings:customSettings
										 forNetworkType:kind
											 completion:finishOne];
			continue;
		}
		NSString *name = ([saved isKindOfClass:[NSDictionary class]] && [saved[kind] isKindOfClass:[NSString class]])
			? saved[kind]
			: @"high";
		[self rememberPreset:name forNetwork:kind];
		[TGSettingsService applyAutoDownloadPresetNamed:name
										 toNetworkTypes:@[ kind ]
											 completion:finishOne];
	}
}

- (void)archiveToggled:(UISwitch *)toggle {
	static NSDictionary *serverKeys = nil;
	if (!serverKeys)
		serverKeys = @{@"archiveUnknownSenders" : @"archiveAndMuteNewChatsFromUnknownUsers",
			@"keepUnmutedArchived" : @"keepUnmutedChatsArchived",
			@"keepFoldersArchived" : @"keepChatsFromFoldersArchived"};

	NSString *key = [TGSettingsViewController archiveKeys][toggle.tag];
	BOOL previous = [self.archive[key] boolValue];
	self.archive[key] = @(toggle.on);

	__weak typeof(self) weakSelf = self;
	void (^revert)(BOOL) = ^(BOOL ok) {
		if (ok)
			return;
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.archive[key] = @(previous);
		[strongSelf.tableView reloadData];
	};
	[TGSettingsService updateArchiveChatListSettings:@{serverKeys[key] : @(toggle.on)} completion:revert];
}

- (void)lessCallDataToggled:(UISwitch *)toggle {
	BOOL useLess = toggle.on;
	BOOL previous = self.lessCallData;
	self.lessCallData = useLess;
	[[NSUserDefaults standardUserDefaults] setBool:useLess
											forKey:TGSettingsLessCallDataKey];
	[[NSUserDefaults standardUserDefaults] synchronize];

	__weak typeof(self) weakSelf = self;
	[self writeLessCallData:useLess completion:^(BOOL ok) {
		if (ok)
			return;
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.lessCallData = previous;
		[[NSUserDefaults standardUserDefaults] setBool:previous
												forKey:TGSettingsLessCallDataKey];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[strongSelf.tableView reloadData];
		[TGSnackbar showInView:strongSelf.view
						   text:TGL(@"Toast.CouldNotChangeAutoDownloadSettings", @"Could not change auto-download settings")
						seconds:2
					   onCommit:nil];
	}];
}

- (void)writeLessCallData:(BOOL)useLess completion:(void (^)(BOOL ok))completion {
	NSArray *kinds = @[ @"wifi", @"mobile", @"roaming", @"other" ];
	NSMutableArray *mirroredKinds = [NSMutableArray array];
	NSMutableArray *mirroredValues = [NSMutableArray array];
	NSMutableArray *unmirrored = [NSMutableArray array];
	for (NSString *kind in kinds) {
		NSDictionary *mirror = [TGSettingsService autoDownloadSettingsForNetworkType:kind];
		if (![mirror isKindOfClass:[NSDictionary class]] || !mirror.count) {
			[unmirrored addObject:kind];
			continue;
		}
		NSMutableDictionary *values = [mirror mutableCopy];
		values[@"useLessDataForCalls"] = @(useLess);
		[mirroredKinds addObject:kind];
		[mirroredValues addObject:values];
	}

	__block NSInteger remaining = (NSInteger)(mirroredKinds.count + (unmirrored.count ? 1 : 0));
	__block BOOL anyFailed = NO;
	void (^finishOne)(BOOL) = ^(BOOL ok) {
		if (!ok)
			anyFailed = YES;
		remaining--;
		if (remaining > 0)
			return;
		if (completion)
			completion(!anyFailed);
	};

	if (!remaining) {
		if (completion)
			completion(YES);
		return;
	}

	for (NSUInteger i = 0; i < mirroredKinds.count; i++) {
		[TGSettingsService setAutoDownloadSettings:mirroredValues[i]
									 forNetworkType:mirroredKinds[i]
										 completion:finishOne];
	}

	if (!unmirrored.count)
		return;

	[TGSettingsService autoDownloadPresetNamed:@"medium"
									completion:^(NSDictionary *preset) {
										if (![preset isKindOfClass:[NSDictionary class]]) {
											finishOne(NO);
											return;
										}
										NSMutableDictionary *values = [preset mutableCopy];
										values[@"useLessDataForCalls"] = @(useLess);
										__block NSInteger unmirroredRemaining = (NSInteger)unmirrored.count;
										__block BOOL anyUnmirroredFailed = NO;
										for (NSString *kind in unmirrored) {
											[TGSettingsService setAutoDownloadSettings:values
																		 forNetworkType:kind
																			 completion:^(BOOL innerOk) {
												if (!innerOk)
													anyUnmirroredFailed = YES;
												unmirroredRemaining--;
												if (unmirroredRemaining > 0)
													return;
												finishOne(!anyUnmirroredFailed);
											}];
										}
									}];
}

- (void)autosaveToggled:(UISwitch *)toggle {
	NSInteger section = toggle.tag / 10;
	NSInteger row = toggle.tag % 10;
	if ((NSUInteger)section >= [TGSettingsViewController autosaveScopes].count)
		return;
	NSString *scope = [TGSettingsViewController autosaveScopes][section];
	NSDictionary *settings = self.autosave[scope];

	BOOL photos = [settings[@"photos"] boolValue];
	BOOL videos = [settings[@"videos"] boolValue];
	long long maxVideo = [settings[@"maxVideoBytes"] longLongValue];
	if (maxVideo <= 0)
		maxVideo = 10 * 1024 * 1024;
	if (row == 0)
		photos = toggle.on;
	else
		videos = toggle.on;

	NSDictionary *previousSettings = self.autosave[scope];
	self.autosave[scope] = @{@"photos" : @(photos),
		@"videos" : @(videos),
		@"maxVideoBytes" : @(maxVideo)};

	__weak typeof(self) weakSelf = self;
	[TGSettingsService setAutosavePhotos:photos
								  videos:videos
						   maxVideoBytes:maxVideo
								forScope:scope
							  completion:^(BOOL ok) {
		if (ok)
			return;
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (previousSettings)
			strongSelf.autosave[scope] = previousSettings;
		else
			[strongSelf.autosave removeObjectForKey:scope];
		[strongSelf.tableView reloadData];
		[TGSnackbar showInView:strongSelf.view
						   text:TGL(@"Toast.CouldNotChangeAutosave", @"Could not change autosave settings")
						seconds:2
					   onCommit:nil];
	}];
}

@end
