#ifndef TG_HOST_TESTS_ACCOUNT_MANAGER_TESTING_H
#define TG_HOST_TESTS_ACCOUNT_MANAGER_TESTING_H

#import "TGAccountManager.h"

@interface TGAccountManager ()
@property (nonatomic, strong) NSMutableArray *records;
@property (nonatomic, assign) NSInteger currentSlot;
@property (nonatomic, assign) BOOL switching;
@property (nonatomic, assign) BOOL addingAccount;
@property (nonatomic, assign) NSInteger slotBeforeAdding;
@property (nonatomic, assign) NSInteger slotAwaitingSignOut;
@property (nonatomic, assign) NSInteger slotToResumeAfterSignOut;
@property (nonatomic, copy) NSString *scopeToDiscardAfterSwitch;
@end

#endif
