//
//  DFStrandStore.h
//  Strand
//
//  Created by Henry Bridge on 6/19/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFStrandStore : NSObject

+ (void) setGalleryLastSeenDate:(NSDate *)date;
+ (NSDate *)galleryLastSeenDate;
+ (void) SaveUnseenPhotosCount:(int)count;
+ (int) UnseenPhotosCount;

@end
