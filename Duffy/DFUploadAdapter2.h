//
//  DFUploadAdapter2.h
//  Duffy
//
//  Created by Henry Bridge on 4/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFUploadAdapter2 : NSObject

- (NSOperation *)uploadOperationForDFPhotoObjectID:(NSManagedObjectID *)DFPhotoID;


@end
