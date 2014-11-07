//
//  DFPhotoPickerHeaderReusableView.h
//  Strand
//
//  Created by Henry Bridge on 10/23/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFPhotoPickerHeaderReusableView : UICollectionReusableView

@property (weak, nonatomic) IBOutlet UILabel *locationLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UIButton *shareButton;
@property (weak, nonatomic) IBOutlet UIImageView *badgeIconView;
@property (weak, nonatomic) IBOutlet UILabel *badgeIconText;

typedef void (^DFPhotoPickerHeaderShareCallback)(void);

@property (nonatomic, copy) DFPhotoPickerHeaderShareCallback shareCallback;
- (IBAction)shareButtonPressed:(id)sender;

@property (nonatomic, copy) DFVoidBlock removeSuggestionCallback;
- (IBAction)removeSuggestionButtonPressed:(UIButton *)sender;
@property (weak, nonatomic) IBOutlet UIButton *removeSuggestionButton;


typedef NS_OPTIONS(NSInteger, DFPhotoPickerHeaderStyle) {
  DFPhotoPickerHeaderStyleTimeOnly = 0,
  DFPhotoPickerHeaderStyleLocation = 1 << 1,
  DFPhotoPickerHeaderStyleBadge = 1 << 2,
};

- (void)configureWithStyle:(DFPhotoPickerHeaderStyle)style;
+ (CGFloat)heightForStyle:(DFPhotoPickerHeaderStyle)style;

@end
