//
//  DFPhotoCollection.h
//  Duffy
//
//  Created by Henry Bridge on 3/19/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>



@interface DFPhotoCollection : NSObject

@property (readonly, nonatomic, retain) NSSet *photoSet;
@property (readonly, nonatomic, retain) NSArray *photosByDate;


- (void)addPhotos:(NSArray *)newPhotos;
- (BOOL)containsPhotoWithAssetURL:(NSString *)assetURLString;


@end
