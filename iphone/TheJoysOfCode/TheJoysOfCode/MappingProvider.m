//
//  MappingProvider.m
//  TheJoysOfCode
//
//  Created by Bob on 29/10/12.
//  Copyright (c) 2012 Tall Developments. All rights reserved.
//

#import "MappingProvider.h"

@implementation MappingProvider

+ (id) mappingProvider: (void(^)(MappingProvider*)) block {
    MappingProvider* provider = [MappingProvider new];
    NSAssert(block, @"You need a configuration block");
    block(provider);
    return provider;
}

@end
