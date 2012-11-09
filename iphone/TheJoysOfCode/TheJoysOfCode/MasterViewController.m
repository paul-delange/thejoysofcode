//
//  MasterViewController.m
//  TheJoysOfCode
//
//  Created by Bob on 29/10/12.
//  Copyright (c) 2012 Tall Developments. All rights reserved.
//

#import "MasterViewController.h"

#import "DetailViewController.h"

#import <RestKit/UI.h>
#import "TFHpple.h"
#import "TimeScroller.h"

#import "GIFDownloader.h"
#import "TumblrObjectPaginator.h"

#import "Post.h"
#import "MKStoreManager.h"

#import <Parse/Parse.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>

@interface MasterViewController () <NSFetchedResultsControllerDelegate, UITableViewDataSource, UITabBarControllerDelegate, RKObjectPaginatorDelegate, RKConfigurationDelegate, TimeScrollerDelegate> {
    BOOL loading;
}

@property (strong, nonatomic) NSFetchedResultsController* tableController;
@property (strong, nonatomic) TumblrObjectPaginator* objectPaginator;
@property (strong, nonatomic) TimeScroller* timeScroller;
@property (weak, nonatomic) UIView* sectionHeaderView;

@end

@implementation MasterViewController

- (void)awakeFromNib
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
    }
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(reachabilityChanged:)
                                                 name: RKReachabilityWasDeterminedNotification
                                               object: nil];
    
    
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    
    if( [self respondsToSelector: @selector(refreshControl)]) {
        UIRefreshControl* refreshControl = [UIRefreshControl new];
        [refreshControl addTarget: self
                           action: @selector(refreshPushed:)
                 forControlEvents: UIControlEventValueChanged];
        self.refreshControl = refreshControl;
    }
    else {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemRefresh
                                                                                               target: self
                                                                                               action: @selector(refreshPushed:)];
    }
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"Back", @"")
                                                                             style: UIBarButtonItemStylePlain
                                                                            target: self.navigationController
                                                                            action: @selector(popViewControllerAnimated:)];
    
    self.title = NSLocalizedString(@"The Joys of Code", @"");
    
    NSFetchRequest* request = [Post fetchRequest];
    [request setPredicate: [NSPredicate predicateWithFormat: @"hasDownloadedVideo = YES"]];
    [request setSortDescriptors: @[[NSSortDescriptor sortDescriptorWithKey: @"publishedDate" ascending: NO]]];
    
    NSFetchedResultsController* frc = [[NSFetchedResultsController alloc] initWithFetchRequest: request
                                                                          managedObjectContext: [NSManagedObjectContext contextForCurrentThread]
                                                                            sectionNameKeyPath: nil
                                                                                     cacheName: @"PostCache"];
    frc.delegate = self;
    NSError* error = nil;
    [frc performFetch: &error];
    NSAssert(!error, @"Error: %@", error);
    self.tableController = frc;
    
    RKURL* patternURL = [kGlobalObjectManager().client.baseURL URLByAppendingResourcePath: @"/posts?api_key=2oiq2RJVxKq2Pk2jaHoyLvOwiknYNKiuBwaZIXljQhSyMHsmMb&limit=:perPage&offset=:currentObject"];
    self.objectPaginator = [[TumblrObjectPaginator alloc] initWithPatternURL: patternURL mappingProvider: kGlobalObjectManager().mappingProvider];
    self.objectPaginator.delegate = self;
    self.objectPaginator.configurationDelegate = self;
    
    self.timeScroller = [[TimeScroller alloc] initWithDelegate: self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSString* identifier = segue.identifier;
    if ([identifier isEqualToString:@"showDetail"]) {
        NSIndexPath* indexPath = [self.tableView indexPathForCell: sender];
        Post* post = [self.tableController objectAtIndexPath: indexPath];
        
        NSAssert([[NSFileManager defaultManager] fileExistsAtPath: post.pathToCachedVideo], @"No video for this post: %@", post);
        UIViewController* destination = segue.destinationViewController;
        DetailViewController* detailVC = nil;
        if( [destination isKindOfClass: [UINavigationController class]] ) {
            detailVC = ((UINavigationController*)destination).viewControllers[0];
        }
        else if( [destination isKindOfClass: [DetailViewController class]] ) {
            detailVC = (DetailViewController*)destination;
        }
        
        NSAssert([detailVC isKindOfClass: [DetailViewController class]], @"DetailVC is not correct type. We had: %@", detailVC);
        
        [detailVC setDetailItem: post];
    }
}*/

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (NSUInteger) supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    
    [super willRotateToInterfaceOrientation: toInterfaceOrientation duration: duration];
}

