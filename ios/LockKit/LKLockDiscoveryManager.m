//
//  LKLockDiscoveryManager.m
//  spacelab
//
//  Created by Shawn Roske on 3/30/15.
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

#import "LKLockDiscoveryManager.h"

#import "LKSecurityManager.h"
#import "LKLockRepository.h"
#import "LKLock.h"
#import "LKLockProximity.h"

#import "RFduino.h"
#import "RFduinoManager.h"

#import "MMWormhole.h"

#define kErrorDomain                @"LKLockDiscoveryManager"
#define kGroupIdentifier            @"group.com.s150.ent.spacelab"
#define kLockActiveContextName      @"lockDiscoveryActiveContext"

@interface LKLockDiscoveryManager ()
{
    RFduino *connectedRFduino;
    NSString *testLockUUID;
    NSTimer *testUpdateTimer;
    NSString *instanceContext;
    MMWormhole *wormhole;
    NSTimer *handshakeTimer;
    NSDictionary *keys;
}

@property (copy) void (^openCompletionCallback)(bool, NSError *);

@end

@implementation LKLockDiscoveryManager

- (id)initWithContext:(NSString *)context
{
    self = [super init];
    if ( self != nil )
    {
        instanceContext = context;
        
        keys = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Default-Keychain" ofType:@"plist"]];
        
        self.rfduinoManager = [RFduinoManager sharedRFduinoManager];
        [self.rfduinoManager stopScan];
        self.rfduinoManager.delegate = self;
        
        connectedRFduino = nil;
        
        testLockUUID = @"f2c8e796-c022-4fa9-a802-cc16963f362e";
        testUpdateTimer = nil;
        
        wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:kGroupIdentifier
                                                        optionalDirectory:@"wormhole"];
        
        [wormhole listenForMessageWithIdentifier:kLockActiveContextName listener:^(id messageObject)
        {
            NSString *activeContext = (NSString *)messageObject;
            NSLog(@"self: %@, instanceContext: %@, received active context update: %@", self, instanceContext, activeContext);
            if ( ![activeContext isEqualToString:@""] )
            {
                if ( ![activeContext isEqualToString:instanceContext] )
                    [self stopDiscovery];
            }
        }];
        
        handshakeTimer = nil;
    }
    return self;
}

#pragma mark - Testing (in Simulator)

- (void)loadTestingData
{
    NSManagedObjectContext *context = [[LKLockRepository sharedInstance] managedObjectContext];

    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"LKLock" inManagedObjectContext:context]];
    [request setPredicate:[NSPredicate predicateWithFormat:@"uuid LIKE[c] %@", testLockUUID]];
    
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:request error:&error];
    if ( results != nil && [results count] == 0 )
    {
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"LKLock" inManagedObjectContext:context];
        LKLock *lock = (LKLock *)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:context];
        lock.uuid = testLockUUID;
        lock.name = @"Vault";
        lock.lockId = @"s150-vault";
        lock.icon = @"icon-vault";
        lock.proximity = [NSNumber numberWithInt:(int)LKLockProximityImmediate];
        lock.proximityString = [self proximityString:[lock.proximity intValue]];
        lock.lastActionAt = [NSDate date];
        
        [[LKLockRepository sharedInstance] saveContext];
    }
}

- (void)testUpdate:(NSTimer *)timer
{
    NSManagedObjectContext *context = [[LKLockRepository sharedInstance] managedObjectContext];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"LKLock" inManagedObjectContext:context]];
    [request setPredicate:[NSPredicate predicateWithFormat:@"uuid LIKE[c] %@", testLockUUID]];
    
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:request error:&error];
    if ( results != nil && [results count] > 0 )
    {
        LKLock *lock = (LKLock *)[results objectAtIndex:0];
        
        int proximity = [lock.proximity intValue];
        proximity += 1;
        if ( proximity > LKLockProximityImmediate )
            proximity = LKLockProximityUnknown;
        
        lock.proximity = [NSNumber numberWithInt:proximity];
        lock.proximityString = [self proximityString:(LKLockProximity)proximity];
        lock.lastActionAt = [NSDate date];
        
    }
}

