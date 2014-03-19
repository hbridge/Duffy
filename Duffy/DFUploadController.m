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
#import "DFSettingsViewController.h"


// Private DFUploadResponse Class
@interface DFUploadResponse : NSObject
@property NSString *result;
@property NSString *debug;
@end
@implementation DFUploadResponse
@end

// Constants
static NSString *BaseURL = @"http://photos.derektest1.com/";
static NSString *AddPhotoResource = @"api/addphoto.php";
const NSString *DFUploadStatusUpdate = @"DFUploadStatusUpdate";
static NSString *UserIDParameterKey = @"userId";

@interface DFUploadController()

@property (readonly, atomic, retain) RKObjectManager* objectManager;
@property (atomic) dispatch_queue_t uploadDispatchQueue;
@property (atomic) dispatch_semaphore_t uploadEnqueueSemaphore;
@property (atomic, retain) NSMutableArray *photosToUpload;

@end

@implementation DFUploadController

@synthesize objectManager = _objectManager;


static const CGFloat IMAGE_UPLOAD_SMALLER_DIMENSION = 569.0;
static const float IMAGE_UPLOAD_JPEG_QUALITY = 90.0;

// We want the upload controller to be a singleton
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
        self.uploadDispatchQueue = dispatch_queue_create("com.duffysoft.DFUploadController.UploadQueue", DISPATCH_QUEUE_SERIAL);
        self.photosToUpload = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark - Public APIs

- (void)uploadPhotos:(NSArray *)photos
{
    NSLog(@"UploadController uploading %d photos", (int)photos.count);
    if (photos.count < 1) return;
    
    [self.photosToUpload addObjectsFromArray:photos];
    [self enqueuePhotoForUpload:self.photosToUpload.firstObject];
}

#pragma mark - Private networking code

- (void)enqueuePhotoForUpload:(DFPhoto *)photo
{
    dispatch_async(self.uploadDispatchQueue, ^{
        [self uploadPhoto:photo];
    });
}


- (void)uploadFinishedForPhoto:(DFPhoto *)photo
{
    [self.photosToUpload removeObject:photo];
    
    NSLog(@"Photo upload complete.  %d photos remaining.", (int)self.photosToUpload.count);
    if (self.photosToUpload.count > 0) {
        [self enqueuePhotoForUpload:self.photosToUpload.firstObject];
    }
}

- (void)uploadPhoto:(DFPhoto *)photo
{
    NSURLRequest *postRequest = [self createPostRequestForPhoto:photo];
    
    RKObjectRequestOperation *operation =
        [[self objectManager] objectRequestOperationWithRequest:postRequest
                                                        success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
    {
        DFUploadResponse *response = [mappingResult firstObject];
        NSLog(@"Upload response received.  result:%@ debug:%@", response.result, response.debug);
        if ([response.result isEqualToString:@"true"]) {
            photo.uploadDate = [NSDate date];
            [self uploadFinishedForPhoto:photo];
        } else {
            NSLog(@"File did not upload properly.  Retrying.");
            [self enqueuePhotoForUpload:self.photosToUpload.firstObject];
        }
    }
                                                        failure:^(RKObjectRequestOperation *operation, NSError *error)
    {
        NSLog(@"Upload failed.  Error: %@", error.localizedDescription);
        
    }];
    
    
    [[self objectManager] enqueueObjectRequestOperation:operation]; // NOTE: Must be enqueued rather than started
}


- (NSMutableURLRequest *)createPostRequestForPhoto:(DFPhoto *)photo
{
    UIImage *imageToUpload = [photo scaledImageWithSmallerDimension:IMAGE_UPLOAD_SMALLER_DIMENSION];
    NSData *imageData = UIImageJPEGRepresentation(imageToUpload, IMAGE_UPLOAD_JPEG_QUALITY);
    NSMutableDictionary *params = [NSMutableDictionary
                                   dictionaryWithDictionary:@{UserIDParameterKey: [DFUser deviceID]}];
    // if processing off, append prefix to userid
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:DFPipelineEnabledUserDefaultKey]
         isEqualToString:DFPipelineEnabledNo]){
        params[UserIDParameterKey] = [NSString stringWithFormat:@"dnp%@", [DFUser deviceID]];
    }
    
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

    return request;
}


#pragma mark - Internal Helper Functions


- (RKObjectManager *)objectManager {
    if (!_objectManager) {
        NSURL *baseURL = [NSURL URLWithString:BaseURL];
        _objectManager = [RKObjectManager managerWithBaseURL:baseURL];
        
        // generate response mapping
        RKObjectMapping *responseMapping = [RKObjectMapping mappingForClass:[DFUploadResponse class]];
        [responseMapping addAttributeMappingsFromArray:@[@"result", @"debug"]];
        
        RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:responseMapping
                                                                                                method:RKRequestMethodPOST
                                                                                           pathPattern:AddPhotoResource
                                                                                               keyPath:nil
                                                                                           statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
        
        [_objectManager addResponseDescriptor:responseDescriptor];
    }
    return _objectManager;
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
