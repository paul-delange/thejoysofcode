//
//  DetailViewController.m
//  TheJoysOfCode
//
//  Created by Bob on 29/10/12.
//  Copyright (c) 2012 Tall Developments. All rights reserved.
//

#import "DetailViewController.h"

#import "Post.h"
#import "GIFDownloader.h"

#import <MediaPlayer/MediaPlayer.h>

@interface DetailViewController ()

@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@property (strong, nonatomic) MPMoviePlayerController* moviePlayer;

- (void)configureView;
@end

@implementation DetailViewController

#pragma mark - Managing the detail item

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil  {
    self = [super initWithNibName: nibNameOrNil bundle: nibBundleOrNil];
    if( self ) {
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(moviePlaybackStateChanged:)
                                                     name: MPMoviePlayerPlaybackStateDidChangeNotification
                                                   object: nil];
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if( self ) {
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(moviePlaybackStateChanged:)
                                                     name: MPMoviePlayerPlaybackStateDidChangeNotification
                                                   object: nil];
    }
    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)setDetailItem:(Post*)newDetailItem
{
    if (_detailItem != newDetailItem) {
        _detailItem = newDetailItem;
        
        // Update the view.
        [self configureView];
    }
    
    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }
}

- (void)configureView
{
    // Update the user interface for the detail item.
    
    if (self.detailItem) {
        self.title = @"";
        self.detailDescriptionLabel.text = self.detailItem.title;
        
        NSURL* url = [NSURL fileURLWithPath: self.detailItem.pathToCachedVideo];
        NSAssert(url, @"No video cached for: %@", self.detailItem);
        
        MPMoviePlayerController* mp = [[MPMoviePlayerController alloc] initWithContentURL: url];
        [mp prepareToPlay];
        mp.repeatMode = MPMovieRepeatModeOne;
        mp.allowsAirPlay = NO;
        mp.shouldAutoplay = NO;
        mp.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        [self.view insertSubview: mp.view belowSubview: self.detailDescriptionLabel];
        
        self.moviePlayer = mp;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	// Do any additional setup after loading the view, typically from a nib.
    [self configureView];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    CGRect frame = CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
    self.moviePlayer.view.frame = frame;
    
    [UIView animateWithDuration: 0.01
                          delay: 0
                        options: 0
                     animations: ^{
                         self.detailDescriptionLabel.alpha = 1.f;
                     } completion: ^(BOOL finished) {
                         NSInteger numberOfWords = [self.detailDescriptionLabel.text componentsSeparatedByString: @" "].count;
                         
                         NSTimeInterval delay = numberOfWords * 0.1;
                         
                         delay = MAX(0.5, delay);
                         
                         [UIView animateWithDuration: 0.3
                                               delay: delay
                                             options: UIViewAnimationOptionCurveEaseOut
                                          animations: ^{
                                              self.detailDescriptionLabel.alpha = 0.f;
                                              
                                          } completion: ^(BOOL finished) {
                                              self.title = self.detailItem.title;
                                              
                                              NSAssert(self.moviePlayer.loadState & (MPMovieLoadStatePlayable | MPMovieLoadStatePlaythroughOK), @"The movie player was in a bad load state: %d", self.moviePlayer.loadState);
                                              NSAssert(self.moviePlayer.playbackState == MPMoviePlaybackStateStopped, @"Movie will not start at the beginning");
                                              NSAssert(self.moviePlayer.isPreparedToPlay, @"Movie player was not prepared");
                                              
                                              [self.moviePlayer play];
                                          }];
                     }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) moviePlaybackStateChanged: (NSNotification*) notification {
    //NSLog(@"Playback state: %d", self.moviePlayer.playbackState);
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Master", @"Master");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

- (void)viewDidUnload {
    [super viewDidUnload];
}
@end