#pragma mark - Public methods

- (void)startDiscovery
{
    if ( ![self.rfduinoManager isScanning] )
    {
        // when attempting to setup discovery, first see if another context is active
        NSString *activeContext = (NSString *)[wormhole messageWithIdentifier:kLockActiveContextName];
        if ( ![activeContext isEqualToString:instanceContext] )
        {
            // if another context is not active, then start it up and set this context as active
            [wormhole passMessageObject:instanceContext identifier:kLockActiveContextName];
        }
        
        // if we are in simulator mode, load up the testing data!
#if TARGET_IPHONE_SIMULATOR
        [self loadTestingData];
        testUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:5.0f target:self selector:@selector(testUpdate:) userInfo:nil repeats:YES];
#endif
        
        [self clearExpiredLocks];
        
        // otherwise start scanning
        [self.rfduinoManager startScan];
    }
}

- (void)stopDiscovery
{
    if ( [self.rfduinoManager isScanning] )
    {
        // when halting discovery, set this context as inactive if it is the currently active context
        NSString *activeContext = (NSString *)[wormhole messageWithIdentifier:kLockActiveContextName];
        if ( [activeContext isEqualToString:instanceContext] )
        {
            [wormhole passMessageObject:@"" identifier:kLockActiveContextName];
        }
        
#if TARGET_IPHONE_SIMULATOR
        [testUpdateTimer invalidate];
        testUpdateTimer = nil;
#endif
        
        [self.rfduinoManager stopScan];
    }
}

- (void)openLock:(LKLock *)lock complete:(void (^)(bool success, NSError *error))completionCallback
{
    [self openLockWithId:lock.lockId complete:completionCallback];
}

