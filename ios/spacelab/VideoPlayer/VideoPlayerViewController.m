//This file is part of MyVideoPlayer.
//
//MyVideoPlayer is free software: you can redistribute it and/or modify
//it under the terms of the GNU General Public License as published by
//the Free Software Foundation, either version 3 of the License, or
//(at your option) any later version.
//
//MyVideoPlayer is distributed in the hope that it will be useful,
//but WITHOUT ANY WARRANTY; without even the implied warranty of
//MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//GNU General Public License for more details.
//
//You should have received a copy of the GNU General Public License
//along with MyVideoPlayer.  If not, see <http://www.gnu.org/licenses/>.

#import "VideoPlayerViewController.h"
#import "VideoPlayerView.h"

/* Asset keys */
NSString * const kTracksKey = @"tracks";
NSString * const kPlayableKey = @"playable";

/* PlayerItem keys */
NSString * const kStatusKey         = @"status";
NSString * const kCurrentItemKey	= @"currentItem";

@interface VideoPlayerViewController ()

@property (nonatomic, retain) VideoPlayerView *playerView;

@end

static void *AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext = &AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext;
static void *AVPlayerDemoPlaybackViewControllerStatusObservationContext = &AVPlayerDemoPlaybackViewControllerStatusObservationContext;

@implementation VideoPlayerViewController

@synthesize URL = _URL;
@synthesize player = _player;
@synthesize playerItem = _playerItem;
@synthesize playerView = _playerView;
@synthesize assetLoaded = _assetLoaded;

#pragma mark - UIView lifecycle

- (id)init
{
    self = [super init];
    if ( self )
    {
        self.playOnLoad = NO;
        self.loopPlayback = NO;
        self.assetLoaded = NO;
    }
    return self;
}

- (void)loadView
{
    VideoPlayerView *playerView = [[VideoPlayerView alloc] init];
    self.view = playerView;
    
    self.playerView = playerView;
    
//    [super loadView];
}


#pragma mark - Memory Management

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:[self.player currentItem]];
    
    [self.player removeObserver:self forKeyPath:kCurrentItemKey];
    [self.player.currentItem removeObserver:self forKeyPath:kStatusKey];
	[self.player pause];
    
    self.URL = nil;
    self.player = nil;
    self.playerItem = nil;
    self.playerView = nil;
    self.assetLoaded = NO;
}


#pragma mark - Private methods

- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
{
    for (NSString *thisKey in requestedKeys) {
		NSError *error = nil;
		AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
		if (keyStatus == AVKeyValueStatusFailed) {
			return;
		}
	}
    
    //if (!asset.playable) {
    //    return;
    //}
	
	if (self.playerItem)
    {
        [self.playerItem removeObserver:self forKeyPath:kStatusKey];            
		
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.playerItem];
    }
	
    self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
    [self.playerItem addObserver:self 
                       forKeyPath:kStatusKey 
                          options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                          context:AVPlayerDemoPlaybackViewControllerStatusObservationContext];
		
    if (![self player])
    {
        [self setPlayer:[AVPlayer playerWithPlayerItem:self.playerItem]];	
        [self.player addObserver:self 
                      forKeyPath:kCurrentItemKey 
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext];
    }
    
    if (self.player.currentItem != self.playerItem)
    {
        [[self player] replaceCurrentItemWithPlayerItem:self.playerItem];
    }
}


#pragma mark - Key Valye Observing

- (void)observeValueForKeyPath:(NSString*) path 
                      ofObject:(id)object 
                        change:(NSDictionary*)change 
                       context:(void*)context
{
	if (context == AVPlayerDemoPlaybackViewControllerStatusObservationContext)
    {
        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        if (status == AVPlayerStatusReadyToPlay)
        {
            if ( self.playOnLoad )
            {
                if ( self.loopPlayback )
                {
                    [[NSNotificationCenter defaultCenter] addObserver:self
                                                             selector:@selector(playerItemDidReachEnd:)
                                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                                               object:[self.player currentItem]];
                }
                
                [self.player play];
            }
            else
                [self.player pause];
            
            self.assetLoaded = YES;
        }
	}
    else if (context == AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext)
    {
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        
        if (newPlayerItem)
        {
            [self.playerView setPlayer:self.player];
            [self.playerView setVideoFillMode:AVLayerVideoGravityResizeAspect];
        }
	}
    else
    {
		[super observeValueForKeyPath:path ofObject:object change:change context:context];
	}
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    [self.player.currentItem seekToTime:kCMTimeZero];
    [self.player play];
}

#pragma mark - Public methods

- (void)setURL:(NSURL*)URL
{
    _URL = [URL copy];
    
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:_URL options:nil];
    
    NSArray *requestedKeys = [NSArray arrayWithObjects:kTracksKey, kPlayableKey, nil];

    [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:
     ^{		 
         dispatch_async( dispatch_get_main_queue(), 
                        ^{
                            [self prepareToPlayAsset:asset withKeys:requestedKeys];
                        });
     }];
    
    self.assetLoaded = NO;
}

@end
