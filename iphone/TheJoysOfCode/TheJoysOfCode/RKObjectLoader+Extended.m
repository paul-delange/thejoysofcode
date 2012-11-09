//
//  RKObjectLoader+Extended.m
//  SeCoucherMoinsBete
//
//  Created by Paul De Lange on 29/05/12.
//  Copyright (c) 2012 Scimob. All rights reserved.
//

#import "RKObjectLoader+Extended.h"

#import <objc/runtime.h>

NSString* kOnWillMapDataKey = @"onWillMapData";

@implementation RKObjectLoader (Extended)

- (RKObjectLoaderWillMapDataBlock) onWillMapData {
    return objc_getAssociatedObject(self, &kOnWillMapDataKey);
}

- (void) setOnWillMapData:(RKObjectLoaderWillMapDataBlock) block {
    objc_setAssociatedObject(self, &kOnWillMapDataKey, block, OBJC_ASSOCIATION_COPY);
}

- (RKObjectMappingResult*)mapResponseWithMappingProvider:(RKObjectMappingProvider*)mappingProvider toObject:(id)targetObject inContext:(RKObjectMappingProviderContext)context error:(NSError**)error {
    
   // NSLog(@"bodyAsString: %@", [self.response bodyAsString]);
    
    id parsedData = [NSJSONSerialization JSONObjectWithData: self.response.body
                                                    options: 0
                                                      error: error];
    if (parsedData == nil && error) {
        return nil;
    }
    
    // Allow the delegate to manipulate the data
    if ([self.delegate respondsToSelector:@selector(objectLoader:willMapData:)]) {
        parsedData = [parsedData mutableCopy];
        [(NSObject<RKObjectLoaderDelegate>*)self.delegate objectLoader:self willMapData:&parsedData];
    }
    
    if( self.onWillMapData ) {
        parsedData = [parsedData mutableCopy];
        self.onWillMapData(&parsedData);
    }
    
    RKObjectMapper* mapper = [RKObjectMapper mapperWithObject:parsedData mappingProvider:mappingProvider];
    mapper.targetObject = targetObject;
    mapper.delegate = (id<RKObjectMapperDelegate>)self;
    mapper.context = context;
    RKObjectMappingResult* result = [mapper performMapping];
    
    // Log any mapping errors
    if (mapper.errorCount > 0) {
        RKLogError(@"Encountered errors during mapping: %@", [[mapper.errors valueForKey:@"localizedDescription"] componentsJoinedByString:@", "]);
    }
    
    // The object mapper will return a nil result if mapping failed
    if (nil == result) {
        // TODO: Construct a composite error that wraps up all the other errors. Should probably make it performMapping:&error when we have this?
        if (error) *error = [mapper.errors lastObject];
        return nil;
    }
    
    return result;
}

@end
