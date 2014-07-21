//
//  DFImageStore.h
//  Strand
//
//  Created by Henry Bridge on 7/20/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFTypedefs.h"

@interface DFImageStore : NSObject

typedef void (^ImageLoadCompletionBlock)(UIImage *image);
typedef void (^SetImageCompletion)(NSError *error);

+ (DFImageStore *)sharedStore;
- (void)imageForID:(DFPhotoIDType)photoID
              type:(DFImageType)type
        completion:(ImageLoadCompletionBlock)completionBlock;

- (void)setImage:(UIImage *)image
            type:(DFImageType)type
           forID:(DFPhotoIDType)photoID
      completion:(SetImageCompletion)completion;

+ (NSError *)clearCache;

+ (NSURL *)applicationDocumentsDirectory;
+ (NSURL *)localFullImagesDirectoryURL;
+ (NSURL *)localThumbnailsDirectoryURL;


@end
