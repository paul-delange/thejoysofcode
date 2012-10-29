//
//  RKObjectLoader+Extended.m
//  SeCoucherMoinsBete
//
//  Created by Paul De Lange on 29/05/12.
//  Copyright (c) 2012 Scimob. All rights reserved.
//

#import "RKObjectLoader+Extended.h"

#import "CurrentUser.h"

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
    NSAssert(0, @"You should not be using this for SCMB");
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
                    NSString* desc = NSLocalizedString(@"Impossible de se connecter au serveur de Se Coucher Moins Bête. Veuillez réessayer ultérieurement.", @"");
                    NSError* offline = [NSError errorWithDomain: SCMBErrorDomain
                                                           code: SCMBErrorCodeServerOffline
                                                       userInfo: @{ NSLocalizedDescriptionKey : desc}];
                    [errors addObject: offline];
                    break;
                }
                case RKObjectMapperErrorObjectMappingTypeMismatch:
                case RKObjectMapperErrorUnmappableContent:
                case RKObjectLoaderUnexpectedResponseError:
                case RKObjectMapperErrorValidationFailure:
                {
                    //We could not parse the response
                    NSString* desc = NSLocalizedString(@"Réponse inconnue du serveur. Veuillez réessayer.", @"");
                    NSError* unparseable = [NSError errorWithDomain: SCMBErrorDomain
                                                               code: SCMBErrorCodeServerReturnedBadResponse
                                                           userInfo: @{ NSLocalizedDescriptionKey : desc}];
                    [errors addObject: unparseable];
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
                    NSString* desc = NSLocalizedString(@"Se Coucher Moins Bête est long à répondre. Attendez quelques minutes et réessayez.", @"");
                    NSError* timeout = [NSError errorWithDomain: SCMBErrorDomain
                                                           code: SCMBErrorCodeServerTimedOut
                                                       userInfo: @{ NSLocalizedDescriptionKey : desc}];
                    [errors addObject: timeout];
                    break;
                }
                default:
                    break;
            }
        }
        else if( [error.domain isEqualToString: @"JKErrorDomain"] ) {
            NSNumber* index = [error.userInfo objectForKey: @"JKAtIndexKey"];
            if( index && index.integerValue == 0 ) {
                NSAssert(self.response.isSuccessful, @"Response body was empty but the server returned something strange");
                
                if(self.onDidLoadObject)
                    self.onDidLoadObject(nil);
                
                return;
            }
            else {
                NSString* desc = NSLocalizedString(@"Réponse inconnue du serveur. Veuillez réessayer.", @"");
                NSError* unparseable = [NSError errorWithDomain: SCMBErrorDomain
                                                           code: SCMBErrorCodeServerReturnedBadResponse
                                                       userInfo: @{ NSLocalizedDescriptionKey : desc}];
                [errors addObject: unparseable];
            }
        }
        
        if( errors.count )
            [[NSNotificationCenter defaultCenter] postNotificationName: kNotificationServerErrorOccurred
                                                                object: self
                                                              userInfo: @{ kServerErrorKey : errors}];
        else {
            
            if(self.response.isSuccessful && self.onDidLoadObject )
                self.onDidLoadObject(nil);
            else {
                [[GAI sharedInstance].defaultTracker trackException: NO withNSError: error];
            }
        }
    };
}

- (NSArray *)cachedObjects {
    BOOL shouldDeleteFromCache = YES;
    
    if( [self.delegate respondsToSelector: @selector(objectLoaderHasCacheDeleteRights:)] ) {
        shouldDeleteFromCache = (BOOL)[self.delegate performSelector: @selector(objectLoaderHasCacheDeleteRights:) withObject: self];
    }
    
    if( shouldDeleteFromCache ) {
        NSFetchRequest *fetchRequest = [self.mappingProvider fetchRequestForResourcePath:self.resourcePath];
        if (fetchRequest) {
            return [NSManagedObject objectsWithFetchRequest:fetchRequest];
        }
    }
    
    return nil;
}

- (void) setModifiedSinceDate: (NSDate*) date {
    static NSDateFormatter* formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        [formatter setDateFormat: @"yyyy-MM-dd"];
    });
    
    NSString* lastModified = [formatter stringFromDate: date];
    if( lastModified.length )
        self.resourcePath = [self.resourcePath stringByAppendingQueryParameters: @{ @"since" : lastModified }];
}

@end

@implementation RKRequest (Extended)

