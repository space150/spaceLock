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
#define kSecServiceName @"com.s150.spacelab.spaceLock"

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

- (NSError *)saveKey:(NSString *)keyName key:(NSData *)keyData
{
    const id keys[] = {
        (__bridge id)(kSecClass),
        (__bridge id)(kSecAttrGeneric),
        (__bridge id)(kSecAttrAccount),
        (__bridge id)(kSecAttrService),
        (__bridge id)(kSecValueData),
        (__bridge id)(kSecAttrAccessible)
    };
    
    //NSString *bundleSeedID = [self bundleSeedID];
    NSData *encKeyName = [keyName dataUsingEncoding:NSUTF8StringEncoding];
    const id values[] = {
        (__bridge id)(kSecClassGenericPassword),
        encKeyName,
        encKeyName,
        kSecServiceName,
        keyData,
        (__bridge id)(kSecAttrAccessibleAfterFirstUnlock)
    };
    
    NSDictionary *attributes = [[NSDictionary alloc] initWithObjects:values forKeys:keys count:6];
    CFTypeRef result;
    
    NSLog(@"attributes: %@", attributes);
    
    NSError* error = nil;
    OSStatus osStatus = SecItemAdd((__bridge CFDictionaryRef)attributes, &result);
    if ( osStatus != noErr )
    {
        error = [[NSError alloc] initWithDomain:kCryptoErrorDomain code:osStatus userInfo:nil];
        NSLog(@"Adding key to keychain failed with OSError %d:%@", (int)osStatus, error);
        
        if ( osStatus == errSecDuplicateItem )
            NSLog(@"Item already exists in the keychain!");
        
        return error;
    }
    return nil;
}

- (NSData *)findKey:(NSString *)keyName
{
    const id keys[] = {
        (__bridge id)(kSecClass),
        (__bridge id)(kSecAttrGeneric),
        (__bridge id)(kSecAttrAccount),
        (__bridge id)(kSecAttrService),
        (__bridge id)(kSecReturnData)
    };
    
    NSData *encKeyName = [keyName dataUsingEncoding:NSUTF8StringEncoding];
    const id values[] = {
        (__bridge id)(kSecClassGenericPassword),
        encKeyName,
        encKeyName,
        kSecServiceName,
        (id)kCFBooleanTrue
    };
    NSDictionary* query = [[NSDictionary alloc] initWithObjects:values forKeys:keys count:5];
    CFTypeRef result;
    
    NSError* error = nil;
    OSStatus osStatus = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if ((osStatus == noErr) && (result != nil) )
    {
        NSData *keyData = (__bridge NSData *)result;
        return keyData;
    }
    else
    {
        error = [[NSError alloc] initWithDomain:kCryptoErrorDomain code:osStatus userInfo:nil];
        NSLog(@"Getting data of key with account \"%@\" from keychain failed with OSError %d: %@.", keyName, (int) osStatus, error);
        
        if ( osStatus == errSecItemNotFound )
            NSLog(@"Item does not exist in keychain");
    }
    
    return nil;
}

- (NSError *)deleteKey:(id)keyName
{
    const id keys[] = {
        (__bridge id)(kSecClass),
        (__bridge id)(kSecAttrGeneric),
        (__bridge id)(kSecAttrAccount),
        (__bridge id)(kSecAttrService)
    };
    
    NSData *encKeyName = [keyName dataUsingEncoding:NSUTF8StringEncoding];
    const id values[] = {
        (__bridge id)(kSecClassGenericPassword),
        encKeyName,
        encKeyName,
        kSecServiceName
    };
    
    NSDictionary* query = [[NSDictionary alloc] initWithObjects:values forKeys:keys count:4];
    
    NSError* error = nil;
    OSStatus osStatus = SecItemDelete((__bridge CFDictionaryRef)query);
    if (osStatus != noErr)
    {
        error = [[NSError alloc] initWithDomain:kCryptoErrorDomain code:osStatus userInfo:nil];
        NSLog(@"Deleting key with account \"%@\" from keychain failed with OSError %d: %@.", keyName, (int)osStatus, error);
        return error;
    }
    return nil;
}

@end

