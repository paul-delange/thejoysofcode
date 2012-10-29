//
//  RKObjectLoader+Extended.m
//  SeCoucherMoinsBete
//
//  Created by Paul De Lange on 29/05/12.
//  Copyright (c) 2012 Scimob. All rights reserved.
//

#import "RKObjectLoader+Extended.h"

#import <objc/runtime.h>
#import <RestKit/RKObjectMapperError.h>

NSString* kOnWillMapDataKey = @"onWillMapData";

static NSString * const kHTTPCacheControl = @"Cache-Control";

@implementation RKObjectLoader (Extended)

- (RKObjectLoaderWillMapDataBlock) onWillMapData {
    return objc_getAssociatedObject(self, &kOnWillMapDataKey);
}

- (void) setOnWillMapData:(RKObjectLoaderWillMapDataBlock) block {
    objc_setAssociatedObject(self, &kOnWillMapDataKey, block, OBJC_ASSOCIATION_COPY);
}

- (RKObjectMappingResult*)mapResponseWithMappingProvider:(RKObjectMappingProvider*)mappingProvider toObject:(id)targetObject inContext:(RKObjectMappingProviderContext)context error:(NSError**)error {
    id<RKParser> parser = [[RKParserRegistry sharedRegistry] parserForMIMEType:self.response.MIMEType];
    NSAssert1(parser, @"Cannot perform object load without a parser for MIME Type '%@'", self.response.MIMEType);
    
    // Check that there is actually content in the response body for mapping. It is possible to get back a 200 response
    // with the appropriate MIME Type with no content (such as for a successful PUT or DELETE). Make sure we don't generate an error
    // in these cases
    id bodyAsString = [self.response bodyAsString];
    RKLogTrace(@"bodyAsString: %@", bodyAsString);
    if (bodyAsString == nil || [[bodyAsString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) {
        RKLogDebug(@"Mapping attempted on empty response body...");
        if (self.targetObject) {
            return [RKObjectMappingResult mappingResultWithDictionary:[NSDictionary dictionaryWithObject:self.targetObject forKey:@""]];
        }
        
        return [RKObjectMappingResult mappingResultWithDictionary:[NSDictionary dictionary]];
    }
    
    id parsedData = [parser objectFromString:bodyAsString error:error];
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

- (void) setOnDidFailWithError:(RKObjectLoaderDidFailWithErrorBlock)onDidFailWithError {
    NSAssert(0, @"You should not be using this for this app");
}

- (RKObjectLoaderDidFailWithErrorBlock) onDidFailWithError {
    return ^(NSError* error) {
        NSAssert([NSThread isMainThread], @"Notification posting must occur on the main thread");
        
        NSMutableArray* errors = [NSMutableArray array];
        
        if( [error.domain isEqualToString: RKErrorDomain] ) {
            switch (error.code) {
                case RKObjectMapperErrorObjectMappingNotFound:
                {
                    //we need to check for form specific errors
                    
                    break;
                }
                case RKObjectLoaderRemoteSystemError:
                case RKRequestUnexpectedResponseError:
                {
                    NSAssert(0, @"These errors are not used by RestKit");
                    break;
                }
                case RKRequestBaseURLOfflineError:
                {   //Server was not reachable
                    break;
                }
                case RKObjectMapperErrorObjectMappingTypeMismatch:
                case RKObjectMapperErrorUnmappableContent:
                case RKObjectLoaderUnexpectedResponseError:
                case RKObjectMapperErrorValidationFailure:
                {
                    //We could not parse the response
                    break;
                }
                case RKObjectMapperErrorFromMappingResult:
                {
                    if( error )
                        [errors addObject: error];
                    break;
                }
                case RKRequestConnectionTimeoutError:
                {
                    //Server timed out
                    break;
                }
                default:
                    break;
            }
        }
    };
}

@end
