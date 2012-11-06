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
#import <Social/Social.h>

@interface DetailViewController () <UIPopoverControllerDelegate, UIActionSheetDelegate>

@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@property (strong, nonatomic) MPMoviePlayerController* moviePlayer;
@property (strong, nonatomic) UIPopoverController* sharePopoverController;

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
        if( self.isViewLoaded )
            [self configureView];
    }
    
    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }
}

- (void) setMoviePlayer:(MPMoviePlayerController *)moviePlayer {
    if( _moviePlayer ) {
        [_moviePlayer stop];
        [_moviePlayer.view removeFromSuperview];
    }
    
    if( moviePlayer ) {
        [moviePlayer prepareToPlay];
        moviePlayer.repeatMode = MPMovieRepeatModeOne;
        moviePlayer.allowsAirPlay = NO;
        moviePlayer.shouldAutoplay = NO;
        moviePlayer.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        [self.view insertSubview: moviePlayer.view belowSubview: self.detailDescriptionLabel];
    }
    
    _moviePlayer = moviePlayer;
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
        self.moviePlayer = mp;
        
        CGRect frame = CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
        self.moviePlayer.view.frame = frame;
        
        self.navigationItem.rightBarButtonItem.enabled = YES;
        
        [UIView animateWithDuration: 0.01
                              delay: 0
                            options: 0
                         animations: ^{
                             self.detailDescriptionLabel.alpha = 1.f;
                         } completion: ^(BOOL finished) {
                             NSInteger numberOfWords = [self.detailDescriptionLabel.text componentsSeparatedByString: @" "].count;
                             
                             NSTimeInterval delay = numberOfWords * 0.15;
                             
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
    else {
        self.navigationItem.rightBarButtonItem.enabled = NO;
        self.detailDescriptionLabel.text = NSLocalizedString(@"Choose a video from the list...", @"");
        self.title = NSLocalizedString(@"The Joys of Code", @"");
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	// Do any additional setup after loading the view, typically from a nib.
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemAction
                                                                                           target: self
                                                                                           action: @selector(sharePushed:)];
    
    
    [self configureView];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    if( self.detailItem ) {
        
    }
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
    barButtonItem.title = NSLocalizedString(@"Videos", @"");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

#pragma mark - Actions
- (void) sharePushed: (id) sender {
    if( NSClassFromString(@"UIActivityViewController") ) {
        if( self.sharePopoverController )
            return;
        
        NSArray* activities = nil;
        NSArray* items = @[self.detailItem.url];
        NSArray* exclude = @[UIActivityTypePostToWeibo, UIActivityTypeAssignToContact, UIActivityTypePrint, UIActivityTypeSaveToCameraRoll];
        
        UIActivityViewController* vc = [[UIActivityViewController alloc] initWithActivityItems: items
                                                                         applicationActivities: activities];
        vc.excludedActivityTypes = exclude;
        vc.completionHandler = ^(NSString* activityType, BOOL completed) {
            self.sharePopoverController = nil;
        };
        
        self.sharePopoverController = [[UIPopoverController alloc] initWithContentViewController: vc];
        self.sharePopoverController.delegate = self;
        [self.sharePopoverController presentPopoverFromBarButtonItem: sender
                                            permittedArrowDirections: UIPopoverArrowDirectionUp
                                                            animated: YES];
    }
    else {
        UIActionSheet* actionSheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"Select social channel", @"")
                                                                 delegate: self
                                                        cancelButtonTitle: NSLocalizedString(@"Cancel", @"")
                                                   destructiveButtonTitle: nil
                                                        otherButtonTitles: @"Twitter", @"Mail", nil];
        [actionSheet showFromBarButtonItem: sender animated: YES];
    }
}

#pragma mark - UIPopoverControllerDelegate
- (void) popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    self.sharePopoverController = nil;
}

#pragma mark - UIActionSheetDelegate
- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if( buttonIndex != actionSheet.cancelButtonIndex ) {
        switch (buttonIndex) {
            case 0:
            {
                break;
            }
            case 1:
            {
                break;
            }
            default:
                break;
        }
    }
}

@end
