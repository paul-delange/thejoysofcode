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
#import "Post.h"

@interface MasterViewController () <NSFetchedResultsControllerDelegate, UITableViewDataSource, UITabBarControllerDelegate>
@property (strong, nonatomic) NSFetchedResultsController* tableController;
@property (strong, nonatomic) RKObjectPaginator* objectPaginator;
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
    [kGlobalObjectManager() loadObjectsAtResourcePath: @"/posts?api_key=2oiq2RJVxKq2Pk2jaHoyLvOwiknYNKiuBwaZIXljQhSyMHsmMb"
                                           usingBlock: ^(RKObjectLoader *loader) {
                                               loader.onDidLoadObjects = ^(NSArray* objects) {
                                                   for(Post* post in objects) {
                                                       [GIFDownloader sendAsynchronousRequest: post.picture
                                                                             downloadFilePath: post.pathToCachedVideo
                                                                                    completed: ^(NSString *outputFilePath, NSError *error) {
                                                                                        post.hasDownloadedVideo = @YES;
                                                                                    }];
                                                   }
                                                   [kGlobalObjectManager().objectStore save: nil];
                                               };
                                               loader.onWillMapData = ^(id* mappableData) {
                                                   NSMutableDictionary* response = [[*mappableData valueForKey: @"response"] mutableCopy];
                                                   NSMutableArray* posts = [[response valueForKeyPath: @"posts"] mutableCopy];
                                                   for(NSUInteger i = 0; i <posts.count;i++) {
                                                       NSDictionary* post = [posts objectAtIndex: i];
                                                       NSString* body = post[@"body"];
                                                       TFHpple* doc = [[TFHpple alloc] initWithHTMLData: [body dataUsingEncoding: NSUTF8StringEncoding]];
                                                       NSString* src = [[[doc searchWithXPathQuery: @"//img/@src"] lastObject] firstChild].content;
                                                       NSString* author = [[[doc searchWithXPathQuery: @"//p/em"] lastObject] firstChild].content;
                                                       
                                                       NSLog(@"Src: %@", src);
                                                       NSLog(@"Author: %@", author);
                                                       
                                                       NSAssert(src, @"%@ does not contain any images", body);
                                                       //NSAssert(author, @"%@ does not contain an author", body);
                                                       
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
                                                   
                                                   NSLog(@"Response: %@", *mappableData);
                                               };
                                           }];
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
    return  self.tableController.sections.count;
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

@end
