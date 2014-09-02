//
//  DFABResultTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 9/2/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFABResultTableViewCell.h"

@implementation DFABResultTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)awakeFromNib
{
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