- (void) viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    CAGradientLayer* gradient = nil;
    for( CALayer* layer in self.sectionHeaderView.layer.sublayers ) {
        if( [layer isKindOfClass: [CAGradientLayer class]] ) {
            gradient = (CAGradientLayer*)layer;
            break;
        }
    }
    
    if( !gradient )
        gradient = [CAGradientLayer new];
    
    gradient.frame = CGRectMake(0, 0, CGRectGetWidth(self.sectionHeaderView.frame), CGRectGetHeight(self.sectionHeaderView.frame));
    gradient.colors = @[(id)[UIColor blackColor].CGColor, (id)[UIColor blackColor].CGColor, (id)[UIColor colorWithWhite: 0.0 alpha: 0.01].CGColor];
    gradient.locations = @[@(0), @(0.7), @(1.0)];
    [self.sectionHeaderView.layer insertSublayer: gradient atIndex: 0];
}

#pragma mark - Actions
- (IBAction) refreshPushed:(id)sender {
    if( !kGlobalObjectManager().client.isNetworkReachable ) {
        NSString* title = NSLocalizedString(@"The Joys of Code", @"");
        NSString* msg = NSLocalizedString(@"No Internet connection. Please connect and try again", @"");
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle: title
                                                        message: msg
                                                       delegate: nil
                                              cancelButtonTitle: NSLocalizedString(@"OK", @"")
                                              otherButtonTitles: nil];
        [alert show];
        return;
    }
    
    if( loading ) {
        if( [self respondsToSelector: @selector(refreshControl)] ) {
            [self.refreshControl endRefreshing];
        }
    }
    else {
        loading = YES;
        [self.objectPaginator loadPage: 0];
    }
}

- (IBAction) pushNotificationsTapped:(id)sender {
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes: UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert];
    
    [[NSUserDefaults standardUserDefaults] setBool: YES forKey: kUserPreferenceHasUsedPushNotifications];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self.tableView reloadSections: [NSIndexSet indexSetWithIndex: 0] withRowAnimation: UITableViewRowAnimationAutomatic];
}

- (void) reachabilityChanged: (NSNotification*) notification {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshPushed: nil];
    });
}

#pragma mark - NSFetchedResultsController
- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    switch (type) {
        case NSFetchedResultsChangeDelete:
        {
            [self.tableView deleteRowsAtIndexPaths: @[indexPath] withRowAnimation: UITableViewRowAnimationAutomatic];
            break;
        }
        case NSFetchedResultsChangeInsert:
        {
            [self.tableView insertRowsAtIndexPaths: @[newIndexPath] withRowAnimation: UITableViewRowAnimationAutomatic];
            break;
        }
        case NSFetchedResultsChangeMove:
        {
            [self.tableView moveRowAtIndexPath: indexPath toIndexPath: newIndexPath];
            break;
        }
        case NSFetchedResultsChangeUpdate:
        {
            [self.tableView reloadRowsAtIndexPaths: @[indexPath] withRowAnimation: UITableViewRowAnimationAutomatic];
            break;
        }
        default:
            break;
    }
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

#pragma mark - UITableViewDataSource
- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return self.tableController.sections.count;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id<NSFetchedResultsSectionInfo> info = self.tableController.sections[section];
    return [info numberOfObjects];
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier: @"PostCell"];
    Post* post = [self.tableController objectAtIndexPath: indexPath];
    
    cell.imageView.image = post.thumbnail;
    cell.textLabel.text = post.title;
    cell.detailTextLabel.text = post.author;
    
    return cell;
}

