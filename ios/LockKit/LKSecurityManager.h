//
//  LKSecurityManager.h
//  spacelab
//
//  Created by Shawn Roske on 3/31/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LKSecurityManager : NSObject

- (NSData *)encryptString:(NSString *)text;
- (NSString *)decryptData:(NSData *)input;

@end