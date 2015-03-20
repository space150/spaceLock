//
//  SLSecurityManager.m
//  spacelab
//
//  Created by Shawn Roske on 3/20/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

#import "SLSecurityManager.h"
#import <CommonCrypto/CommonCrypto.h>
#import "NSData+Conversion.h"

@implementation SLSecurityManager

- (NSData *)encryptString:(NSString *)text
{
    char key[] = { 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44,
        0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44 };
    
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger dataLength = [data length];
    //NSLog(@"data: %@", data);
    
    char ivPtr[kCCBlockSizeAES128 + 1];
    bzero(ivPtr, sizeof(ivPtr));
    
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt,
                                          kCCAlgorithmAES128,
                                          kCCOptionPKCS7Padding | kCCOptionECBMode,
                                          key,
                                          kCCBlockSizeAES128,
                                          ivPtr,
                                          [data bytes],
                                          dataLength,
                                          buffer,
                                          bufferSize,
                                          &numBytesEncrypted);
    
    NSData *resultData = nil;
    if (cryptStatus == kCCSuccess) {
        resultData = [NSData dataWithBytes:buffer length:numBytesEncrypted];
    }
    
    free(buffer);
    
    //NSLog(@"encrypted: %@", resultData);
    
    return resultData;
}

@end
