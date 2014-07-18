//
//  DFPermissionsHelpers.h
//  Strand
//
//  Created by Henry Bridge on 7/18/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFTypedefs.h"

@interface DFPermissionsHelpers : NSObject

+ (BOOL)recordAndLogPermission:(DFPermissionType)permission
                     changedTo:(DFPermissionStateType)currentState;

@end
