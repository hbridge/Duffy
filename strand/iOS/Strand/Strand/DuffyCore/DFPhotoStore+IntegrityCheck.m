//
//  DFPhotoStore+IntegrityCheck.m
//  Duffy
//
//  Created by Henry Bridge on 4/24/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoStore+IntegrityCheck.h"
#import "DFPhoto.h"

@implementation DFPhotoStore (IntegrityCheck)


- (DFPhotoStoreIntegrityCheckResult)checkForErrorsAndRepairWithContext:(NSManagedObjectContext *)context;
{
    DDLogInfo(@"Integrity check started.");
    DFPhotoStoreIntegrityCheckResult result = DFIntegrityResultNoError;
        
    DDLogInfo(@"Integrity check completed, result = %d", result);
    return result;
}


@end
