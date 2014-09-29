//
//  OFElementSquare.h
//  CocktailGuide
//
//  Created by Henry Bridge on 10/10/13.
//  Copyright (c) 2013 Old Fashioned Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OFElementSquare : UIView

typedef enum {
    OFElementSquareDisplayAbbreviation = 0,
    OFElementSquareDisplayName
} OFElementSquareDisplayMode;

@property (nonatomic, strong) NSString *elementAbbreviation;
@property (nonatomic, strong) NSString *elementName;
@property (nonatomic) OFElementSquareDisplayMode displayMode;
@property (nonatomic, strong) NSString *fontName;
@property (nonatomic) UIEdgeInsets insets;

@end
