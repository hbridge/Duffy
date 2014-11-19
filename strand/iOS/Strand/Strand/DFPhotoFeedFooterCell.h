//
//  DFPhotoFeedFooterCell.h
//  Strand
//
//  Created by Henry Bridge on 11/19/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFPhotoFeedFooterCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIButton *commentButton;
@property (weak, nonatomic) IBOutlet UIButton *moreButton;

@property (nonatomic, copy) void (^commentBlock)(void);
@property (nonatomic, copy) void (^moreBlock)(void);

+ (CGFloat)height;

- (IBAction)commentButtonPressed:(id)sender;
- (IBAction)moreButtonPressed:(id)sender;

@end
