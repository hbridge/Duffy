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

/* (UIImage *)thumbnail
 Returns a thumbnail representation of the photo collection.  If not set, returns a thumbnail of the
 earliest photo in the collection.
 */
@property (nonatomic, retain) UIImage *thumbnail;

- (id)initWithPhotos:(NSArray *)photos;
- (void)addPhotos:(NSArray *)newPhotos;
- (BOOL)containsPhotoWithAssetURL:(NSString *)assetURLString;
- (NSArray *)photosByDateAscending:(BOOL)ascending;
- (NSArray *)objectIDsByDateAscending:(BOOL)ascending;

@end
