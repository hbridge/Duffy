//
//  DFUploadOperation.h
//  Duffy
//
//  Created by Henry Bridge on 4/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFNetworkingConstants.h"

@interface DFUploadOperation : NSOperation





typedef void (^DFPhotoUploadOperationSuccessBlock)(NSDictionary *resultDict);
typedef void (^DFPhotoUploadOperationFailureBlock)(NSDictionary *resultDict, BOOL isCancelled);

@property (nonatomic, retain) NSArray *photoIDs;
@property (nonatomic) DFPhotoUploadOperationImageDataType uploadOperationType;
@property (nonatomic, retain) NSOperationQueue *completionOperationQueue;
@property (nonatomic, copy) DFPhotoUploadOperationSuccessBlock successBlock;
@property (nonatomic, copy) DFPhotoUploadOperationFailureBlock failureBlock;


- (id)initWithPhotoIDs:(NSArray *)photoIDs
   uploadOperationType:(DFPhotoUploadOperationImageDataType)imageUploadType;

@end
