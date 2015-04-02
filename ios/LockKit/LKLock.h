//
//  LKLock.h
//  spacelab
//
//  Created by Shawn Roske on 4/1/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface LKLock : NSManagedObject

@property (nonatomic, retain) NSDate * lastActionAt;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * uuid;
@property (nonatomic, retain) NSNumber * proximity;
@property (nonatomic, retain) NSString * proximityString;

@end
