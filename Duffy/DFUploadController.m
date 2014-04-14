//
//  DFUploadController.m
//  Duffy
//
//  Created by Henry Bridge on 3/11/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <RestKit/RestKit.h>
#import <CommonCrypto/CommonHMAC.h>
#import <JDStatusBarNotification/JDStatusBarNotification.h>
#import "DFUploadController.h"
#import "DFPhotoStore.h"
#import "DFPhoto.h"
#import "DFUser.h"
#import "DFSettingsViewController.h"
#import "NSDictionary+DFJSON.h"
#import "DFPhoto+FaceDetection.h"
#import "NSNotificationCenter+DFThreadingAddons.h"
#import "DFNotificationSharedConstants.h"
#import "DFAnalytics.h"


// Private DFUploadResponse Class
@interface DFUploadResponse : NSObject
@property (nonatomic, retain) NSString *result;
@property (nonatomic, retain) NSString *debug;
@end
@implementation DFUploadResponse
@end

// Constants
static NSString *AddPhotoResource = @"/api/addPhoto";
static NSString *UserIDParameterKey = @"phone_id";
static NSString *PhotoMetadataKey = @"photo_metadata";
static NSString *PhotoLocationKey = @"location_data";
static NSString *PhotoFacesKey = @"iphone_faceboxes_topleft";

@interface DFUploadController()

@property (readonly, atomic, retain) RKObjectManager* objectManager;
@property (atomic) dispatch_queue_t uploadDispatchQueue;
@property (atomic) dispatch_semaphore_t uploadEnqueueSemaphore;
@property (atomic, retain) NSMutableOrderedSet *photoURLsToUpload;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundUpdateTask;

@property (readonly, nonatomic, retain) NSManagedObjectContext *managedObjectContext;

@end

@implementation DFUploadController

@synthesize objectManager = _objectManager;
@synthesize managedObjectContext = _managedObjectContext;


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
        self.photoURLsToUpload = [[NSMutableOrderedSet alloc] init];
        [self setupStatusBarNotifications];
        self.backgroundUpdateTask = UIBackgroundTaskInvalid;
    }
    return self;
}


#pragma mark - Public APIs

- (void)uploadPhotosWithURLs:(NSArray *)photoURLStrings
{
    NSUInteger photosInQueuePreAdd = self.photoURLsToUpload.count;
    if (photoURLStrings.count < 1) return;
 
    [self beginBackgroundUpdateTask];
    if (!self.currentSessionStats) {
        self.currentSessionStats = [[DFUploadSessionStats alloc] init];
    }
    [self.currentSessionStats.acceptedURLs addObjectsFromArray:photoURLStrings];
    
    [self.photoURLsToUpload addObjectsFromArray:photoURLStrings];
    [self enqueuePhotoURLForUpload:self.photoURLsToUpload.firstObject];
    
    NSLog(@"UploadController: upload requested for %d photos, %d already in queue, %d added.",
          (int)photosInQueuePreAdd,
          (int)self.photoURLsToUpload.count,
          (int)(self.photoURLsToUpload.count - photosInQueuePreAdd)
          );
    [self postStatusUpdate];

}


#pragma mark - Private config code
- (void)setupStatusBarNotifications
{
    [JDStatusBarNotification setDefaultStyle:^JDStatusBarStyle *(JDStatusBarStyle *style) {
        style.barColor = [UIColor colorWithWhite:.9686 alpha:1.0]; //.9686 matches the default nav bar color
        style.textColor = [UIColor darkGrayColor];
        style.progressBarColor = [UIColor blueColor];
        style.animationType = JDStatusBarAnimationTypeFade;
        return style;
    }];
}

#pragma mark - Private Uploading Code

- (void) beginBackgroundUpdateTask
{
    if (self.backgroundUpdateTask != UIBackgroundTaskInvalid) {
        NSLog(@"DFUploadController: have background upload task, no need to register another.");
        return;
    }
    self.backgroundUpdateTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self endBackgroundUpdateTask];
    }];
}

- (void) endBackgroundUpdateTask
{
    [[UIApplication sharedApplication] endBackgroundTask: self.backgroundUpdateTask];
    self.backgroundUpdateTask = UIBackgroundTaskInvalid;
}

