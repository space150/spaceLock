//
//  LKKey.h
//  spacelab
//
//  Created by Shawn Roske on 5/18/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface LKKey : NSManagedObject

@property (nonatomic, retain) NSString * lockId;
@property (nonatomic, retain) NSString * lockName;
@property (nonatomic, retain) NSString * imageFilename;

@end
