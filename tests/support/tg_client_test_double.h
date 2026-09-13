#ifndef TG_HOST_TESTS_CLIENT_TEST_DOUBLE_H
#define TG_HOST_TESTS_CLIENT_TEST_DOUBLE_H

#import "TGClient+Private.h"

@interface TGClient (HostTestDouble)
@property (nonatomic, assign) NSInteger tgTestSaveCachedChatsCallCount;
@property (nonatomic, assign) NSInteger tgTestResetForAccountSwitchCallCount;
@property (nonatomic, assign) NSInteger tgTestResumeFromBackgroundCallCount;
@property (nonatomic, assign) NSInteger tgTestLogOutCallCount;
@end

#endif
