//
//  TumblrObjectPaginator.m
//  TheJoysOfCode
//
//  Created by Paul de Lange on 31/10/12.
//  Copyright (c) 2012 Tall Developments. All rights reserved.
//

#import "TumblrObjectPaginator.h"

@interface TumblrObjectPaginator () {
    NSUInteger pageCount;
    NSUInteger currentPage;
}

@end

@implementation TumblrObjectPaginator

- (NSUInteger) currentObject {
    return MIN(self.perPage * self.currentPage, self.objectCount);
}

- (void)objectLoader:(RKObjectLoader *)loader willMapData:(inout id *)mappableData
{
    NSError *error = nil;
    RKObjectMappingOperation *mappingOperation = [RKObjectMappingOperation mappingOperationFromObject:*mappableData
                                                                                             toObject:self
                                                                                          withMapping: kGlobalObjectManager().mappingProvider.paginationMapping];
    BOOL success = [mappingOperation performMapping:&error];
    if (!success) {
        pageCount = currentPage = 0;
        RKLogError(@"Paginator didn't map info to compute page count. Assuming no pages.");
    } else if (self.perPage && [self hasObjectCount]) {
        float objectCountFloat = self.objectCount;
        
        NSDictionary* queryParams = [loader.URL queryParameters];
        currentPage = self.perPage * [queryParams[@"offset"] integerValue];
        pageCount = ceilf(objectCountFloat / self.perPage);
        RKLogInfo(@"Paginator objectCount: %ld pageCount: %ld", (long)self.objectCount, (long)self.pageCount);
    } else {
        NSAssert(NO, @"Paginator perPage set is 0.");
        RKLogError(@"Paginator perPage set is 0.");
    }
}

- (BOOL) hasNextPage {
    NSAssert(self.isLoaded, @"Cannot determine hasNextPage: paginator is not loaded.");
    NSAssert([self hasPageCount], @"Cannot determine hasNextPage: page count is not known.");
    
    return self.currentObject < self.objectCount;
}

- (NSUInteger) pageCount {
    return ceil(self.objectCount / self.perPage);
}

@end