- (UIView*) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if( [[NSUserDefaults standardUserDefaults] boolForKey: kUserPreferenceHasUsedPushNotifications] ) {
        return nil;
    }
    else {
        UIView* headerView = [[UIView alloc] initWithFrame: CGRectMake(0, 0, CGRectGetWidth(tableView.frame), [self tableView: tableView heightForHeaderInSection: section])];
        headerView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        
        UILabel* pushText = [[UILabel alloc] initWithFrame: headerView.frame];
        pushText.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        pushText.numberOfLines = 2;
        pushText.textAlignment = UITextAlignmentCenter;
        pushText.textColor = [UIColor whiteColor];
        pushText.font = [UIFont fontWithName: @"Chalkduster" size: 12];
        pushText.text = NSLocalizedString(@"Tap here to enable Push Notifications to let you know when new videos are added!", @"");
        pushText.backgroundColor = [UIColor clearColor];
        [headerView addSubview: pushText];
        
        UITapGestureRecognizer* recognizer = [[UITapGestureRecognizer alloc] initWithTarget: self
                                                                                     action: @selector(pushNotificationsTapped:)];
        [headerView addGestureRecognizer: recognizer];
        
        self.sectionHeaderView = headerView;
        
        return headerView;
    }
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [[NSUserDefaults standardUserDefaults] boolForKey: kUserPreferenceHasUsedPushNotifications] ? 0 : 50.f;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.f;
}

#pragma mark - UITableViewDelegate
- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static const NSInteger kFreeVideoLimit = 50;
    NSInteger watchedCount = [[NSUserDefaults standardUserDefaults] integerForKey: kUserPreferenceHasWatchedVideoCount];
    NSInteger warningCount = floorf( kFreeVideoLimit * .75 );
    
    if( watchedCount == warningCount ) {
        NSString* title = NSLocalizedString(@"Free Videos", @"");
        NSString* msg = NSLocalizedString(@"You have only a few more videos to watch before we will ask you to start paying. If you enjoy this app please consider supporting us in this way, otherwise choose your next videos well!", @"");
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle: title
                                                        message: msg
                                                       delegate: nil
                                              cancelButtonTitle: NSLocalizedString(@"OK", @"")
                                              otherButtonTitles: nil];
        [alert show];
        [tableView deselectRowAtIndexPath: indexPath animated: YES];
        
        NSUInteger count = [[NSUserDefaults standardUserDefaults] integerForKey: kUserPreferenceHasWatchedVideoCount];
        count++;
        [[NSUserDefaults standardUserDefaults] setInteger: count forKey: kUserPreferenceHasWatchedVideoCount];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        return;
    }
    
    if( watchedCount > kFreeVideoLimit ) {
        if( !isPro() ) {
            [[MKStoreManager sharedManager] buyFeature: kSubscriptionIdentifier
                                            onComplete: ^(NSString *purchasedFeature,
                                                          NSData *purchasedReceipt,
                                                          NSArray *availableDownloads) {
                                                
                                                NSAssert([purchasedFeature isEqualToString: kSubscriptionIdentifier], @"Bad purchase of: %@", purchasedFeature);
                                                
                                                if( !purchasedReceipt ) {
                                                    NSString* title = NSLocalizedString(@"Error occurred", @"");
                                                    NSString* msg = NSLocalizedString(@"Oh oh, something has gone wrong and your purchase could not be verified. Please try again", @"");
                                                    UIAlertView* alert = [[UIAlertView alloc] initWithTitle: title
                                                                                                    message: msg
                                                                                                   delegate: nil
                                                                                          cancelButtonTitle: NSLocalizedString(@"OK", @"")
                                                                                          otherButtonTitles: nil];
                                                    [alert show];
                                                }
                                                
                                            } onCancelled:^{
                                                NSString* title = NSLocalizedString(@"Error occurred", @"");
                                                NSString* msg = NSLocalizedString(@"Oh oh, something has gone wrong and your purchase could not be verified. Please try again", @"");
                                                UIAlertView* alert = [[UIAlertView alloc] initWithTitle: title
                                                                                                message: msg
                                                                                               delegate: nil
                                                                                      cancelButtonTitle: NSLocalizedString(@"OK", @"")
                                                                                      otherButtonTitles: nil];
                                                [alert show];
                                            }];
            
            [tableView deselectRowAtIndexPath: indexPath animated: YES];
            return;
        }
    }
    
    Post* post = [self.tableController objectAtIndexPath: indexPath];
    
    NSAssert([[NSFileManager defaultManager] fileExistsAtPath: post.pathToCachedVideo], @"No video for this post: %@", post);
    
    if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
        [self.detailViewController setDetailItem: post];
    else {
        DetailViewController* vc = [self.storyboard instantiateViewControllerWithIdentifier: @"DetailViewController"];
        [vc setDetailItem: post];
        [self.navigationController pushViewController: vc animated: YES];
    }
}

