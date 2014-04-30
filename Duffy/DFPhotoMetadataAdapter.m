//
//  DFPhotoMetadataAdapter.m
//  Duffy
//
//  Created by Henry Bridge on 4/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoMetadataAdapter.h"
#import <RestKit/RestKit.h>
#import "DFPhoto.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFObjectManager.h"



@interface DFPhotoMetadataAdapter()

@property (nonatomic, retain) RKObjectManager *objectManager;

@end


@interface DFPeanutPhoto : NSObject

@property (nonatomic) UInt64 user;
@property (nonatomic) UInt64 id;
@property (nonatomic, retain) NSString *time_taken;
@property (nonatomic, retain) NSDictionary *metadata;

- (id)initWithDFPhoto:(DFPhoto *)photo;

@end
@implementation DFPeanutPhoto


+ (void)initialize
{
    [DFObjectManager registerAdapterClass:[DFPhotoMetadataAdapter class]];
}

- (id)initWithDFPhoto:(DFPhoto *)photo
{
    self = [super init];
    if (self) {
        self.user = photo.userID;
        self.id = photo.photoID;
        NSDateFormatter *djangoFormatter = [NSDateFormatter DjangoDateFormatter];
        self.time_taken = [djangoFormatter stringFromDate:photo.creationDate];
        self.metadata = photo.metadataDictionary;
    }
    return self;
}

+ (NSArray *)attributes
{
    return @[@"user", @"id", @"time_taken", @"metadata"];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"DFPeanutPhoto: user:%d id:%d time_taken:%@ metadata:%@",
            (int)self.user, (int)self.id, self.time_taken, self.metadata.description];
}

@end

@implementation DFPhotoMetadataAdapter


- (id)initWithObjectManager:(RKObjectManager *)manager
{
    self = [super init];
    if (self) {
        self.objectManager = manager;
    }
    return self;
}


+ (NSArray *)requestDescriptors
{
    RKObjectMapping *photoMapping = [RKObjectMapping mappingForClass:[DFPeanutPhoto class]];
    [photoMapping addAttributeMappingsFromArray:[DFPeanutPhoto attributes]];
    
    RKRequestDescriptor *requestDescriptor =
    [RKRequestDescriptor requestDescriptorWithMapping:[photoMapping inverseMapping]
                                          objectClass:[DFPeanutPhoto class]
                                          rootKeyPath:nil
                                               method:RKRequestMethodPOST];
    
    return [NSArray arrayWithObjects:requestDescriptor, nil];
}

+ (NSArray *)responseDescriptors
{
    RKObjectMapping *photoMapping = [RKObjectMapping mappingForClass:[DFPeanutPhoto class]];
    [photoMapping addAttributeMappingsFromArray:[DFPeanutPhoto attributes]];

    RKResponseDescriptor *responseDescriptor =
    [RKResponseDescriptor responseDescriptorWithMapping:photoMapping
                                                 method:RKRequestMethodAny pathPattern:nil
                                                keyPath:nil
                                            statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    return [NSArray arrayWithObjects:responseDescriptor, nil];
}

- (void)postPhoto:(DFPhoto *)photo
{
    DFPeanutPhoto *peanutPhoto = [[DFPeanutPhoto alloc] initWithDFPhoto:photo];
    
    NSMutableURLRequest *request = [self.objectManager requestWithObject:peanutPhoto method:RKRequestMethodPOST path:@"photos/" parameters:nil];
    RKObjectRequestOperation *requestOperation = [self.objectManager objectRequestOperationWithRequest:request success:nil failure:nil];
    [self.objectManager enqueueObjectRequestOperation:requestOperation];
    
    [requestOperation waitUntilFinished];
    
    if (requestOperation.error) {
        DDLogWarn(@"DFPhotoMetadataAdapter post failed: %@", requestOperation.error.localizedDescription);
    } else {
        DFPeanutPhoto *resultPeanutPhoto = [requestOperation.mappingResult firstObject];
        DDLogInfo(@"DFPhotoMetadataAdapter post succeeded, result photo: %@", resultPeanutPhoto);
        photo.photoID = resultPeanutPhoto.id;
    }
}


@end
