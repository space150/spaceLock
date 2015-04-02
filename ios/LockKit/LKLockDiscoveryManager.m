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

@interface LKLockDiscoveryManager ()
{
    RFduino *connectedRFduino;
}

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
    }
    return self;
}

#pragma mark - Public methods

- (void)loadTestingData
{
    NSManagedObjectContext *context = [[LKLockRepository sharedInstance] managedObjectContext];
    
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"LKLock" inManagedObjectContext:context];
    LKLock *lock = (LKLock *)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:context];
    lock.uuid = @"test-uuid";
    lock.name = @"test-name";
    lock.lastActionAt = [NSDate date];
    
    [[LKLockRepository sharedInstance] saveContext];
}

- (void)startDiscovery
{
    // if we are in simulator mode, load up the testing data!
    // TODO
    
    // otherwise start scanning
    [self.rfduinoManager startScan];
}

- (void)stopDiscovery
{
    [self.rfduinoManager stopScan];
}

- (void)openLock:(LKLock *)lock complete:(bool (^)(void))completionCallback;
{
    [self openLockWithUUID:lock.uuid complete:completionCallback];
}

- (void)openLockWithUUID:(NSString *)uuid complete:(bool (^)(void))completionCallback
{
    // find the rfduino!
    RFduino *foundRFDuino = nil;
    for ( RFduino *rfduino in self.rfduinoManager.rfduinos )
        if ( [uuid isEqualToString:rfduino.UUID] )
            foundRFDuino = rfduino;
    
    if ( foundRFDuino != nil )
        [self initHandshake:foundRFDuino];
}

// MARK: - Security methods

- (void)initHandshake:(RFduino *)rfduino
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ( !rfduino.outOfRange )
            [self.rfduinoManager connectRFduino:rfduino];
    });
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
    }
}

#pragma mark - RfduinoDiscoveryDelegate methods

- (void)didDiscoverRFduino:(RFduino *)rfduino
{
    // we need a UUID and a "known" range to even care about this one
    if ( rfduino.UUID != nil )
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
    
}

- (void)didUpdateDiscoveredRFduino:(RFduino *)rfduino
{
    if ( rfduino.UUID != nil )
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
            
            // if this rfduino has a new range of unknown and we haven't updated it in quite some time delete it!
            // TODO
            if ( rfduino.proximity == RFduinoRangeUnknown )
            {
                //[context deleteObject:lock];
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
            NSLog(@"error in searching for lock with UUID: %@ -- %@", rfduino.UUID, [error localizedDescription]);
        }
    }
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
