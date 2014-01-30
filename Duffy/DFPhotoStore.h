//
//  DFPhotoStore.h
//  Duffy
//
//  Created by Henry Bridge on 1/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFPhotoStore : NSObject

+ (DFPhotoStore *)sharedStore;
- (NSArray *)cameraRoll;



- (NSArray *)allAlbums;

@end
