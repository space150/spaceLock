//
//  LKLock.m
//  spacelab
//
//  Created by Shawn Roske on 4/1/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

#import "LKLock.h"


@implementation LKLock

@dynamic lastActionAt;
@dynamic name;
@dynamic lockId;
@dynamic icon;
@dynamic uuid;
@dynamic proximity;
@dynamic proximityString;

- (LKLockProximity)proximityEnum
{
    return (LKLockProximity)[self.proximity intValue];
}

@end
