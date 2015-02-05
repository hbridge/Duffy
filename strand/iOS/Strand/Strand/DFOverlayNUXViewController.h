//
//  DFOverlayNUXViewController.h
//  Strand
//
//  Created by Henry Bridge on 2/5/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SAMGradientView/SAMGradientView.h>

typedef enum {
  DFoverlayNUXTypeSuggestions = 0,
} DFOverlayNuxType;


@interface DFOverlayNUXViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIImageView *topImageView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *explanatoryTextLabel;
@property (weak, nonatomic) IBOutlet SAMGradientView *explanatoryGradientView;

@property (readonly, nonatomic) DFOverlayNuxType nuxType;


- (instancetype)initWithOverlayNUXType:(DFOverlayNuxType)nuxType;

@end
