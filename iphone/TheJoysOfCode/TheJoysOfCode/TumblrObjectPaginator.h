//
//  TumblrObjectPaginator.h
//  TheJoysOfCode
//
//  Created by Paul de Lange on 31/10/12.
//  Copyright (c) 2012 Tall Developments. All rights reserved.
//

#import <RestKit/RestKit.h>

@interface TumblrObjectPaginator : RKObjectPaginator

@property (readonly, nonatomic) NSUInteger currentObject;

@end
