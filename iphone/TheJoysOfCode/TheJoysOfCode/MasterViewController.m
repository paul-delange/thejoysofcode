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

@interface MasterViewController () <RKFetchedResultsTableControllerDelegate>
@property (strong, nonatomic) RKFetchedResultsTableController* tableController;
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
    self.navigationItem.leftBarButtonItem = self.editButtonItem;

    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject:)];
    self.navigationItem.rightBarButtonItem = addButton;
    self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    
    self.tableController = [kGlobalObjectManager() fetchedResultsTableControllerForTableViewController: self];
    self.tableController.pullToRefreshEnabled = YES;
    self.tableController.autoRefreshFromNetwork = YES;
    self.tableController.autoRefreshRate = 60*60;
    self.tableController.resourcePath = @"/posts?api_key=2oiq2RJVxKq2Pk2jaHoyLvOwiknYNKiuBwaZIXljQhSyMHsmMb";
    self.tableController.delegate = self;
    RKTableViewCellMapping* cellMapping = [RKTableViewCellMapping cellMappingForReuseIdentifier: @"PostCellIdentifier"];
    [cellMapping mapKeyPathsToAttributes:
     @"title", @"textLabel.text",
     nil];
    
    [self.tableController mapObjectsWithClassName: @"Post" toTableCellsWithMapping: cellMapping];
    [self.tableController loadTable];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        NSDate *object = [self.tableController objectForRowAtIndexPath: indexPath];
        [[segue destinationViewController] setDetailItem:object];
    }
}

#pragma mark - RKFetchedResultsTableControllerDelegate
- (void)tableController:(RKAbstractTableController *)tableController willLoadTableWithObjectLoader:(RKObjectLoader *)objectLoader {
    objectLoader.onWillMapData = ^(id* mappableData) {
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
}

- (void)tableController:(RKAbstractTableController *)tableController didLoadTableWithObjectLoader:(RKObjectLoader *)objectLoader {
    
}

- (void)tableControllerDidFinishLoad:(RKAbstractTableController *)tableController {
    
}

- (void)tableController:(RKAbstractTableController *)tableController didFailLoadWithError:(NSError *)error {
    
}

- (void)tableControllerDidCancelLoad:(RKAbstractTableController *)tableController {
    
}

- (void)tableControllerDidFinalizeLoad:(RKAbstractTableController *)tableController {
    
}

- (void)tableControllerDidBecomeOnline:(RKAbstractTableController *)tableController {
    
}

- (void)tableControllerDidBecomeOffline:(RKAbstractTableController *)tableController {
    
}

@end
