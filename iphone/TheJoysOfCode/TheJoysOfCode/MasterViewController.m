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
                                                                                        NSLog(@"Saved: %@", outputFilePath);
                                                                                    }];
                                                   }
                                               };
                                               loader.onWillMapData = ^(id* mappableData) {
                                                   
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
