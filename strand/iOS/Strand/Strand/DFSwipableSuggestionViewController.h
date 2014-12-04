//
//  DFSwipableSuggestionViewController.h
//  Strand
//
//  Created by Henry Bridge on 12/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSuggestionViewController.h"
#import "DFCardinalImageView.h"

@interface DFSwipableSuggestionViewController : DFSuggestionViewController <DFCardinalImageViewDelegate>

@property (weak, nonatomic) IBOutlet DFProfileStackView *profileStackView;
@property (weak, nonatomic) IBOutlet UILabel *topLabel;
@property (weak, nonatomic) IBOutlet UILabel *bottomLabel;
@property (weak, nonatomic) IBOutlet DFCardinalImageView *cardinalImageView;

@end
