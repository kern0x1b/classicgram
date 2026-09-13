#import "TGStorageDownloadsCellBase.h"
#import "TGStorageDownloadsItem.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGHexColour.h"

@implementation TGStorageDownloadsCellBase

- (void)applyItem:(TGStorageDownloadsItem *)item {
	self.accessoryView = nil;
	self.accessoryType = UITableViewCellAccessoryNone;
	self.selectionStyle = UITableViewCellSelectionStyleNone;

	self.textLabel.font = [UIFont boldSystemFontOfSize:17];
	self.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	self.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	self.textLabel.highlightedTextColor = [UIColor whiteColor];
	self.textLabel.text = item.titleText;

	self.detailTextLabel.font = [UIFont systemFontOfSize:16];
	self.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	self.detailTextLabel.highlightedTextColor = [UIColor whiteColor];
	self.detailTextLabel.text = item.detailText ?: @"";

	switch (item.kind) {
		case TGStorageDownloadsRowKindClear:
			self.textLabel.textAlignment = NSTextAlignmentCenter;
			self.textLabel.textColor = [[TGTheme shared] groupedDestructiveColour];
			self.selectionStyle = UITableViewCellSelectionStyleBlue;
			break;
		case TGStorageDownloadsRowKindLoading: {
			self.textLabel.textColor = [[TGTheme shared] groupedDisabledColour];
			UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
				initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			[spinner startAnimating];
			self.accessoryView = spinner;
			break;
		}
		case TGStorageDownloadsRowKindEmpty:
			self.textLabel.textColor = [[TGTheme shared] groupedDisabledColour];
			break;
		case TGStorageDownloadsRowKindMore:
			self.textLabel.textColor = [[TGTheme shared] groupedActionColour];
			self.selectionStyle = UITableViewCellSelectionStyleBlue;
			break;
		case TGStorageDownloadsRowKindEntry:
			self.selectionStyle = UITableViewCellSelectionStyleBlue;
			break;
	}
}

@end
