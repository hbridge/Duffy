//
//  DFUploadController.m
//  Duffy
//
//  Created by Henry Bridge on 3/11/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <RestKit/RestKit.h>
#import <CommonCrypto/CommonHMAC.h>
#import "DFUploadController.h"
#import "DFPhotoStore.h"
#import "DFPhoto.h"
#import "DFUser.h"

@interface DFUploadController()

@property (nonatomic, retain) RKObjectManager* objectManager;

@end


// Private DFUploadResponse Class
@interface DFUploadResponse : NSObject

@property NSString *result;
@property NSString *debug;

@end

@implementation DFUploadResponse

@end

@implementation DFUploadController



NSString *DFUploadStatusUpdate = @"DFUploadStatusUpdate";



static DFUploadController *defaultUploadController;

+ (DFUploadController *)sharedUploadController {
    if (!defaultUploadController) {
        defaultUploadController = [[super allocWithZone:nil] init];
    }
    return defaultUploadController;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedUploadController];
}

- (DFUploadController *)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}


- (void)uploadPhotos:(NSArray *)photos
{
    NSLog(@"UploadController uploading %ld photos", photos.count);
    for (DFPhoto *photo in photos) {
        if (photo.uploadDate) {
            NSLog(@"Uploading a file we already think was uploaded.");
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
    NSDictionary *params = @{@"userId": [DFUser deviceID]};
    NSDate *uploadStartDate = [NSDate date];
    NSString *uniqueUploadName = [self uniqueFilenameForPhoto:photo uploadDate:uploadStartDate];

    NSMutableURLRequest *request = [[self objectManager] multipartFormRequestWithObject:nil
                                                                                 method:RKRequestMethodPOST
                                                                                   path:AddPhotoResource
                                                                             parameters:params
                                                              constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        [formData appendPartWithFileData:imageData
                                    name:uniqueUploadName
                                fileName:[NSString stringWithFormat:@"%@.jpg", uniqueUploadName]
                                mimeType:@"image/jpg"];
    }];
    
    //NSLog(request.description);
    
    RKObjectRequestOperation *operation =
        [[self objectManager] objectRequestOperationWithRequest:request
                                                        success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
    {
        DFUploadResponse *response = [mappingResult firstObject];
        NSLog(@"Upload response received.  result:%@ debug:%@", response.result, response.debug);
        if ([response.result isEqualToString:@"true"]) {
            photo.uploadDate = uploadStartDate;
        } else {
            // TODO add retry logic here?
        }
    }
                                                        failure:^(RKObjectRequestOperation *operation, NSError *error)
    {
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



- (NSString *)uniqueFilenameForPhoto:(DFPhoto *)photo uploadDate:(NSDate *)date
{
    NSString *inputString = [NSString stringWithFormat:@"%@ %f", photo.alAssetURLString, [date timeIntervalSince1970]];
    NSString *sha1 = [self sha1:inputString];
    return sha1;
}

-(NSString*) sha1:(NSString*)input
{
    const char *cstr = [input cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:input.length];
    
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (int)data.length, digest);
    
    NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    
    return output;
}


@end
