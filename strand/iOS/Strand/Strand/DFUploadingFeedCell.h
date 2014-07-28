//
//  DFUploadingFeedCell.h
//  Strand
//
//  Created by Henry Bridge on 7/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFUploadingFeedCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *thumbnailImageView;
@property (weak, nonatomic) IBOutlet UILabel *statusTextLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIButton *retryButton;
- (IBAction)retryButtonPressed:(UIButton *)sender;

@end