#pragma mark - RKConfigurationDelegate
- (void)configureObjectLoader:(RKObjectLoader *)loader {
    loader.onWillMapData = ^(id* mappableData) {
        NSMutableDictionary* response = [[*mappableData valueForKey: @"response"] mutableCopy];
        NSMutableArray* posts = [[response valueForKeyPath: @"posts"] mutableCopy];
        for(NSUInteger i = 0; i <posts.count;i++) {
            NSDictionary* post = [posts objectAtIndex: i];
            NSString* body = post[@"body"];
            TFHpple* doc = [[TFHpple alloc] initWithHTMLData: [body dataUsingEncoding: NSUTF8StringEncoding]];
            NSString* src = [[[doc searchWithXPathQuery: @"//img/@src"] lastObject] firstChild].content;
            NSString* author = [[[doc searchWithXPathQuery: @"//p/em"] lastObject] firstChild].content;
            
            NSAssert(src, @"%@ does not contain any images", body);
            
            NSMutableDictionary* mutablePost = [post mutableCopy];
            mutablePost[@"picture"] = src;
            if( author )
                mutablePost[@"author"] = author;
            
            NSUInteger index = [posts indexOfObject: post];
            [posts replaceObjectAtIndex: index withObject: mutablePost];
        }
        
        [response setObject: posts forKey: @"posts"];
        
        NSMutableDictionary* newData = [*mappableData mutableCopy];
        [newData setObject: response forKey: @"response"];
        *mappableData = newData;
    };
}

#pragma mark - RKObjectPaginatorDelegate
- (void) paginator:(RKObjectPaginator *)paginator didLoadObjects:(NSArray *)objects forPage:(NSUInteger)page {
    
    for(Post* post in objects) {
        if( [post isKindOfClass: [Post class]] && !post.hasDownloadedVideoValue ) {
            [GIFDownloader sendAsynchronousRequest: post.picture
                                  downloadFilePath: post.pathToCachedVideo
                                 thumbnailFilePath: post.pathToThumbnail
                                         completed: ^(NSString *outputFilePath, NSError *error) {
                                             Post* local = [Post findFirstByAttribute: @"primaryKey" withValue: post.primaryKey];
                                             if( error ) {
                                                 [Flurry logError: @"Decoder" message: @"Error" error: error];
                                             }
                                             else {
                                                 local.hasDownloadedVideoValue = YES;
                                             }
                                             
                                             [kGlobalObjectManager().objectStore save: nil];
                                         }];
        }
    }
    
    if( paginator.hasNextPage ) {
        [paginator loadNextPage];
    }
    else {
        loading = NO;
        if( [self respondsToSelector: @selector(refreshControl)]) {
            [self.refreshControl endRefreshing];
        }
    }
}

- (void) paginator:(RKObjectPaginator *)paginator didFailWithError:(NSError *)error objectLoader:(RKObjectLoader *)loader {
    
}

#pragma mark - TimeScrollerDelegate
- (UITableView*) tableViewForTimeScroller:(TimeScroller *)timeScroller {
    return self.tableView;
}

- (NSDate*) dateForCell:(UITableViewCell *)cell {
    NSIndexPath* indexPath = [self.tableView indexPathForCell: cell];
    Post* post = [self.tableController objectAtIndexPath: indexPath];
    return post.publishedDate;
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self.timeScroller scrollViewDidScroll];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self.timeScroller scrollViewDidEndDecelerating];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.timeScroller scrollViewWillBeginDragging];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        [self.timeScroller scrollViewDidEndDecelerating];
    }
}
@end
