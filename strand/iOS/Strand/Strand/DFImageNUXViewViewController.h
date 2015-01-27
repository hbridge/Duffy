//
//  DFImageNUXViewViewController.h
//  Strand
//
//  Created by Henry Bridge on 1/23/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFNUXViewController.h"

@interface DFImageNUXViewViewController : DFNUXViewController
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *explanationLabel;
@property (weak, nonatomic) IBOutlet UIButton *button;

@property (nonatomic, retain) NSString *titleText;
@property (nonatomic, retain) UIImage *image;
@property (nonatomic, retain) NSString *explanation;
@property (nonatomic, retain) NSString *buttonTitle;

- (IBAction)buttonPressed:(id)sender;
- (instancetype)initWithTitle:(NSString *)title
                          image:(UIImage *)image
                explanationText:(NSString *)explanation
                    buttonTitle:(NSString *)buttonTitle;

@end
