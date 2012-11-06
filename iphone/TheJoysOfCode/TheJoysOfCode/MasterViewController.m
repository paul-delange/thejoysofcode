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

#import "GIFDownloader.h"
#import "TumblrObjectPaginator.h"

#import "Post.h"

@interface MasterViewController () <NSFetchedResultsControllerDelegate, UITableViewDataSource, UITabBarControllerDelegate, RKObjectPaginatorDelegate, RKConfigurationDelegate>
@property (strong, nonatomic) NSFetchedResultsController* tableController;
@property (strong, nonatomic) TumblrObjectPaginator* objectPaginator;
@end

@implementation MasterViewController

- (void)awakeFromNib
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
    }
    
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemRefresh
                                                                                           target: self
                                                                                           action: @selector(refreshPushed:)];
    
    self.title = NSLocalizedString(@"Les joies du code", @"");
    
    NSFetchRequest* request = [Post fetchRequest];
    [request setPredicate: [NSPredicate predicateWithFormat: @"hasDownloadedVideo = YES"]];
    [request setSortDescriptors: @[[NSSortDescriptor sortDescriptorWithKey: @"publishedDate" ascending: YES]]];
    
    NSFetchedResultsController* frc = [[NSFetchedResultsController alloc] initWithFetchRequest: request
                                                                          managedObjectContext: [NSManagedObjectContext contextForCurrentThread]
                                                                            sectionNameKeyPath: nil
                                                                                     cacheName: @"PostCache"];
    frc.delegate = self;
    NSError* error = nil;
    [frc performFetch: &error];
    NSAssert(!error, @"Error: %@", error);
    self.tableController = frc;
    
    NSURL* patternURL = [kGlobalObjectManager().client.baseURL URLByAppendingResourcePath: @"/posts?api_key=2oiq2RJVxKq2Pk2jaHoyLvOwiknYNKiuBwaZIXljQhSyMHsmMb&limit=:perPage&offset=:currentObject"];
    self.objectPaginator = [[TumblrObjectPaginator alloc] initWithPatternURL: patternURL mappingProvider: kGlobalObjectManager().mappingProvider];
    self.objectPaginator.delegate = self;
    self.objectPaginator.configurationDelegate = self;
    
    [self refreshPushed: self.navigationItem.rightBarButtonItem];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        [[segue destinationViewController] setDetailItem:sender];
    }
}

#pragma mark - Actions
- (IBAction) refreshPushed:(id)sender {
    [self.objectPaginator loadPage: 0];
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
    
    return cell;
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
    
}

- (void) paginator:(RKObjectPaginator *)paginator didFailWithError:(NSError *)error objectLoader:(RKObjectLoader *)loader {
    
}

@end
