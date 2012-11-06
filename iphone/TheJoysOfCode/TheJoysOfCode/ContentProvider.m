//
//  ContentProvider.m
//  TheJoysOfCode
//
//  Created by Bob on 29/10/12.
//  Copyright (c) 2012 Tall Developments. All rights reserved.
//

#import "ContentProvider.h"

#import <Parse/Parse.h>

#define kContentLanguageKey    @"content.language.key"

@implementation ContentProvider

static const char* availableProviders[] = {"fr"};

+ (void) load {
    @autoreleasepool {
        NSString* previousLanguage = [[NSUserDefaults standardUserDefaults] stringForKey: kContentLanguageKey];
        
        if( previousLanguage==nil ) {
            NSArray* preferredLanguages = [NSLocale preferredLanguages];
            NSString* userLanguage = [preferredLanguages objectAtIndex: 0] ? : @"fr";
            
            if( [self providerExistsForIdentifier: userLanguage] ) {
                [self setContentLanguage: userLanguage];
            }
            NSInteger totalAvailable = sizeof(availableProviders) / sizeof(availableProviders[0]);
            if( totalAvailable == 1 ) {
                const char* cLang = availableProviders[0];
                NSString* forcedLanguage = [NSString stringWithCString: cLang encoding:NSUTF8StringEncoding];
                [self setContentLanguage: forcedLanguage];
            }
            else {
                [self setContentLanguage: userLanguage];
            }
        }
    }
}

+ (BOOL) providerExistsForIdentifier: (NSString*) iso639_1_identifier {
    if(!iso639_1_identifier)
        return NO;
    
    const char* thisLanguage = [[iso639_1_identifier lowercaseString] UTF8String];
    NSInteger totalAvailable = sizeof(availableProviders) / sizeof(availableProviders[0]);
    for (NSInteger i=0; i<totalAvailable; i++) {
        if( strcmp(availableProviders[i], thisLanguage) == 0 )
            return YES;
    }
    
    return NO;
}

+ (NSString*) contentLanguage {
    return [[NSUserDefaults standardUserDefaults] stringForKey: kContentLanguageKey];
}

+ (void) setContentLanguage: (NSString*) identifier {
    NSString* previousLanguage = [[NSUserDefaults standardUserDefaults] stringForKey: kContentLanguageKey];
    
    if( ![previousLanguage isEqualToString: identifier] ) {
        [[NSUserDefaults standardUserDefaults] setObject: identifier forKey: kContentLanguageKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

+ (NSString*) baseURL {
    NSString* lang = [[NSUserDefaults standardUserDefaults] stringForKey: kContentLanguageKey];
    NSAssert(lang, @"There was no language set in your content provider");
    
    if( [lang isEqualToString: @"fr"] ) {
        return @"http://api.tumblr.com/v2/blog/lesjoiesducode.tumblr.com";
    }
    else if( [lang isEqualToString: @"en"] ) {
        return @"http://api.tumblr.com/v2/blog/thejoysofcode.tumblr.com/";
    }
    
    return @"";
}

@end
