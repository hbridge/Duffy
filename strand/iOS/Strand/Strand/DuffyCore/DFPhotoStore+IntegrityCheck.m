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
    
    result |= [self findDuplicatesForALAssetsWithContext:context];
    
    DDLogInfo(@"Integrity check completed, result = %d", result);
    return result;
}


- (DFPhotoStoreIntegrityCheckResult)findDuplicatesForALAssetsWithContext:(NSManagedObjectContext *)managedObjectContext
{
    DFPhotoStoreIntegrityCheckResult result = DFIntegrityResultNoError;
    
    DFPhotoCollection *allPhotos = [DFPhotoStore allPhotosCollectionUsingContext:managedObjectContext];
    if (allPhotos.photoURLSet.count < allPhotos.photoSet.count) { // if we have fewer URLs than we have photos, there are dupes per URL
        unsigned long numDupesRemoved = 0;
        NSMutableSet *urlsNotTaken = [allPhotos.photoURLSet mutableCopy];
        
        for (DFPhoto *photo in allPhotos.photoSet) {
            if ([urlsNotTaken containsObject:photo.asset.canonicalURL]) {
                [urlsNotTaken removeObject:photo.asset.canonicalURL];
            } else {
                [managedObjectContext deleteObject:photo];
                numDupesRemoved++;
            }
        }
        
        result = DFIntegrityResultErrorsFixed;
        DDLogWarn(@"%lu duplicates detected and removed.", numDupesRemoved);
    }
    
    return result;
}

@end
