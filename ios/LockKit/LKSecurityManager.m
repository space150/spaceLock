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

@interface LKSecurityManager ()

@property (nonatomic, retain) NSDictionary *keys;

@end

@implementation LKSecurityManager

//const char privateKey[] = { 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44,
//    0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44 };

- (id)init
{
    self = [super init];
    if ( self != nil )
    {
        [self loadKeysFromStore];
    }
    return self;
}

- (void)loadKeysFromStore
{
    self.keys = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Default-Keychain" ofType:@"plist"]];
}

- (void)generateKeyForLockName:(NSString *)lockName
{
    NSMutableDictionary *entry = (NSMutableDictionary *)[[self.keys objectForKey:lockName] mutableCopy];
    if ( entry != nil )
    {
        // generate key
        NSMutableData* newKey = [NSMutableData dataWithCapacity:kCCBlockSizeAES128];
        for( unsigned int i = 0 ; i < kCCBlockSizeAES128; i++ )
        {
            u_int32_t byte = arc4random();
            [newKey appendBytes:(void*)&byte length:1];
        }
        
        // set the newly generated key
        [entry setValue:newKey forKey:@"key"];
//        [entry setValue:[newKey hexadecimalString] forKey:@"keyHex"];
        
        NSMutableDictionary *keys = [self.keys mutableCopy];
        [keys setValue:entry forKey:lockName];
        
        // save it
        NSError *error;
        NSString *localizedPath = [[NSBundle mainBundle] pathForResource:@"Default-Keychain" ofType:@"plist"];
        NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:keys format:NSPropertyListXMLFormat_v1_0  options:0 error:&error];
        if (xmlData)
        {
            [xmlData writeToFile:localizedPath atomically:YES];
            NSLog(@"wrote new plist data to: %@", localizedPath);
        }
        else
        {
            NSLog(@"Error writing plist to file '%@', error = '%@'", localizedPath, [error localizedDescription]);
        }
        NSLog(@"wrote new plist data to: %@", localizedPath);
        
        [self loadKeysFromStore];
        
        // create the handshake and output to console
        NSData *handshake = [self encryptString:lockName forLockName:lockName];
        NSLog(@"%@ has a new key: %@", lockName, [newKey hexadecimalString]);
        NSLog(@"handshake: %@", [handshake hexadecimalString]);
    }
    else
    {
        NSLog(@"Error - unable to find a keychain entry for lockName: %@", lockName);
    }

}


- (NSData *)encryptString:(NSString *)text forLockName:(NSString *)lockName
{
    NSDictionary *keyEntry = [self.keys objectForKey:lockName];
    if ( keyEntry != nil )
    {
        NSData *keyData = (NSData *)[keyEntry objectForKey:@"key"];
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
    else
    {
        NSLog(@"unable to encrypt, could not find keychain entry for lockName: %@", lockName);
    }
    return nil;
}

- (NSString *)decryptData:(NSData *)input forLockName:(NSString *)lockName
{
    NSDictionary *keyEntry = [self.keys objectForKey:lockName];
    if ( keyEntry != nil )
    {
        NSData *keyData = (NSData *)[keyEntry objectForKey:@"key"];
        NSError *error = nil;
        NSData *output = [self cryptoOperation:kCCDecrypt key:keyData input:input error:&error];
        if ( output == nil )
        {
            NSLog(@"Unable to descrypt string: %@", [error localizedDescription]);
            return nil;
        }
        
        return [NSString stringWithUTF8String:[output bytes]];
    }
    else
    {
        NSLog(@"unable to decrypt, could not find keychain entry for lockName: %@", lockName);
    }
    return nil;
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