- (void)openLockWithId:(NSString *)lockId complete:(void (^)(bool success, NSError *error))completionCallback
{
    self.openCompletionCallback = completionCallback;
    
    // find the rfduino!
    RFduino *foundRFDuino = nil;
    for ( RFduino *rfduino in self.rfduinoManager.rfduinos )
    {
        NSString* thisLockId = [NSString stringWithUTF8String:[rfduino.advertisementData bytes]];
        if ( [lockId isEqualToString:thisLockId] )
            foundRFDuino = rfduino;
    }
    
    if ( foundRFDuino != nil )
    {
        [self initHandshake:foundRFDuino];
    }
    else if ( self.openCompletionCallback != nil )
    {
        self.openCompletionCallback(NO, [NSError errorWithDomain:kErrorDomain
                                                            code:42
                                                        userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Unable to find active Lock with that lockId!", nil)}]);
    }
}

#pragma mark - Security Methods

- (void)initHandshake:(RFduino *)rfduino
{
    if ( !rfduino.outOfRange )
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.rfduinoManager connectRFduino:rfduino];
        });
        
        // start a timeout timer here, if we don't hear back in X seconds we should
        // disconnect, cancel and throw an error
        handshakeTimer = [NSTimer scheduledTimerWithTimeInterval:5.0f target:self selector:@selector(handshakeTimeout:) userInfo:nil repeats:NO];
    }
    else
    {
        if ( self.openCompletionCallback != nil )
        {
            self.openCompletionCallback(NO, [NSError errorWithDomain:kErrorDomain
                                                                code:42
                                                            userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Lock is out of range", nil)}]);
        }
    }
}

- (void)handshakeTimeout:(NSTimer *)timer
{
    if ( self.openCompletionCallback != nil )
    {
        self.openCompletionCallback(NO, [NSError errorWithDomain:kErrorDomain
                                                            code:42
                                                        userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Handshake timed out!", nil)}]);
    }
    
    [handshakeTimer invalidate];
    handshakeTimer = nil;
}

- (void)verifyHandshake:(NSData *)data
{
    if ( connectedRFduino != nil && [data length] == 16 )
    {
        // get the lock entry:
        NSString* lockId = [NSString stringWithUTF8String:[connectedRFduino.advertisementData bytes]];
        if ( lockId == nil )
        {
            self.openCompletionCallback(NO, [NSError errorWithDomain:kErrorDomain
                                                                code:42
                                                            userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Lock has no advertisement data!", nil)}]);
            return;
        }
        
        NSManagedObjectContext *context = [[LKLockRepository sharedInstance] managedObjectContext];
        
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        [request setEntity:[NSEntityDescription entityForName:@"LKLock" inManagedObjectContext:context]];
        [request setPredicate:[NSPredicate predicateWithFormat:@"lockId == %@", lockId]];
        
        NSError *error = nil;
        NSArray *results = [context executeFetchRequest:request error:&error];
        if ( results != nil && [results count] > 0 )
        {
            LKLock *lock = (LKLock *)[results objectAtIndex:0];
        
            LKSecurityManager *security = [[LKSecurityManager alloc] init];
            NSString *lockId = [security decryptData:data forLockName:lock.lockId];
            NSLog(@"lockId: %@, lock: %@", lockId, lock.lockId);
            
            // verify the lock id!
            if ( lockId != nil && [lockId isEqualToString:lock.lockId] )
            {
                NSString *command = [NSString stringWithFormat:@"%@%d", @"u", (int)[[NSDate date] timeIntervalSince1970]];
                NSData *data = [security encryptString:command forLockName:lock.lockId];
                
                [connectedRFduino send:data];
                
                // force disconnection, in thetu fure we could listen for the lock status and disconnect later?
                [connectedRFduino disconnect];
                
                if ( self.openCompletionCallback != nil )
                {
                    self.openCompletionCallback(YES, nil);
                    self.openCompletionCallback = nil;
                }
            }
            else
            {
                [connectedRFduino disconnect];
                
                if ( self.openCompletionCallback != nil )
                {
                    self.openCompletionCallback(NO, [NSError errorWithDomain:kErrorDomain
                                                                        code:42
                                                                    userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Lock responded with an invalid lock ID", nil)}]);
                }
            }
        }
        else
        {
            [connectedRFduino disconnect];
            
            if ( self.openCompletionCallback != nil )
            {
                self.openCompletionCallback(NO, [NSError errorWithDomain:kErrorDomain
                                                                    code:42
                                                                userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"No connected lock", nil)}]);
            }
        }
    }
}

#pragma mark - Lock Management

- (void)clearExpiredLocks
{
    NSManagedObjectContext *context = [[LKLockRepository sharedInstance] managedObjectContext];
    
    NSMutableArray *expiredLocks = [[NSMutableArray alloc] init];
    
    NSDate *now = [NSDate date];
    
    // grab all the existing locks and set them as "possibly expired"
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"LKLock" inManagedObjectContext:context]];
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:request error:&error];
    if ( results != nil && [results count] > 0 )
    {
        for ( int j = 0; j < [results count]; j++ )
        {
            LKLock *lock = (LKLock *)[results objectAtIndex:j];
            [expiredLocks addObject:lock];
        }
    }
    
    // now remove the locks from the "possibly expired" list if we find them and they have been updated recently
    for ( RFduino *rfduino in self.rfduinoManager.rfduinos )
    {
        if ( !rfduino.outOfRange && [now timeIntervalSinceDate:rfduino.lastAdvertisement] < 10 )
        {
            NSInteger foundIndex = -1;
            for ( int j = 0; j < [expiredLocks count]; j++ )
            {
                LKLock *lock = (LKLock *)[expiredLocks objectAtIndex:j];
                NSString *thisLockId = [NSString stringWithUTF8String:[rfduino.advertisementData bytes]];
                if ( [lock.lockId isEqualToString:thisLockId] )
                {
                    foundIndex = j;
                }
            }
            if ( foundIndex > -1 )
                [expiredLocks removeObjectAtIndex:foundIndex];
        }
    }
    
#if TARGET_IPHONE_SIMULATOR
    [expiredLocks removeAllObjects];
#endif
    
    NSLog(@"found expired locks: %@", expiredLocks);
    
    // update the proxmity on expired locks to "unknown"
    for ( int i = 0; i < [expiredLocks count]; i++ )
    {
        LKLock *lock = (LKLock *)[expiredLocks objectAtIndex:i];
        lock.proximity = [NSNumber numberWithInt:RFduinoRangeUnknown];
        lock.proximityString = [self proximityString:(LKLockProximity)[lock.proximity intValue]];
        lock.lastActionAt = [NSDate date];
    }
    
    [[LKLockRepository sharedInstance] saveContext];
}

- (void)createLock:(RFduino *)rfduino
{
    NSString* lockId = [NSString stringWithUTF8String:[rfduino.advertisementData bytes]];
    if ( lockId == nil )
    {
        NSLog(@"ERROR: lock has no advertisement data/lock Id!");
        return;
    }
    
    NSManagedObjectContext *context = [[LKLockRepository sharedInstance] managedObjectContext];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"LKLock" inManagedObjectContext:context]];
    [request setPredicate:[NSPredicate predicateWithFormat:@"lockId == %@", lockId]];
    
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:request error:&error];
    if ( results != nil && [results count] == 0 )
    {
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"LKLock" inManagedObjectContext:context];
        LKLock *lock = (LKLock *)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:context];

        // find this lock entry in the plist data
        NSDictionary *entry = (NSDictionary *)[keys objectForKey:lockId];
        lock.lockId = lockId;
        lock.name = [entry objectForKey:@"name"];
        lock.icon = [entry objectForKey:@"icon"];
        
        lock.uuid = rfduino.UUID;
        lock.proximity = [NSNumber numberWithInt:rfduino.proximity];
        lock.proximityString = [self proximityString:(LKLockProximity)rfduino.proximity];
        lock.lastActionAt = [NSDate date];
        
        [[LKLockRepository sharedInstance] saveContext];
    }
}

