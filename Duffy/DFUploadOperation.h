//
//  DFUploadOperation.h
//  Duffy
//
//  Created by Henry Bridge on 4/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFUploadOperation : NSOperation

typedef void (^DFPhotoUploadOperationSuccessBlock)(NSUInteger numImageBytes);
typedef void (^DFPhotoUploadOperationFailureBlock)(NSError *error, BOOL isCancelled);

@property (nonatomic, retain) NSManagedObjectID *photoID;
@property (nonatomic, retain) NSOperationQueue *completionOperationQueue;
@property (nonatomic, copy) DFPhotoUploadOperationSuccessBlock successBlock;
@property (nonatomic, copy) DFPhotoUploadOperationFailureBlock failureBlock;


- (id)initWithPhotoID:(NSManagedObjectID *)photoID;

@end