- (void)enqueuePhotoURLForUpload:(NSString *)photoURLString
{
    dispatch_async(self.uploadDispatchQueue, ^{
        DFPhoto *photo = [DFPhoto photoWithURL:photoURLString inContext:self.managedObjectContext];
        [self uploadPhoto:photo];
    });
}


- (void)uploadPhoto:(DFPhoto *)photo
{
    NSURLRequest *postRequest = [self createPostRequestForPhoto:photo];
    
    NSNumber *numBytes = [NSURLProtocol propertyForKey:@"DFPhotoNumBytes" inRequest:postRequest];
    [DFAnalytics logUploadBeganWithNumBytes:[numBytes unsignedIntegerValue]];
    RKObjectRequestOperation *operation =
        [[self objectManager] objectRequestOperationWithRequest:postRequest
            success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
    {
        DFUploadResponse *response = [mappingResult firstObject];
        NSLog(@"Upload response received.  result:%@ debug:%@", response.result, response.debug);
        if ([response.result isEqualToString:@"true"]) {
            photo.uploadDate = [NSDate date];
            [self uploadFinishedForPhoto:photo];
            [DFAnalytics logUploadEndedWithResult:DFAnalyticsValueResultSuccess];
        } else {
            NSLog(@"File did not upload properly.  Retrying.");
            [self enqueuePhotoURLForUpload:self.photoURLsToUpload.firstObject];
            [DFAnalytics logUploadEndedWithResult:DFAnalyticsValueResultFailure debug:response.debug];
        }
    }
            failure:^(RKObjectRequestOperation *operation, NSError *error)
    {
        NSLog(@"Upload failed.  Error: %@", error.localizedDescription);
        NSString *debugString = [NSString stringWithFormat:@"%@ %ld", error.domain, (long)error.code];
        [DFAnalytics logUploadEndedWithResult:DFAnalyticsValueResultFailure debug:debugString];
        if (error.code == -1001) {//timeout
            [self enqueuePhotoURLForUpload:self.photoURLsToUpload.firstObject];
        }
        
    }];
    
    
    [[self objectManager] enqueueObjectRequestOperation:operation]; // NOTE: Must be enqueued rather than started
}

- (NSMutableURLRequest *)createPostRequestForPhoto:(DFPhoto *)photo
{
    UIImage *imageToUpload = [photo scaledImageWithSmallerDimension:IMAGE_UPLOAD_SMALLER_DIMENSION];
    NSData *imageData = UIImageJPEGRepresentation(imageToUpload, IMAGE_UPLOAD_JPEG_QUALITY);
    NSDictionary *postParameters = [self postParametersForPhoto:photo];
    NSString *uniqueFilename = [NSString stringWithFormat:@"photo_%@.jpg", [[NSUUID UUID] UUIDString]];
    
    
    NSMutableURLRequest *request = [[self objectManager] multipartFormRequestWithObject:nil
                                                                                 method:RKRequestMethodPOST
                                                                                   path:AddPhotoResource
                                                                             parameters:postParameters
                                                              constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                                                                  [formData appendPartWithFileData:imageData
                                                                                              name:@"file"
                                                                                          fileName:uniqueFilename
                                                                                          mimeType:@"image/jpg"];
                                                              }];
    [NSURLProtocol setProperty:[NSNumber numberWithUnsignedInteger:imageData.length] forKey:@"DFPhotoNumBytes" inRequest:request];

    return request;
}

- (NSDictionary *)postParametersForPhoto:(DFPhoto *)photo
{
    NSDictionary *params = @{
                             UserIDParameterKey: [[DFUser currentUser] deviceID],
                             PhotoMetadataKey: [self metadataJSONStringForPhoto:photo],
                             PhotoLocationKey: [self locationJSONStringForPhoto:photo],
                             PhotoFacesKey:    [self faceJSONStringForPhoto:photo],
                             };
    
    return params;
}


- (NSString *)metadataJSONStringForPhoto:(DFPhoto *)photo
{
    NSDictionary *jsonSafeMetadataDict = [[photo metadataDictionary] dictionaryWithNonJSONRemoved];
    return [jsonSafeMetadataDict JSONString];
}

