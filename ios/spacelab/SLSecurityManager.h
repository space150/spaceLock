//
//  SLSecurityManager.h
//  spacelab
//
//  Created by Shawn Roske on 3/20/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SLSecurityManager : NSObject

- (NSData *)encryptString:(NSString *)text;
- (NSString *)decryptData:(NSData *)input;

@end
