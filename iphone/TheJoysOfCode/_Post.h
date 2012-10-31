// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to Post.h instead.

#import <CoreData/CoreData.h>


extern const struct PostAttributes {
	__unsafe_unretained NSString *author;
	__unsafe_unretained NSString *hasDownloadedVideo;
	__unsafe_unretained NSString *picture;
	__unsafe_unretained NSString *primaryKey;
	__unsafe_unretained NSString *publishedDate;
	__unsafe_unretained NSString *title;
	__unsafe_unretained NSString *url;
} PostAttributes;

extern const struct PostRelationships {
} PostRelationships;

extern const struct PostFetchedProperties {
} PostFetchedProperties;










@interface PostID : NSManagedObjectID {}
@end

@interface _Post : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (PostID*)objectID;




@property (nonatomic, strong) NSString* author;


//- (BOOL)validateAuthor:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* hasDownloadedVideo;


@property BOOL hasDownloadedVideoValue;
- (BOOL)hasDownloadedVideoValue;
- (void)setHasDownloadedVideoValue:(BOOL)value_;

//- (BOOL)validateHasDownloadedVideo:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* picture;


//- (BOOL)validatePicture:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* primaryKey;


@property int64_t primaryKeyValue;
- (int64_t)primaryKeyValue;
- (void)setPrimaryKeyValue:(int64_t)value_;

//- (BOOL)validatePrimaryKey:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSDate* publishedDate;


//- (BOOL)validatePublishedDate:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* title;


//- (BOOL)validateTitle:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* url;


//- (BOOL)validateUrl:(id*)value_ error:(NSError**)error_;






@end

@interface _Post (CoreDataGeneratedAccessors)

@end

@interface _Post (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveAuthor;
- (void)setPrimitiveAuthor:(NSString*)value;




- (NSNumber*)primitiveHasDownloadedVideo;
- (void)setPrimitiveHasDownloadedVideo:(NSNumber*)value;

- (BOOL)primitiveHasDownloadedVideoValue;
- (void)setPrimitiveHasDownloadedVideoValue:(BOOL)value_;




- (NSString*)primitivePicture;
- (void)setPrimitivePicture:(NSString*)value;




- (NSNumber*)primitivePrimaryKey;
- (void)setPrimitivePrimaryKey:(NSNumber*)value;

- (int64_t)primitivePrimaryKeyValue;
- (void)setPrimitivePrimaryKeyValue:(int64_t)value_;




- (NSDate*)primitivePublishedDate;
- (void)setPrimitivePublishedDate:(NSDate*)value;




- (NSString*)primitiveTitle;
- (void)setPrimitiveTitle:(NSString*)value;




- (NSString*)primitiveUrl;
- (void)setPrimitiveUrl:(NSString*)value;




@end
