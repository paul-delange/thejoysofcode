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
#import "ContentProvider.h"

#import <MediaPlayer/MediaPlayer.h>
#import <Twitter/Twitter.h>
#import <MessageUI/MessageUI.h>
#import <Social/Social.h>
#import <QuartzCore/QuartzCore.h>

@interface DetailViewController () <UIPopoverControllerDelegate, UIActionSheetDelegate, MFMailComposeViewControllerDelegate> {
    BOOL ideaViewShowing;
}

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
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(movieFinishedPlaying:)
                                                     name: MPMoviePlayerPlaybackDidFinishNotification
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
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(movieFinishedPlaying:)
                                                     name: MPMoviePlayerPlaybackDidFinishNotification
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
        self.title = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"" : NSLocalizedString(@"The Joys of Code", @"");
        
        self.detailDescriptionLabel.text = self.detailItem.title;
        
        NSURL* url = [NSURL fileURLWithPath: self.detailItem.pathToCachedVideo];
        NSAssert(url, @"No video cached for: %@", self.detailItem);
        
        MPMoviePlayerController* mp = [[MPMoviePlayerController alloc] initWithContentURL: url];
        self.moviePlayer = mp;
        
        CGRect frame = CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
        self.moviePlayer.view.frame = frame;
        
        self.navigationItem.rightBarButtonItem.enabled = YES;
        self.titleReminderLabel.alpha = 0.f;
        self.titleReminderLabel.text = self.detailItem.title;

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
                                                  
                                                  
                                                  NSAssert(self.moviePlayer.loadState & (MPMovieLoadStatePlayable | MPMovieLoadStatePlaythroughOK), @"The movie player was in a bad load state: %d", self.moviePlayer.loadState);
                                                  NSAssert(self.moviePlayer.playbackState == MPMoviePlaybackStateStopped, @"Movie will not start at the beginning");
                                                  NSAssert(self.moviePlayer.isPreparedToPlay, @"Movie player was not prepared");
                                                  
                                                  [self.moviePlayer play];
                                              }];
                         }];
    }
    else {
        self.titleReminderLabel.alpha = 0.f;
        self.navigationItem.rightBarButtonItem.enabled = NO;
        self.detailDescriptionLabel.text = NSLocalizedString(@"Choose a video from the list...", @"");
        self.title = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? NSLocalizedString(@"When...", @"") : NSLocalizedString(@"The Joys of Code", @"");
    }
    
    if( ideaViewShowing ) {
        [UIView animateWithDuration: 0.3
                              delay: 0
                            options: UIViewAnimationCurveEaseOut
                         animations: ^{
                             self.ideaView.center = CGPointMake(CGRectGetWidth(self.view.frame) + CGRectGetWidth(self.ideaView.frame)/2.f,
                                                                CGRectGetMidY(self.view.frame));
                         } completion: ^(BOOL finished) {
                             ideaViewShowing = NO;
                         }];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	// Do any additional setup after loading the view, typically from a nib.
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemAction
                                                                                           target: self
                                                                                           action: @selector(sharePushed:)];
    
    
    self.ideaView.center = CGPointMake(CGRectGetWidth(self.view.frame) + CGRectGetWidth(self.ideaView.frame)/2.f,
                                       CGRectGetMidY(self.view.frame));
    /*
    CALayer* mask = [CALayer new];
    mask.contents = (__bridge id)([UIImage imageNamed: @"flare"].CGImage);
    mask.bounds = CGRectMake(0, 0, CGRectGetWidth(self.ideaView.frame), CGRectGetHeight(self.ideaView.frame));
    mask.position = CGPointMake(CGRectGetWidth(self.ideaView.frame)/2.f, CGRectGetHeight(self.ideaView.frame)/2.f);
    self.ideaView.layer.mask = mask;
    self.ideaButton.clipsToBounds = NO;
    */
    
    [self.ideaView.layer setCornerRadius: 30.f];
    [self.ideaView.layer setBorderColor: [UIColor lightGrayColor].CGColor];
    [self.ideaView.layer setBorderWidth: 1.5];
    [self.ideaView.layer setShadowColor: [UIColor blackColor].CGColor];
    [self.ideaView.layer setShadowOpacity: 0.8];
    [self.ideaView.layer setShadowRadius: 3.0];
    [self.ideaView.layer setShadowOffset: CGSizeMake(2.0, 2.0)];
    
    self.ideaButton.titleLabel.numberOfLines = 0;
    self.ideaButton.titleLabel.textAlignment = UITextAlignmentCenter;
    [self.ideaButton setTitle: NSLocalizedString(@"Have an idea? Tap here to let us know.", @"")
                     forState: UIControlStateNormal];
    
    self.titleReminderLabel.shadowColor = [UIColor blackColor];
    self.titleReminderLabel.shadowOffset = CGSizeMake(2, 2);
    
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

- (void) viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    if( ideaViewShowing ) {
        self.ideaView.center = CGPointMake(CGRectGetWidth(self.view.frame) - CGRectGetWidth(self.ideaView.frame)/2.f,
                                           CGRectGetMidY(self.view.frame));
    }
    else {
        self.ideaView.center = CGPointMake(CGRectGetWidth(self.view.frame) + CGRectGetWidth(self.ideaView.frame)/2.f,
                                           CGRectGetMidY(self.view.frame));
    }
    
    self.titleReminderLabel.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame)*0.25);
}

