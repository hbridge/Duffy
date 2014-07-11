//
//  DFPeanutActionAdapter.h
//  Strand
//
//  Created by Henry Bridge on 7/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFNetworkAdapter.h"
#import "DFPeanutAction.h"

@interface DFPeanutActionAdapter : NSObject <DFNetworkAdapter>

typedef void (^DFPeanutActionResponseBlock)(DFPeanutAction *action, NSError *error);


- (void)postAction:(DFPeanutAction *)action
withCompletionBlock:(DFPeanutActionResponseBlock)completionBlock;

@end
