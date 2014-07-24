//
//  DFPhotoFeedController.h
//  Strand
//
//  Created by Henry Bridge on 7/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPhotoFeedCell.h"

@interface DFPhotoFeedController : UITableViewController <UIActionSheetDelegate, DFPhotoFeedCellDelegate>

- (IBAction)cameraButtonPressed:(id)sender;
- (IBAction)inviteButtonPressed:(id)sender;
- (void)jumpToPhoto:(DFPhotoIDType)photoID;

@end