+ (void) load {
    Method original, swizzled;
    
    original = class_getInstanceMethod(self, @selector(prepareURLRequest));
    swizzled = class_getInstanceMethod(self, @selector(swizzled_prepareURLRequest));
    
    method_exchangeImplementations(original, swizzled);
    
    // Cache-Control support
    // http://angelolloqui.com/blog/18-Restkit-addition-Cache-Control
    Method shouldLoadFromCacheCustom = class_getInstanceMethod([RKRequest class], @selector(shouldLoadFromCacheCustom));
    Method shouldLoadFromCache = class_getInstanceMethod([RKRequest class], @selector(shouldLoadFromCache));
    NSAssert(shouldLoadFromCache, @"The current version of RestKit is not compatible with the Cache-Control additions");
    method_exchangeImplementations(shouldLoadFromCache, shouldLoadFromCacheCustom);
}

- (RKRequestDidLoadResponseBlock) onDidLoadResponse {
    return ^(RKResponse* response) {
        //Extract the cookie for later...
        for(NSHTTPCookie* cookie in response.cookies) {
            NSAssert([cookie isKindOfClass: [NSHTTPCookie class]], @"Cookie is not a cookie");
            if( [[cookie.name lowercaseString] isEqualToString: @"token"] ) {
                CurrentUser* user = [CurrentUser findFirst];
                user.cookie = cookie;
                break;
            }
         }
        
        //Extract the authentication field
        NSString* authentication = response.allHeaderFields[@"x-authenticated"];
        if( authentication ) {
            NSAssert([authentication isKindOfClass: [NSString class]], @"Authentication was not a number");
            CurrentUser* user = [CurrentUser findFirst];
            user.isAuthenticated = @(authentication.boolValue);
        }
    };
}

- (RKRequestWillSendRequestBlock) onWillSendRequest {
    return ^(RKRequest* request) {
        CurrentUser* user = [CurrentUser findFirst];
        NSHTTPCookie* cookie = user.cookie;
        if( cookie ) {
            NSMutableDictionary* headers = [request.additionalHTTPHeaders mutableCopy];
            NSArray* cookieArray = @[user.cookie];
            NSDictionary* cookieHeaders = [NSHTTPCookie requestHeaderFieldsWithCookies: cookieArray];
            [headers addEntriesFromDictionary: cookieHeaders];
            request.additionalHTTPHeaders = headers;
        }
    };
}

- (BOOL) swizzled_prepareURLRequest {
    [self.URLRequest setHTTPMethod:[self HTTPMethod]];
    
    if( self.onWillSendRequest ) {
        self.onWillSendRequest(self);
    }

    return [self swizzled_prepareURLRequest];
}

- (BOOL)shouldLoadFromCacheCustom {
    if ([self.cache hasResponseForRequest:self]) {
        if (self.cachePolicy & RKRequestCachePolicyControlMaxAge) {
            NSDictionary *headers = [self.cache headersForRequest:self];
            
            //Retrieve the Cache-Control header
            NSString *cacheControl = [headers objectForKey:kHTTPCacheControl];
            if (!cacheControl) {
                //Check for lower case headers that could also match
                for (NSString* responseHeader in headers) {
                    if ([[responseHeader uppercaseString] isEqualToString:[kHTTPCacheControl uppercaseString]]) {
                        cacheControl = [headers objectForKey:responseHeader];
                        break;
                    }
                }
            }
            
            if (cacheControl) {
                
                //Check the cache control max age
                NSError *error = NULL;
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\bmax-age=(\\d)+"
                                                                                       options:NSRegularExpressionCaseInsensitive
                                                                                         error:&error];
                
                NSRange rangeOfFirstMatch = [regex rangeOfFirstMatchInString:cacheControl options:0 range:NSMakeRange(0, [cacheControl length])];
                if (rangeOfFirstMatch.location != NSNotFound) {
                    NSInteger maxAge = [[cacheControl substringWithRange:NSMakeRange(rangeOfFirstMatch.location + 8, rangeOfFirstMatch.length - 8)] integerValue];
                    NSDate* date = [self.cache cacheDateForRequest:self];
                    NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:date];
                    if (interval < maxAge) {
                        DLog(@"Reusing cached result for %@ with maxAge %d and current age %d", [self.URL absoluteString], maxAge, (NSInteger)interval);
                        return YES;
                    }
                }
                
                //Check the cache control no-cache
                regex = [NSRegularExpression regularExpressionWithPattern:@"\\bno-cache\\b"
                                                                  options:NSRegularExpressionCaseInsensitive
                                                                    error:&error];
                
                rangeOfFirstMatch = [regex rangeOfFirstMatchInString:cacheControl options:0 range:NSMakeRange(0, [cacheControl length])];
                if (rangeOfFirstMatch.location != NSNotFound) {
                    return NO;
                }
            }
        }
    }
    return [self shouldLoadFromCacheCustom];
}

@end
