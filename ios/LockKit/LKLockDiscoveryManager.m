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

#define kErrorDomain @"LKLockDiscoveryManager"

@interface LKLockDiscoveryManager ()
{
    RFduino *connectedRFduino;
    NSString *testLockUUID;
    NSTimer *testUpdateTimer;
}

@property (copy) void (^openCompletionCallback)(bool, NSError *);

@end

@implementation LKLockDiscoveryManager

- (id)init
{
    self = [super init];
    if ( self != nil )
    {
        self.rfduinoManager = [RFduinoManager sharedRFduinoManager];
        [self.rfduinoManager stopScan];
        self.rfduinoManager.delegate = self;
        
        connectedRFduino = nil;
        
        testLockUUID = @"f2c8e796-c022-4fa9-a802-cc16963f362e";
        testUpdateTimer = nil;
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
            proximity = LKLockProximityFar;
        
        lock.proximity = [NSNumber numberWithInt:proximity];
        lock.proximityString = [self proximityString:(LKLockProximity)proximity];
        lock.lastActionAt = [NSDate date];
        
    }
}

#pragma mark - Public methods

- (void)startDiscovery
{
    // if we are in simulator mode, load up the testing data!
#if TARGET_IPHONE_SIMULATOR
    [self loadTestingData];
    testUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(testUpdate:) userInfo:nil repeats:YES];
#endif
    
    [self clearExpiredLocks];
    
    // otherwise start scanning
    [self.rfduinoManager startScan];
}

- (void)stopDiscovery
{
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
        // TODO
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
    
    NSDate *now = [NSDate date];
    
    // if we have a nil rfduino, then loop through and collect the UUIDs with "out of range" arduinos
    NSMutableArray *expiredLocks = [[NSMutableArray alloc] init];
    for ( RFduino *rfduino in self.rfduinoManager.rfduinos )
    {
        if ( rfduino.outOfRange || [now timeIntervalSinceDate:rfduino.lastAdvertisement] > 10 )
            [expiredLocks addObject:rfduino.UUID];
    }
    
    NSLog(@"found expired locks: %@", expiredLocks);
    
    // delete the expired locks
    for ( int i = 0; i < [expiredLocks count]; i++ )
    {
        NSString *uuid = (NSString *)[expiredLocks objectAtIndex:i];
        
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        [request setEntity:[NSEntityDescription entityForName:@"LKLock" inManagedObjectContext:context]];
        [request setPredicate:[NSPredicate predicateWithFormat:@"uuid LIKE[c] %@", uuid]];
        
        NSError *error = nil;
        NSArray *results = [context executeFetchRequest:request error:&error];
        if ( results != nil && [results count] > 0 )
        {
            for ( int j = 0; j < [results count]; j++ )
            {
                LKLock *lock = (LKLock *)[results objectAtIndex:j];
                [context deleteObject:lock];
            }
        }
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
    
    [self.rfduinoManager stopScan];
    
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
    
    [self.rfduinoManager startScan];
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
