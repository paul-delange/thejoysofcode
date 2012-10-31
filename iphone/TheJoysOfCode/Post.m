#import "Post.h"
#import "GIFDownloader.h"

@implementation Post

// Custom logic goes here.

+ (void) load {
    [[NSNotificationCenter defaultCenter] addObserver: [self class]
                                             selector: @selector(objectContextHasSaved:)
                                                 name: NSManagedObjectContextDidSaveNotification
                                               object: nil];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:@"Videos"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:dataPath])
        [[NSFileManager defaultManager] createDirectoryAtPath:dataPath
                                  withIntermediateDirectories: YES
                                                   attributes: nil
                                                        error: nil];
}

+ (void) objectContextHasSaved: (NSNotification*) notification {
    NSArray* deletedObjects = [notification.userInfo objectForKey: NSDeletedObjectsKey];
    NSArray* posts = [deletedObjects filteredArrayUsingPredicate: [NSPredicate predicateWithFormat: @"SELF isKindOfClass: %@", self]];
    
    for(Post* post in posts) {
        NSString* path = [post pathToCachedVideo];
        
        NSLog(@"Deleting object at path: %@", path);
        
        if( [[NSFileManager defaultManager] fileExistsAtPath: path] ) {
            NSError* error=nil;
            [[NSFileManager defaultManager] removeItemAtPath: path error: &error];
            
            if( error ) {
                NSLog(@"Error deleting file: %@", error);
            }
        }
    }
}

- (NSString*) pathToCachedVideo {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:@"Videos"];
    
   // NSAssert([[NSFileManager defaultManager] fileExistsAtPath: dataPath], @"%@ does not exist", dataPath);
   // NSAssert(self.primaryKey, @"There must be a primary key to save correctly: %@", self);
    
    if( self.primaryKey ) {
        NSString* fileName = [NSString stringWithFormat: @"%@.mp4", self.primaryKey];
        return [dataPath stringByAppendingPathComponent: fileName];
    }
    else {
        return nil;
    }
}

@end
