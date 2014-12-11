//
//  DFEvaluatedPhotoViewController.h
//  Strand
//
//  Created by Henry Bridge on 12/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFHomeSubViewController.h"
#import "DFProfileStackView.h"

@interface DFEvaluatedPhotoViewController : DFHomeSubViewController

@property (nonatomic) DFPhotoIDType photoID;
@property (nonatomic) DFStrandIDType strandID;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet DFProfileStackView *profileStackView;

- (instancetype)initWithPhotoID:(DFPhotoIDType)photoID
                       inStrand:(DFStrandIDType)strandID;

@end
