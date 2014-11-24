//
//  DFSwapAddPhotosCell.h
//  Strand
//
//  Created by Henry Bridge on 11/20/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFSwapAddPhotosCell : UITableViewCell

@property (nonatomic, copy) void (^cancelBlock)(void);
@property (nonatomic, copy) void (^okBlock)(void);
- (IBAction)cancelPressed:(id)sender;
- (IBAction)okPressed:(id)sender;

@end
