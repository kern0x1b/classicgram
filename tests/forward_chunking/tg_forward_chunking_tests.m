#import "tg_forward_chunking_tests.h"
#import "../../src/Screens/Chat/TGForwardChunking.h"

static NSArray *TGForwardChunkingTestIds(NSUInteger count) {
	NSMutableArray *ids = [NSMutableArray array];
	for (NSUInteger i = 0; i < count; i++)
		[ids addObject:@(i + 1)];
	return ids;
}

TGTestOutcome TGForwardChunkingTestEmptyIdsProducesNoChunks(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *chunks = TGChunkedForwardMessageIds(@[], TGForwardMessagesMaxChunkSize);
	TGTestExpectEqualInteger(&outcome, chunks.count, 0, "an empty selection must produce no chunks at all");

	return outcome;
}

TGTestOutcome TGForwardChunkingTestFewerIdsThanChunkSizeProducesOneChunk(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *ids = TGForwardChunkingTestIds(5);
	NSArray *chunks = TGChunkedForwardMessageIds(ids, TGForwardMessagesMaxChunkSize);
	TGTestExpectEqualInteger(&outcome, chunks.count, 1, "a selection under the chunk size must fit in a single call");
	TGTestExpectTrue(&outcome, [chunks.firstObject isEqualToArray:ids],
			"the single chunk must contain every id, in order");

	return outcome;
}

TGTestOutcome TGForwardChunkingTestExactMultipleOfChunkSizeProducesEvenChunks(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *ids = TGForwardChunkingTestIds(200);
	NSArray *chunks = TGChunkedForwardMessageIds(ids, 100);
	TGTestExpectEqualInteger(&outcome, chunks.count, 2, "200 ids at a chunk size of 100 must split into exactly two chunks");
	TGTestExpectEqualInteger(&outcome, [chunks[0] count], 100, "the first chunk must be full");
	TGTestExpectEqualInteger(&outcome, [chunks[1] count], 100, "the second chunk must be full");

	return outcome;
}

TGTestOutcome TGForwardChunkingTestRemainderProducesASmallerFinalChunk(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *ids = TGForwardChunkingTestIds(250);
	NSArray *chunks = TGChunkedForwardMessageIds(ids, 100);
	TGTestExpectEqualInteger(&outcome, chunks.count, 3, "250 ids at a chunk size of 100 must need three calls");
	TGTestExpectEqualInteger(&outcome, [chunks[0] count], 100, "the first chunk must be full");
	TGTestExpectEqualInteger(&outcome, [chunks[1] count], 100, "the second chunk must be full");
	TGTestExpectEqualInteger(&outcome, [chunks[2] count], 50, "the trailing chunk must hold only the remainder");

	return outcome;
}

TGTestOutcome TGForwardChunkingTestChunksStayInAscendingOrder(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *ids = TGForwardChunkingTestIds(150);
	NSArray *chunks = TGChunkedForwardMessageIds(ids, 100);
	TGTestExpectEqualLongLong(&outcome, [chunks[0][0] longLongValue], 1,
			"the first chunk must start at the lowest id");
	TGTestExpectEqualLongLong(&outcome, [[chunks[0] lastObject] longLongValue], 100,
			"the first chunk must end just before the second chunk begins");
	TGTestExpectEqualLongLong(&outcome, [chunks[1][0] longLongValue], 101,
			"the second chunk must continue immediately where the first left off");
	TGTestExpectEqualLongLong(&outcome, [[chunks[1] lastObject] longLongValue], 150,
			"the second chunk must end at the highest id");

	return outcome;
}

TGTestOutcome TGForwardChunkingTestZeroChunkSizeProducesNoChunks(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *ids = TGForwardChunkingTestIds(10);
	NSArray *chunks = TGChunkedForwardMessageIds(ids, 0);
	TGTestExpectEqualInteger(&outcome, chunks.count, 0, "a zero chunk size must not infinite-loop or fabricate a chunk");

	return outcome;
}
