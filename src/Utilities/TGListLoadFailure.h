#import <Foundation/Foundation.h>

typedef enum {
	TGListStatusRows = 0,
	TGListStatusLoading,
	TGListStatusFailed,
	TGListStatusEmpty
} TGListStatus;

BOOL TGListShowsLoadFailureNotice(BOOL failed, NSUInteger loadedRowCount);

TGListStatus TGListStatusOfList(BOOL loaded, BOOL failed, NSUInteger loadedRowCount);
