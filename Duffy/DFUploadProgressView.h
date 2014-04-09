//
//  DFUploadProgressView.h
//  Duffy
//
//  Created by Henry Bridge on 4/9/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFUploadProgressView : UIView

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *leftLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

@end
