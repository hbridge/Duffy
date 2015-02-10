//
//  DFBorderedTextField.h
//  Strand
//
//  Created by Henry Bridge on 2/10/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

IB_DESIGNABLE
@interface DFBorderedTextField : UITextField

@property (nonatomic) IBInspectable CGFloat topBorder;
@property (nonatomic) IBInspectable CGFloat bottomBorder;
@property (nonatomic) IBInspectable CGFloat leftBorder;
@property (nonatomic) IBInspectable CGFloat rightBorder;
@property (nonatomic) IBInspectable CGFloat leftInset;
@property (nonatomic, retain) IBInspectable UIColor *borderColor;

@end
