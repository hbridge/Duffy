//
//  DFNUXFlowViewController.h
//  Strand
//
//  Created by Henry Bridge on 1/23/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFNavigationController.h"
#import "DFNUXViewController.h"

@interface DFNUXFlowViewController : DFNavigationController <DFNUXViewControllerDelegate>

/* data accumulated from other nux steps */
@property (nonatomic, retain) NSMutableDictionary *allUserInfo;

@end