- (void) moviePlaybackStateChanged: (NSNotification*) notification {
    //NSLog(@"Playback state: %d", self.moviePlayer.playbackState);
    
    if( self.moviePlayer.playbackState == MPMoviePlaybackStatePaused ) {
        //Finished loop
        if( !ideaViewShowing ) {
            [UIView animateWithDuration: 0.3
                                  delay: 0
                                options: UIViewAnimationCurveEaseOut
                             animations: ^{
                                 self.ideaView.center = CGPointMake(CGRectGetWidth(self.view.frame) - CGRectGetWidth(self.ideaView.frame)/2.f,
                                                                    CGRectGetMidY(self.view.frame));
                                 self.titleReminderLabel.alpha = 1.f;
                             } completion: ^(BOOL finished) {
                             }];
            ideaViewShowing = YES;
        }
    }
}

- (void) movieFinishedPlaying: (NSNotification*) notification {
    NSLog(@"Finished: %@", notification);
    if( notification.object == self.moviePlayer ) {
        
    }
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (NSUInteger) supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
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
            [self dismissViewControllerAnimated: YES completion: ^{
                
            }];
        };
        
        if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {

        self.sharePopoverController = [[UIPopoverController alloc] initWithContentViewController: vc];
        self.sharePopoverController.delegate = self;
        [self.sharePopoverController presentPopoverFromBarButtonItem: sender
                                            permittedArrowDirections: UIPopoverArrowDirectionUp
                                                            animated: YES];
        }
        else {
            [self presentViewController: vc animated: YES completion:^{
                
            }];
        }
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

- (IBAction)ideaPushed:(UIButton *)sender {
    [UIView animateWithDuration: 0.3
                          delay: 0
                        options: UIViewAnimationCurveEaseOut
                     animations: ^{
                         self.ideaView.center = CGPointMake(CGRectGetWidth(self.view.frame) + CGRectGetWidth(self.ideaView.frame)/2.f,
                                                            CGRectGetMidY(self.view.frame));
                     } completion: ^(BOOL finished) {
                     }];
    
    //Mail
    if( [MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController* vc = [MFMailComposeViewController new];
        [vc setSubject: NSLocalizedString(@"The Joys of Code", @"")];
        NSString* body = @"Situation:\n\n\nGIF:\n\n\nMy name:\n\n\n";
        [vc setMessageBody: body isHTML: NO];
        vc.mailComposeDelegate = self;
        [vc setToRecipients: @[[ContentProvider feedbackEmail]]];
        vc.modalPresentationStyle = UIModalPresentationFormSheet;
        [self presentModalViewController: vc animated: YES];
    }
    else {
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Configure Mail", @"")
                                                        message: NSLocalizedString(@"Please configure a Mail account in your device settings", @"")
                                                       delegate: nil
                                              cancelButtonTitle: NSLocalizedString(@"OK", @"")
                                              otherButtonTitles: nil];
        [alert show];
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
            {   //Twitter
                if( [TWTweetComposeViewController canSendTweet]) {
                    TWTweetComposeViewController* vc = [TWTweetComposeViewController new];
                    [vc addURL: [NSURL URLWithString: self.detailItem.url]];
                    [vc setInitialText: self.detailItem.title];
                    vc.completionHandler = ^(TWTweetComposeViewControllerResult result) {
                        [self dismissViewControllerAnimated: YES completion: ^{
                            
                        }];
                    };
                    vc.modalPresentationStyle = UIModalPresentationFormSheet;
                    [self presentModalViewController: vc animated: YES];
                }
                else {
                    UIAlertView* alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Configure Twitter", @"")
                                                                    message: NSLocalizedString(@"Please configure a Twitter account in your device settings", @"")
                                                                   delegate: nil
                                                          cancelButtonTitle: NSLocalizedString(@"OK", @"")
                                                          otherButtonTitles: nil];
                    [alert show];
                }
                break;
            }
            case 1:
            {
                //Mail
                if( [MFMailComposeViewController canSendMail]) {
                    MFMailComposeViewController* vc = [MFMailComposeViewController new];
                    [vc setSubject: NSLocalizedString(@"The Joys of Code", @"")];
                    NSString* body = [NSString stringWithFormat: @"<a href=%@>%@</a>", self.detailItem.url, self.detailItem.title];
                    [vc setMessageBody: body isHTML: YES];
                    vc.mailComposeDelegate = self;
                    vc.modalPresentationStyle = UIModalPresentationFormSheet;
                    [self presentModalViewController: vc animated: YES];
                }
                else {
                    UIAlertView* alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Configure Mail", @"")
                                                                    message: NSLocalizedString(@"Please configure a Mail account in your device settings", @"")
                                                                   delegate: nil
                                                          cancelButtonTitle: NSLocalizedString(@"OK", @"")
                                                          otherButtonTitles: nil];
                    [alert show];
                }
                break;
            }
            default:
                break;
        }
    }
}

#pragma mark - MFMailComposeViewControllerDelegate
- (void) mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [self dismissViewControllerAnimated: YES completion: ^{
        
    }];
}

- (void)viewDidUnload {
    [self setIdeaView:nil];
    [self setIdeaButton:nil];
    [self setTitleReminderLabel:nil];
    [super viewDidUnload];
}

@end