- (void)updateLock:(RFduino *)rfduino
{
    NSString* lockId = [NSString stringWithUTF8String:[rfduino.advertisementData bytes]];
    if ( lockId == nil )
    {
        NSLog(@"ERROR: lock has no advertisement data/lock Id!");
        return;
    }
    
    NSManagedObjectContext *context = [[LKLockRepository sharedInstance] managedObjectContext];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"LKLock" inManagedObjectContext:context]];
    [request setPredicate:[NSPredicate predicateWithFormat:@"lockId == %@", lockId]];
    
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:request error:&error];
    if ( results != nil && [results count] > 0 )
    {
        LKLock *lock = (LKLock *)[results objectAtIndex:0];
       
        // if the proxmity value has changed, update it
       if ( [lock.proximity intValue] != (int)rfduino.proximity )
        {
            lock.proximity = [NSNumber numberWithInt:rfduino.proximity];
            lock.proximityString = [self proximityString:(LKLockProximity)rfduino.proximity];
            lock.lastActionAt = [NSDate date];
        }
    }
    else
    {
        [self createLock:rfduino];
    }
}

#pragma mark - RfduinoDiscoveryDelegate methods

- (void)didDiscoverRFduino:(RFduino *)rfduino
{
    if ( rfduino.UUID != nil )
        [self createLock:rfduino];
    
}

- (void)didUpdateDiscoveredRFduino:(RFduino *)rfduino
{
    if ( rfduino.UUID != nil )
        [self updateLock:rfduino];
    else if ( rfduino == nil )
        [self clearExpiredLocks];
}

- (void)didConnectRFduino:(RFduino *)rfduino
{
    connectedRFduino = rfduino;
    connectedRFduino.delegate = self;
}

- (void)didLoadServiceRFduino:(RFduino *)rfduino
{
    // nothing
}

- (void)didDisconnectRFduino:(RFduino *)rfduino
{
    if ( connectedRFduino != nil )
        [connectedRFduino setDelegate:nil];
    
    if ( self.openCompletionCallback != nil )
        self.openCompletionCallback = nil;
}

#pragma mark - RFduinoDelegate Methods

- (void)didReceive:(NSData *)data
{
    [self verifyHandshake:data];
}

- (NSString *)proximityString:(LKLockProximity)proximity
{
    switch (proximity)
    {
        case LKLockProximityFar:
            return @"Far";
            break;
            
        case LKLockProximityImmediate:
            return @"Immediate";
            break;
            
        case LKLockProximityNear:
            return @"Near";
            break;
            
        case LKLockProximityUnknown:
            return @"Unknown";
            break;
    }
}

@end
