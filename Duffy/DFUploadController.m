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

@interface DFUploadResponse : NSObject

@property NSString *result;
@property NSString *debug;

@end

@implementation DFUploadResponse

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
        
        // generate response mapping
        RKObjectMapping *responseMapping = [RKObjectMapping mappingForClass:[DFUploadResponse class]];
        [responseMapping addAttributeMappingsFromArray:@[@"result", @"debug"]];
        
        RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:responseMapping
                                                                                                method:RKRequestMethodPOST
                                                                                           pathPattern:@"api/addphoto.php"
                                                                                               keyPath:nil
                                                                                           statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
        
        [_objectManager addResponseDescriptor:responseDescriptor];
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
                                    name:photo.localFilename
                                fileName:[NSString stringWithFormat:@"%@", photo.localFilename]
                                mimeType:@"image/jpg"];
    }];
    
    //NSLog(request.description);
    
    RKObjectRequestOperation *operation =
        [[self objectManager] objectRequestOperationWithRequest:request
                                                        success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
        DFUploadResponse *response = [mappingResult firstObject];
        NSLog(@"Upload resposne received.  result:%@ debug:%@", response.result, response.debug);
                                                            
    }
                                                        failure:^(RKObjectRequestOperation *operation, NSError *error) {
                                                            NSLog(@"Upload failed.  Error: %@", error.localizedDescription);
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
