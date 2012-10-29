//
//  MappingProvider.h
//  TheJoysOfCode
//
//  Created by Bob on 29/10/12.
//  Copyright (c) 2012 Tall Developments. All rights reserved.
//

#import <RestKit/RestKit.h>

@interface MappingProvider : RKObjectMappingProvider

+ (id) mappingProvider: (void(^)(MappingProvider*)) block;

@end
