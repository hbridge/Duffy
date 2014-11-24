//
//  DFSwapSuggestionTableViewCell.h
//  Strand
//
//  Created by Henry Bridge on 11/21/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSwapTableViewCell.h"

@interface DFSwapSuggestionTableViewCell : DFSwapTableViewCell

@property (weak, nonatomic) IBOutlet DFProfileStackView *profilePhotoStackView;
@property (weak, nonatomic) IBOutlet UILabel *peopleLabel;
@property (weak, nonatomic) IBOutlet UILabel *subTitleLabel;
@property (weak, nonatomic) IBOutlet UIImageView *previewImageView;
@property (weak, nonatomic) IBOutlet UIImageView *profileReplacementImageView;

@end
