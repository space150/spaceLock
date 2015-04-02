//
//  LKSecurityManager.m
//  spacelab
//
//  Created by Shawn Roske on 3/31/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

#import "LKSecurityManager.h"
#import <CommonCrypto/CommonCrypto.h>
#import "NSData+Conversion.h"

#define kCryptoErrorDomain @"LKSecurityManager"

@implementation LKSecurityManager

const char privateKey[] = { 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44,
    0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44 };

- (NSData *)encryptString:(NSString *)text
{
    NSData *input = [text dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *error = nil;
    NSData *output = [self cryptoOperation:kCCEncrypt input:input error:&error];
    if ( output == nil )
    {
        NSLog(@"Unable to encrypt string: %@", [error localizedDescription]);
        return nil;
    }
    
    return output;
}

- (NSString *)decryptData:(NSData *)input
{
    NSError *error = nil;
    NSData *output = [self cryptoOperation:kCCDecrypt input:input error:&error];
    if ( output == nil )
    {
        NSLog(@"Unable to descrypt string: %@", [error localizedDescription]);
        return nil;
    }
    
    return [NSString stringWithUTF8String:[output bytes]];
}

- (NSData *)cryptoOperation:(CCOperation)operation
                      input:(NSData *)input
                      error:(NSError **)error
{
    size_t outLength;
    NSMutableData *output = [NSMutableData dataWithLength:input.length + kCCBlockSizeAES128];
    
    CCCryptorStatus result = CCCrypt(operation,             // operation
                                     kCCAlgorithmAES128,    // Algorithm
                                     kCCOptionPKCS7Padding | kCCOptionECBMode, // options
                                     privateKey,            // key
                                     kCCBlockSizeAES128,    // keylength
                                     nil,                   // iv
                                     input.bytes,           // dataIn
                                     input.length,          // dataInLength,
                                     output.mutableBytes,   // dataOut
                                     output.length,         // dataOutAvailable
                                     &outLength);           // dataOutMoved
    
    if (result == kCCSuccess)
    {
        output.length = outLength;
    }
    else
    {
        *error = [NSError errorWithDomain:kCryptoErrorDomain code:result userInfo:nil];
        return nil;
    }
    
    return output;
}

@end