- (NSString *)locationJSONStringForPhoto:(DFPhoto *)photo
{
    if (photo.location == nil) {
        NSLog(@"photo has no location, skipping.");
        return [@{} JSONString];
    }
    
    
    NSDictionary __block *resultDictionary;
    
    // safe to call this here as we're on the uploader dispatch queue and
    // the reverse geocoder call back will happen on main thread, per the docs
    
    dispatch_semaphore_t reverseGeocodeSemaphore = dispatch_semaphore_create(0);
    [photo fetchReverseGeocodeDictionary:^(NSDictionary *locationDict) {
        resultDictionary = locationDict;
        dispatch_semaphore_signal(reverseGeocodeSemaphore);
    }];
     
     dispatch_semaphore_wait(reverseGeocodeSemaphore, DISPATCH_TIME_FOREVER);
    

     return [resultDictionary JSONString];
}

- (NSString *)faceJSONStringForPhoto:(DFPhoto *)photo
{
    NSArray __block *resultArray;
    
    dispatch_semaphore_t faceDetectSemaphore = dispatch_semaphore_create(0);
    [photo faceFeaturesInPhoto:^(NSArray *features) {
        resultArray = features;
        dispatch_semaphore_signal(faceDetectSemaphore);
    }];
    
    dispatch_semaphore_wait(faceDetectSemaphore, DISPATCH_TIME_FOREVER);
    
    NSMutableDictionary *resultDictionary = [[NSMutableDictionary alloc] init];
    for (CIFaceFeature *faceFeature in resultArray) {
        NSString *key = [NSString stringWithFormat:@"%lu", (unsigned long)resultDictionary.count];
        resultDictionary[key] = @{@"bounds": NSStringFromCGRect(faceFeature.bounds),
                                  @"has_smile" : [NSNumber numberWithBool:faceFeature.hasSmile],
                                  };
    }
    
    return [resultDictionary JSONString];
}

# pragma mark - Private Upload Completion Handlers

- (void)uploadFinishedForPhoto:(DFPhoto *)photo
{
    [self saveUploadProgress];
    [[NSNotificationCenter defaultCenter] postMainThreadNotificationName:DFPhotoChangedNotificationName
                                                                  object:self
                                                                userInfo:@{photo.objectID : DFPhotoChangeTypeMetadata}];
    
    [self.photoURLsToUpload removeObject:photo.alAssetURLString];
    [self.currentSessionStats.uploadedURLs addObject:photo.alAssetURLString];
    [self postStatusUpdate];
    
    NSLog(@"Photo upload complete.  %d photos remaining.", (int)self.photoURLsToUpload.count);
    if (self.photoURLsToUpload.count > 0) {
        [self enqueuePhotoURLForUpload:self.photoURLsToUpload.firstObject];
    } else {
        NSLog(@"all photos uploaded.");
        self.currentSessionStats = nil;
        [self endBackgroundUpdateTask];
    }
}

- (void)saveUploadProgress
{
    
    NSError *error = nil;
    if(![self.managedObjectContext save:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        [NSException raise:@"Could not save upload photo progress." format:@"Error: %@",[error localizedDescription]];
    }
    
    NSLog(@"upload progress saved.");
}

- (void)postStatusUpdate
{
    [[NSNotificationCenter defaultCenter] postMainThreadNotificationName:DFUploadStatusNotificationName
                                                                  object:self
                                                                userInfo:@{DFUploadStatusUpdateSessionUserInfoKey: self.currentSessionStats}];
    [self showStatusBarNotification];
}

- (void)showStatusBarNotification
{
    if (self.currentSessionStats.numRemaining > 0) {
        NSString *statusString = [NSString stringWithFormat:@"Uploading. %lu left.", (unsigned long)self.currentSessionStats.numRemaining];

        [JDStatusBarNotification showWithStatus:statusString];
        [JDStatusBarNotification showProgress:self.currentSessionStats.progress];
    } else {
        [JDStatusBarNotification showWithStatus:@"Upload complete." dismissAfter:2];
    }
}

#pragma mark - Internal Helper Functions


- (RKObjectManager *)objectManager {
    if (!_objectManager) {
        NSURL *baseURL = [[DFUser currentUser] serverURL];
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


#pragma mark - Core Data helpers


- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [[DFPhotoStore sharedStore] persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}



@end
