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
    /*[[NSNotificationCenter defaultCenter] addObserver: [Post class]
                                             selector: @selector(objectContextHasSaved:)
                                                 name: NSManagedObjectContextDidSaveNotification
                                               object: nil];
     */
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
/*
+ (NSDate*) lastPostDate {
    NSFetchRequest* request = [self fetchRequest];
    [request setResultType: NSDictionaryResultType];
    
    NSExpression* keyPathExpression = [NSExpression expressionForKeyPath: @"publishedDate"];
    NSExpression* maxExpression = [NSExpression expressionForFunction: @"max:" arguments: @[keyPathExpression]];
    NSExpressionDescription* expressionDescription = [NSExpressionDescription new];
    [expressionDescription setName: @"maxDate"];
    [expressionDescription setExpression: maxExpression];
    [expressionDescription setExpressionResultType: NSDateAttributeType];
    
    [request setPropertiesToFetch: @[expressionDescription]];
    
    NSArray* objs = [self executeFetchRequest: request];
    if( objs.count ) {
        return [objs[0] valueForKeyPath: @"maxDate"];
    }
    return nil;
}*/

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
    /*
    NSURL* url = [NSURL fileURLWithPath: self.pathToCachedVideo];
    
    NSAssert(url, @"Could not create a url for: %@", self.pathToCachedVideo);
    
    AVAsset* asset = [AVAsset assetWithURL: url];
    AVAssetImageGenerator* imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset: asset];
    CMTime duration = asset.duration;
    CMTime time = CMTimeMultiply(duration, 0.1);
    CGImageRef cgImg = [imageGenerator copyCGImageAtTime: time actualTime: NULL error: nil];
    UIImage* uiImg = [UIImage imageWithCGImage: cgImg];
    CGImageRelease(cgImg);
    return uiImg;
     */
    return [UIImage imageWithContentsOfFile: self.pathToThumbnail];
}

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
                                             [kGlobalObjectManager().objectStore save: nil];
                                         }
                                         
                                         //BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath: outputFilePath];
                                         //NSLog(@"File %@", exists?@"exists":@"doesn't exist");
                                     }];

    }
    
    [super willSave];
}

@end
