//
//  LKLockDiscoveryManager.m
//  spacelab
//
//  Created by Shawn Roske on 3/30/15.
//  Copyright (c) 2015 space150. All rights reserved.
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
            NSLog(@"instanceContext: %@, received active context update: %@", instanceContext, activeContext);
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
        lock.name = @"space150-msp-f3";
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

- (void)stopDiscovery
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

- (void)openLock:(LKLock *)lock complete:(void (^)(bool success, NSError *error))completionCallback
{
    [self openLockWithUUID:lock.uuid complete:completionCallback];
}

- (void)openLockWithUUID:(NSString *)uuid complete:(void (^)(bool success, NSError *error))completionCallback
{
    self.openCompletionCallback = completionCallback;
    
    // find the rfduino!
    RFduino *foundRFDuino = nil;
    for ( RFduino *rfduino in self.rfduinoManager.rfduinos )
        if ( [[uuid lowercaseString] isEqualToString:[rfduino.UUID lowercaseString]] )
            foundRFDuino = rfduino;
    
    if ( foundRFDuino != nil )
    {
        [self initHandshake:foundRFDuino];
    }
    else if ( self.openCompletionCallback != nil )
    {
        self.openCompletionCallback(NO, [NSError errorWithDomain:kErrorDomain
                                                            code:42
                                                        userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Unable to find active Lock by that UUID!", nil)}]);
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
    if ( [data length] == 16 )
    {
        LKSecurityManager *security = [[LKSecurityManager alloc] init];
        NSString *lockId = [security decryptData:data];
        NSLog(@"lockId: %@", lockId);
        
        // TODO VERIFY LOCK ID!
        
        NSString *command = [NSString stringWithFormat:@"%@%d", @"u", (int)[[NSDate date] timeIntervalSince1970]];
        NSData *data = [security encryptString:command];
        
        [connectedRFduino send:data];
        
        // force disconnection, in the future we could listen for the lock status and disconnect later?
        [connectedRFduino disconnect];
        
        if ( self.openCompletionCallback != nil )
        {
            self.openCompletionCallback(YES, nil);
            self.openCompletionCallback = nil;
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
                if ( [[lock.uuid lowercaseString] isEqualToString:[rfduino.UUID lowercaseString]] )
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
    NSManagedObjectContext *context = [[LKLockRepository sharedInstance] managedObjectContext];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"LKLock" inManagedObjectContext:context]];
    [request setPredicate:[NSPredicate predicateWithFormat:@"uuid LIKE[c] %@", rfduino.UUID]];
    
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:request error:&error];
    if ( results != nil && [results count] == 0 )
    {
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"LKLock" inManagedObjectContext:context];
        LKLock *lock = (LKLock *)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:context];
        lock.uuid = rfduino.UUID;
        lock.name = rfduino.name;
        lock.proximity = [NSNumber numberWithInt:rfduino.proximity];
        lock.proximityString = [self proximityString:(LKLockProximity)rfduino.proximity];
        lock.lastActionAt = [NSDate date];
        
        [[LKLockRepository sharedInstance] saveContext];
    }
}

- (void)updateLock:(RFduino *)rfduino
{
    NSManagedObjectContext *context = [[LKLockRepository sharedInstance] managedObjectContext];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"LKLock" inManagedObjectContext:context]];
    [request setPredicate:[NSPredicate predicateWithFormat:@"uuid LIKE[c] %@", rfduino.UUID]];
    
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:request error:&error];
    if ( results != nil && [results count] > 0 )
    {
        LKLock *lock = (LKLock *)[results objectAtIndex:0];
        
        // if this lock is out of range, remove it
        if ( rfduino.outOfRange )
        {
            [context deleteObject:lock];
        }
        // otherwise update the proximity if it has changed
        else if ( [lock.proximity intValue] != (int)rfduino.proximity )
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
    NSLog(@"didConnectRFduino");
    
    //[self.rfduinoManager stopScan];
    
    connectedRFduino = rfduino;
    connectedRFduino.delegate = self;
}

- (void)didLoadServiceRFduino:(RFduino *)rfduino
{
    NSLog(@"didLoadServiceRFduino");
}

- (void)didDisconnectRFduino:(RFduino *)rfduino
{
    NSLog(@"didDisconnectRFduino");
    
    if ( connectedRFduino != nil )
        [connectedRFduino setDelegate:nil];
    
    if ( self.openCompletionCallback != nil )
        self.openCompletionCallback = nil;
    
    //[self.rfduinoManager startScan];
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
