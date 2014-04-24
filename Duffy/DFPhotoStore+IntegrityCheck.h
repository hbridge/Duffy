//
//  DFPhotoStore+IntegrityCheck.h
//  Duffy
//
//  Created by Henry Bridge on 4/24/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoStore.h"

@interface DFPhotoStore (IntegrityCheck)

typedef enum {
    DFIntegrityResultNoError,
    DFIntegrityResultErrorsFixed,
    DFIntegrityResultErrorsUnfixable,
} DFPhotoStoreIntegrityCheckResult;


- (DFPhotoStoreIntegrityCheckResult)checkForErrorsAndRepairWithContext:(NSManagedObjectContext *)context;

@end
