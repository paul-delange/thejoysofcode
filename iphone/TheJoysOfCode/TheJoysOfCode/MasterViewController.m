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

@interface MasterViewController () <NSFetchedResultsControllerDelegate, UITableViewDataSource, UITabBarControllerDelegate, RKObjectPaginatorDelegate, RKConfigurationDelegate, TimeScrollerDelegate, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UISearchDisplayDelegate, UISearchBarDelegate> {
    BOOL loading;
    NSMutableArray* searchItems;
}

@property (strong, nonatomic) NSFetchedResultsController* tableController;
@property (strong, nonatomic) UISearchDisplayController* searchController;
@property (strong, nonatomic) TumblrObjectPaginator* objectPaginator;
@property (strong, nonatomic) TimeScroller* timeScroller;
@property (weak, nonatomic) UIView* sectionHeaderView;
@property (weak, nonatomic) UISearchBar* searchBar;

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
    
    searchItems = [NSMutableArray new];
    
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
    
    UISearchBar* searchBar = [[UISearchBar alloc] initWithFrame: CGRectMake(0, 0, CGRectGetWidth(self.view.frame), 44)];
    searchBar.barStyle = UIBarStyleBlackOpaque;
    self.searchController = [[UISearchDisplayController alloc] initWithSearchBar: searchBar contentsController: self];
    self.searchController.delegate = self;
    self.searchController.searchResultsDataSource = self;
    self.searchController.searchResultsDelegate = self;
    self.tableView.tableHeaderView = searchBar;
    self.searchBar = searchBar;
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
    return tableView == self.tableView ? self.tableController.sections.count : 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id<NSFetchedResultsSectionInfo> info = self.tableController.sections[section];
    return tableView == self.tableView ? [info numberOfObjects] : searchItems.count;
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier: @"PostCell"];
    
    if( !cell ) {
        cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleSubtitle reuseIdentifier: @"PostCell"];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
    }
    
    Post* post = tableView == self.tableView ? [self.tableController objectAtIndexPath: indexPath] : searchItems[indexPath.row];
    
    cell.imageView.image = post.thumbnail;
    cell.textLabel.text = post.title;
    cell.detailTextLabel.text = post.author;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (UIView*) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if( [[NSUserDefaults standardUserDefaults] boolForKey: kUserPreferenceHasUsedPushNotifications] || tableView != self.tableView) {
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
    return tableView == self.tableView ? [[NSUserDefaults standardUserDefaults] boolForKey: kUserPreferenceHasUsedPushNotifications] ? 0 : 50.f : 0.f;
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
        
        watchedCount++;
        [[NSUserDefaults standardUserDefaults] setInteger: watchedCount forKey: kUserPreferenceHasWatchedVideoCount];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        return;
    }
    
    if( watchedCount > kFreeVideoLimit ) {
#if TARGET_IPHONE_SIMULATOR
        
#else
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
#endif
    }
    
    Post* post = tableView == self.tableView ? [self.tableController objectAtIndexPath: indexPath] : searchItems[indexPath.row];
    
    NSAssert([[NSFileManager defaultManager] fileExistsAtPath: post.pathToCachedVideo], @"No video for this post: %@", post);
    
    if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
        [self.detailViewController setDetailItem: post];
    else {
        DetailViewController* vc = [self.storyboard instantiateViewControllerWithIdentifier: @"DetailViewController"];
        [vc setDetailItem: post];
        
        if( SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0")) {
            NSDictionary* options = @{
            UIPageViewControllerOptionSpineLocationKey : @(UIPageViewControllerSpineLocationNone),
            UIPageViewControllerOptionInterPageSpacingKey : @(0)
            };
            
            UIPageViewController* pageViewController = [[UIPageViewController alloc] initWithTransitionStyle: UIPageViewControllerTransitionStyleScroll
                                                                                       navigationOrientation: UIPageViewControllerNavigationOrientationHorizontal
                                                                                                     options: options];
            pageViewController.dataSource = self;
            pageViewController.delegate = self;
            [pageViewController setViewControllers: @[vc]
                                         direction: UIPageViewControllerNavigationDirectionForward
                                          animated: NO
                                        completion: ^(BOOL finished) {
                                            
                                        }];
            [self.navigationController pushViewController: pageViewController animated: YES];
            
        }
        else {
            [self.navigationController pushViewController: vc animated: YES];
        }
    }
    
    [self.searchBar resignFirstResponder];
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

#pragma mark - UIPageViewControllerDataSource
- (UIViewController*) pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    NSAssert([viewController isKindOfClass: [DetailViewController class]], @"%@ was not of type DetailViewController", viewController);
    DetailViewController* current = (DetailViewController*)viewController;
    NSIndexPath* currentPath = [self.tableController indexPathForObject: current.detailItem];
    
    if( currentPath.row >= [self tableView: self.tableView numberOfRowsInSection: 0] ) {
        return nil;
    }
    else {
        NSIndexPath* nextPath = [NSIndexPath indexPathForRow: currentPath.row+1 inSection: currentPath.section];
        Post* post = [self.tableController objectAtIndexPath: nextPath];
        DetailViewController* vc = [self.storyboard instantiateViewControllerWithIdentifier: @"DetailViewController"];
        [vc setDetailItem: post];
        return vc;
    }
}

- (UIViewController*) pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    NSAssert([viewController isKindOfClass: [DetailViewController class]], @"%@ was not of type DetailViewController", viewController);
    DetailViewController* current = (DetailViewController*)viewController;
    NSIndexPath* currentPath = [self.tableController indexPathForObject: current.detailItem];
    
    NSLog(@"Row: %d Section: %d", currentPath.row, currentPath.section);
    
    if( currentPath.row < 1 ) {
        return nil;
    }
    else {
        NSIndexPath* nextPath = [NSIndexPath indexPathForRow: currentPath.row-1 inSection: currentPath.section];
        Post* post = [self.tableController objectAtIndexPath: nextPath];
        DetailViewController* vc = [self.storyboard instantiateViewControllerWithIdentifier: @"DetailViewController"];
        [vc setDetailItem: post];
        return vc;
    }
}

#pragma mark - UISearchDisplayControllerDelegate
- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [searchItems removeAllObjects];
    NSPredicate* searchPredicate = [NSPredicate predicateWithFormat: @"title CONTAINS[cd] %@ AND hasDownloadedVideo = YES", searchString];
    NSArray* allItems = self.tableController.fetchedObjects;
    NSArray* filtered = [allItems filteredArrayUsingPredicate: searchPredicate];
    [searchItems addObjectsFromArray: filtered];
    return YES;
}

@end
