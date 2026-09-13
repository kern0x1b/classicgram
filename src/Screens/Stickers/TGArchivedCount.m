#import "TGArchivedCount.h"

NSInteger TGArchivedCount(NSInteger reportedTotal, NSUInteger received, NSInteger limit) {
	if (limit > 0 && (NSInteger)received < limit)
		return (NSInteger)received;
	if (reportedTotal > (NSInteger)received)
		return reportedTotal;
	return (NSInteger)received;
}
