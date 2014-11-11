//
//  DFNoResultsTableViewCell.h
//  Strand
//
//  Created by Henry Bridge on 10/26/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFNoResultsTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *noResultsLabel;

+ (CGFloat)desiredHeight;

@end
