//
//  AppDelegate.m
//  TheJoysOfCode
//
//  Created by Bob on 29/10/12.
//  Copyright (c) 2012 Tall Developments. All rights reserved.
//

#import "AppDelegate.h"
#import "ContentProvider.h"
#import "MappingProvider.h"

#import "Post.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
#if DEBUG
    //See RestKit/Support/lcl_config_components.h
    RKLogConfigureByName("RestKit", RKLogLevelCritical);
    RKLogConfigureByName("RestKit/Network", RKLogLevelCritical);
    RKLogConfigureByName("RestKit/Network/Queue", RKLogLevelCritical);
    RKLogConfigureByName("RestKit/Network/Reachability", RKLogLevelCritical);
    RKLogConfigureByName("RestKit/ObjectMapping", RKLogLevelCritical);
    RKLogConfigureByName("RestKit/CoreData", RKLogLevelCritical);
#else
    RKLogConfigureByName("RestKit", RKLogLevelOff);
#endif
    
    kGlobalObjectManager();
    
    // Override point for customization after application launch.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
        UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
        splitViewController.delegate = (id)navigationController.topViewController;
    }
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (RKObjectManager*) objectManager {
    if( !_objectManager ) {
        _objectManager = [RKObjectManager objectManagerWithBaseURLString: [ContentProvider baseURL]];
        _objectManager.objectStore = [RKManagedObjectStore objectStoreWithStoreFilename: @"DataBase.sqlite"];
        _objectManager.objectStore.cacheStrategy = [RKFetchRequestManagedObjectCache new];
        _objectManager.mappingProvider = [MappingProvider mappingProvider: ^(MappingProvider *provider) {
            RKManagedObjectStore* store = _objectManager.objectStore;
            
            RKManagedObjectMapping* postMapping = [RKManagedObjectMapping mappingForEntityWithName: @"Post"
                                                                              inManagedObjectStore: store];
            postMapping.primaryKeyAttribute = @"primaryKey";
            [postMapping mapAttributes: @"title", @"picture", @"author", nil];
            [postMapping mapKeyPathsToAttributes:
             @"id", @"primaryKey",
             @"date", @"publishedDate",
             @"post_url", @"url",
             nil];
            
            RKObjectMapping* paginationMapping = [RKObjectMapping mappingForClass: [RKObjectPaginator class]];
            [paginationMapping mapKeyPathsToAttributes:
             @"response.total_posts", @"objectCount",
             nil];
            
            [provider setObjectMapping: postMapping forKeyPath: @"response.posts"];
            
            provider.paginationMapping = paginationMapping;
            
        }];
    }
    
    return _objectManager;
}

@end


RKObjectManager* kGlobalObjectManager(void) {
    AppDelegate* app = ((AppDelegate*)[[UIApplication sharedApplication] delegate]);
    return app.objectManager;
}