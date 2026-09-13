#import "TGHiddenStoriesCellCatalogue.h"
#import "TGHiddenStoriesPosterCell.h"

@implementation TGHiddenStoriesCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGHiddenStoriesRowKind)kind {
	switch (kind) {
		case TGHiddenStoriesRowKindPoster:
			return @"TGHiddenStoriesRow.Poster";
	}
	return nil;
}

+ (Class)cellClassForKind:(TGHiddenStoriesRowKind)kind {
	switch (kind) {
		case TGHiddenStoriesRowKindPoster:
			return [TGHiddenStoriesPosterCell class];
	}
	return nil;
}

@end
