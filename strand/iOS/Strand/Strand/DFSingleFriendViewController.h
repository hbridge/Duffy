//
//  DFSingleFriendViewController.h
//  Strand
//
//  Created by Derek Parham on 10/13/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutUserObject.h"

@interface DFSingleFriendViewController : UITableViewController

- (instancetype)initWithUser:(DFPeanutUserObject *)user withSharedPhotos:(BOOL)sharedPhotos;

@end
