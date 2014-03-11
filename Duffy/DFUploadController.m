//
//  DFUploadController.m
//  Duffy
//
//  Created by Henry Bridge on 3/11/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFUploadController.h"
#import "DFPhotoStore.h"
#import "DFPhoto.h"
#import <RestKit/RestKit.h>

@interface DFUploadController()

@property (nonatomic, retain) RKObjectManager* objectManager;

@end


@implementation DFUploadController

NSString *DFUploadStatusUpdate = @"DFUploadStatusUpdate";

- (void)uploadPhotos:(NSArray *)photos
{
    for (DFPhoto *photo in photos) {
        if (photo.uploadDate) {
            NSLog(@"Uh oh, we think this photo was already uploaded!");
            continue;
        }
        
        [self uploadPhoto:photo];
        
    }
    
}

static NSString *BaseURL = @"http://photos.derektest1.com/";
static NSString *AddPhotoResource = @"/api/addphoto.php";

- (RKObjectManager *)objectManager {
    if (!_objectManager) {
        NSURL *baseURL = [NSURL URLWithString:BaseURL];
        _objectManager = [RKObjectManager managerWithBaseURL:baseURL];
        
    }
    return _objectManager;
}

- (void)uploadPhoto:(DFPhoto *)photo
{
    if (photo.thumbnail == nil) {
        [photo addObserver:self forKeyPath:@"thumbnail" options:NSKeyValueObservingOptionNew context:nil];
        [photo loadThumbnail];
        return;
    }
    
    [self uploadPhotoWithCachedThumbnail:photo];
}

- (void)uploadPhotoWithCachedThumbnail:(DFPhoto *)photo
{
    if (photo.thumbnail == nil) return;
    
    NSData *imageData = UIImageJPEGRepresentation(photo.thumbnail, 0.75);
    // TOODO add a req parameter "Id" with a user id from the device
    
    
    NSMutableURLRequest *request = [[self objectManager] multipartFormRequestWithObject:nil
                                                                                 method:RKRequestMethodPOST
                                                                                   path:AddPhotoResource
                                                                             parameters:nil
                                                              constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        [formData appendPartWithFileData:imageData
                                    name:photo.localID
                                fileName:[NSString stringWithFormat:@"%@.jpg", photo.localID]
                                mimeType:@"image/jpg"];
    }];
    
    //NSLog(request.description);
    
    RKObjectRequestOperation *operation = [[self objectManager] objectRequestOperationWithRequest:request success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
        // success code
    } failure:^(RKObjectRequestOperation *operation, NSError *error) {
        // failure block
    }];
    [[self objectManager] enqueueObjectRequestOperation:operation]; // NOTE: Must be enqueued rather than started
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"thumbnail"]) {
        [self uploadPhotoWithCachedThumbnail:(DFPhoto *)object];
    }
}


@end
