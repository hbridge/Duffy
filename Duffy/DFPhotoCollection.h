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
@property (readonly, nonatomic, retain) NSSet *photoURLSet;


- (id)initWithPhotos:(NSArray *)photos;
- (void)addPhotos:(NSArray *)newPhotos;
- (BOOL)containsPhotoWithAssetURL:(NSString *)assetURLString;
- (NSArray *)photosByDateAscending:(BOOL)ascending;

@end
