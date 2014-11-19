//
//  DFFeedSectionHeaderView.h
//  Strand
//
//  Created by Henry Bridge on 7/21/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFProfileStackView.h"

@class DFFeedSectionHeaderView;

@interface DFFeedSectionHeaderView : UITableViewHeaderFooterView
@property (weak, nonatomic) IBOutlet DFProfileStackView *profilePhotoStackView;
@property (weak, nonatomic) IBOutlet UILabel *actorLabel;
@property (strong, nonatomic) IBOutlet UIView *backgroundView;

@property (nonatomic, retain) NSObject *representativeObject;

+ (CGFloat)height;

@end
