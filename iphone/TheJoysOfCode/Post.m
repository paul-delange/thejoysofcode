#import "Post.h"
#import "GIFDownloader.h"

#import <Parse/Parse.h>
#import <RestKit/RestKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@implementation Post
@dynamic hasDownloadedVideo;

// Custom logic goes here.

+ (void) load {
    @autoreleasepool {
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *videoPath = [documentsDirectory stringByAppendingPathComponent:@"Videos"];
        NSString* thumbPath = [documentsDirectory stringByAppendingPathComponent: @"Thumbs"];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:videoPath])
            [[NSFileManager defaultManager] createDirectoryAtPath:videoPath
                                      withIntermediateDirectories: YES
                                                       attributes: nil
                                                            error: nil];
        if (![[NSFileManager defaultManager] fileExistsAtPath:thumbPath])
            [[NSFileManager defaultManager] createDirectoryAtPath:thumbPath
                                      withIntermediateDirectories: YES
                                                       attributes: nil
                                                            error: nil];
         
    }
}

+ (void) initialize {
    [[NSNotificationCenter defaultCenter] addObserver: [Post class]
                                             selector: @selector(objectContextHasSaved:)
                                                 name: NSManagedObjectContextDidSaveNotification
                                               object: nil];
     
    [[NSNotificationCenter defaultCenter] addObserver: [self class]
                                             selector: @selector(objectContextWillSave:)
                                                 name: NSManagedObjectContextWillSaveNotification
                                               object: nil];
}

+ (void) objectContextHasSaved: (NSNotification*) notification {
    
}

+ (void) objectContextWillSave: (NSNotification*) notification {
        NSSet* deletedObjects = [notification.userInfo objectForKey: NSDeletedObjectsKey];
        NSSet* posts = [deletedObjects filteredSetUsingPredicate: [NSPredicate predicateWithFormat: @"SELF isKindOfClass: %@", self]];
        
        for(Post* post in posts) {
            NSString* path = [post pathToCachedVideo];
            if( [[NSFileManager defaultManager] fileExistsAtPath: path] ) {
                NSError* error=nil;
                [[NSFileManager defaultManager] removeItemAtPath: path error: &error];
            }
        }
}

- (NSString*) pathToCachedVideo {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:@"Videos"];
    
    if( self.primaryKey ) {
        NSString* fileName = [NSString stringWithFormat: @"%@.mp4", self.primaryKey];
        return [dataPath stringByAppendingPathComponent: fileName];
    }
    else {
        return nil;
    }
}

- (NSString*) pathToThumbnail {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:@"Thumbs"];
    
    if( self.primaryKey ) {
        NSString* fileName = [NSString stringWithFormat: @"%@.png", self.primaryKey];
        return [dataPath stringByAppendingPathComponent: fileName];
    }
    else {
        return nil;
    }
}

- (UIImage*) thumbnail {
    return [UIImage imageWithContentsOfFile: self.pathToThumbnail];
}
/*
- (void) willSave {
    NSDictionary* changed = self.changedValues;
    if( [[changed objectForKey: @"picture"] length] && self.primaryKeyValue) {
        [GIFDownloader sendAsynchronousRequest: self.picture
                              downloadFilePath: self.pathToCachedVideo
                             thumbnailFilePath: self.pathToThumbnail
                                     completed: ^(NSString *outputFilePath, NSError *error) {
                                         Post* post = [Post findFirstByAttribute: @"primaryKey" withValue: self.primaryKey];
                                         if( !error ) {
                                             post.hasDownloadedVideoValue = YES; 
                                         }
                                         else {
                                             [post deleteEntity];
                                         }
                                         [kGlobalObjectManager().objectStore save: nil];
                                     }];

    }
    
    [super willSave];
}*/

@end
