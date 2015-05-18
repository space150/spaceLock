//
//  LKSecurityManager.m
//  spacelab
//
//  Created by Shawn Roske on 3/31/15.
//  Copyright (c) 2015 space150, Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
//  associated documentation files (the "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
//  following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial
//  portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
//  LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
//  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
//  THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "LKSecurityManager.h"
#import <CommonCrypto/CommonCrypto.h>
#import "NSData+Conversion.h"

#define kCryptoErrorDomain @"LKSecurityManager"

@interface LKSecurityManager ()

@end

@implementation LKSecurityManager
- (NSData *)generateNewKeyForLockName:(NSString *)lockName
{
    // generate key
    NSMutableData* newKey = [NSMutableData dataWithCapacity:kCCBlockSizeAES128];
    for( unsigned int i = 0 ; i < kCCBlockSizeAES128; i++ )
    {
        u_int32_t byte = arc4random();
        [newKey appendBytes:(void*)&byte length:1];
    }
    
    return newKey;    
}

- (NSData *)encryptString:(NSString *)text withKey:(NSData *)keyData
{
    NSData *input = [text dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSData *output = [self cryptoOperation:kCCEncrypt key:keyData input:input error:&error];
    if ( output == nil )
    {
        NSLog(@"Unable to encrypt string: %@", [error localizedDescription]);
        return nil;
    }
    return output;
}

- (NSString *)decryptData:(NSData *)input withKey:(NSData *)keyData
{
    NSError *error = nil;
    NSData *output = [self cryptoOperation:kCCDecrypt key:keyData input:input error:&error];
    if ( output == nil )
    {
        NSLog(@"Unable to decrypt string: %@", [error localizedDescription]);
        return nil;
    }
    
    return [NSString stringWithUTF8String:[output bytes]];
}

- (NSData *)cryptoOperation:(CCOperation)operation
                        key:(NSData *)key
                      input:(NSData *)input
                      error:(NSError **)error
{
    size_t outLength;
    NSMutableData *output = [NSMutableData dataWithLength:input.length + kCCBlockSizeAES128];
    
    CCCryptorStatus result = CCCrypt(operation,             // operation
                                     kCCAlgorithmAES128,    // Algorithm
                                     kCCOptionPKCS7Padding | kCCOptionECBMode, // options
                                     key.bytes,             // key
                                     kCCBlockSizeAES128,//key.length,            // keylength
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

