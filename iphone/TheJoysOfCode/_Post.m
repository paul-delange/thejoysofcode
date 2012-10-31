// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to Post.m instead.

#import "_Post.h"

const struct PostAttributes PostAttributes = {
	.author = @"author",
	.hasDownloadedVideo = @"hasDownloadedVideo",
	.picture = @"picture",
	.primaryKey = @"primaryKey",
	.publishedDate = @"publishedDate",
	.title = @"title",
	.url = @"url",
};

const struct PostRelationships PostRelationships = {
};

const struct PostFetchedProperties PostFetchedProperties = {
};

@implementation PostID
@end

@implementation _Post

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"Post" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"Post";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"Post" inManagedObjectContext:moc_];
}

- (PostID*)objectID {
	return (PostID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"hasDownloadedVideoValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"hasDownloadedVideo"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"primaryKeyValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"primaryKey"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}

	return keyPaths;
}




@dynamic author;






@dynamic hasDownloadedVideo;



- (BOOL)hasDownloadedVideoValue {
	NSNumber *result = [self hasDownloadedVideo];
	return [result boolValue];
}

- (void)setHasDownloadedVideoValue:(BOOL)value_ {
	[self setHasDownloadedVideo:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveHasDownloadedVideoValue {
	NSNumber *result = [self primitiveHasDownloadedVideo];
	return [result boolValue];
}

- (void)setPrimitiveHasDownloadedVideoValue:(BOOL)value_ {
	[self setPrimitiveHasDownloadedVideo:[NSNumber numberWithBool:value_]];
}





@dynamic picture;






@dynamic primaryKey;



- (int64_t)primaryKeyValue {
	NSNumber *result = [self primaryKey];
	return [result longLongValue];
}

- (void)setPrimaryKeyValue:(int64_t)value_ {
	[self setPrimaryKey:[NSNumber numberWithLongLong:value_]];
}

- (int64_t)primitivePrimaryKeyValue {
	NSNumber *result = [self primitivePrimaryKey];
	return [result longLongValue];
}

- (void)setPrimitivePrimaryKeyValue:(int64_t)value_ {
	[self setPrimitivePrimaryKey:[NSNumber numberWithLongLong:value_]];
}





@dynamic publishedDate;






@dynamic title;






@dynamic url;











@end
