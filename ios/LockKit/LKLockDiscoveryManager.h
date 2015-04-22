//
//  LKLockDiscoveryManager.h
//  spacelab
//
//  Created by Shawn Roske on 3/30/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

#import "RFduinoDelegate.h"
#import "RFduinoManagerDelegate.h"

@class RFduinoManager;
@class RFduino;
@class LKLock;

@interface LKLockDiscoveryManager : NSObject <RFduinoManagerDelegate, RFduinoDelegate>
{
    // nothing
}

@property (nonatomic, strong) RFduinoManager *rfduinoManager;

- (id)initWithContext:(NSString *)context;
- (void)startDiscovery;
- (void)stopDiscovery;
- (void)openLock:(LKLock *)lock complete:(void (^)(bool success, NSError *error))completionCallback;
- (void)openLockWithId:(NSString *)lockId complete:(void (^)(bool success, NSError *error))completionCallback;

@end
