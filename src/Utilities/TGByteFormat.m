#import "TGByteFormat.h"
#import "TGLocalization.h"
#import <math.h>

NSString *TGMediaFormatBytes(long long bytes) {
	if (bytes < 1024)
		return [NSString stringWithFormat:TGL(@"FileSize.B", @"%@ B"),
			[NSString stringWithFormat:@"%lld", bytes]];

	double kb = bytes / 1024.0;
	double roundedKb = round(kb);
	if (roundedKb < 1024.0)
		return [NSString stringWithFormat:TGL(@"FileSize.KB", @"%@ KB"),
			[NSString stringWithFormat:@"%.0f", roundedKb]];

	double mb = bytes / (1024.0 * 1024.0);
	double roundedMb = round(mb * 10.0) / 10.0;
	if (roundedMb < 1024.0)
		return [NSString stringWithFormat:TGL(@"FileSize.MB", @"%@ MB"),
			[NSString stringWithFormat:@"%.1f", roundedMb]];

	double gb = bytes / (1024.0 * 1024.0 * 1024.0);
	return [NSString stringWithFormat:TGL(@"FileSize.GB", @"%@ GB"),
		[NSString stringWithFormat:@"%.2f", gb]];
}
