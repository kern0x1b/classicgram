#import "TGStoryViewersCellCatalogue.h"
#import "TGStoryViewerRowCell.h"

@implementation TGStoryViewersCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGStoryViewersRowKind)kind {
	switch (kind) {
		case TGStoryViewersRowKindViewer:
			return @"TGStoryViewersRow.Viewer";
	}
	return nil;
}

+ (Class)cellClassForKind:(TGStoryViewersRowKind)kind {
	switch (kind) {
		case TGStoryViewersRowKindViewer:
			return [TGStoryViewerRowCell class];
	}
	return nil;
}

@end
