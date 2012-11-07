#import "_Post.h"

@interface Post : _Post {}
// Custom logic goes here.
- (NSString*) pathToCachedVideo;
- (NSString*) pathToThumbnail;
- (UIImage*) thumbnail;

@end
