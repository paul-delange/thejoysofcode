//
//  RKObjectLoader+Extended.h
//  SeCoucherMoinsBete
//
//  Created by Paul De Lange on 29/05/12.
//  Copyright (c) 2012 Scimob. All rights reserved.
//

#import <RestKit/RestKit.h>

typedef void(^RKObjectLoaderWillMapDataBlock)(id* mappableData);

@protocol RKObjectLoaderDelegate <RKObjectLoaderDelegate>
@optional
- (BOOL) objectLoaderHasCacheDeleteRights:(RKObjectLoader *)objectLoader;

@end

@interface RKObjectLoader (Extended)

@property (nonatomic, copy) RKObjectLoaderWillMapDataBlock onWillMapData;

@end

