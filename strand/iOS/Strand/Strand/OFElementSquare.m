//
//  OFElementSquare.m
//  CocktailGuide
//
//  Created by Henry Bridge on 10/10/13.
//  Copyright (c) 2013 Old Fashioned Software. All rights reserved.
//

#import "OFElementSquare.h"

@interface OFElementSquare ()

@property (nonatomic) CGFloat fontSize;
@property (nonatomic, retain) UIFont *font;
@property (atomic, retain) NSString *displayedText;

@end

@implementation OFElementSquare

@synthesize elementAbbreviation;
@synthesize elementName;
@synthesize fontName;
@synthesize insets;
@synthesize displayMode;

static CGFloat const INSETS_DEFAULT = 5.0f;
static CGFloat const MAX_FONT_SIZE = 128.0f;




- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.insets = UIEdgeInsetsMake(INSETS_DEFAULT, INSETS_DEFAULT, INSETS_DEFAULT, INSETS_DEFAULT);
        self.fontSize = 0.0;
        self.fontName = @"Avenir-Light";
    }
    return self;
}

- (void)setElementAbbreviation:(NSString *)newElementAbbreviation
{
    elementAbbreviation = newElementAbbreviation;
    self.displayMode = self.displayMode;
}


- (void)setElementName:(NSString *)newElementName
{
    elementName = newElementName;
    self.displayMode = self.displayMode;
}

- (void)setDisplayMode:(OFElementSquareDisplayMode)newDisplayMode
{
    displayMode = newDisplayMode;
    
    if (self.displayMode == OFElementSquareDisplayAbbreviation) {
        _displayedText = self.elementAbbreviation;
    } else {
        _displayedText = [self.elementName stringByReplacingOccurrencesOfString:@" " withString:@"\n"];
    }
    [self calculateFontSize];
}

- (void)calculateFontSize
{
    if (self.bounds.size.width == 0 || self.bounds.size.height == 0|| !self.displayedText || [self.displayedText isEqualToString:@""] ) {
        self.fontSize = 0;
        return;
    }
    
    CGRect textArea = CGRectInset(self.frame, (self.insets.left + self.insets.right)/2.0, (self.insets.top + self.insets.bottom)/2.0);
    CGFloat curSize = MAX_FONT_SIZE;
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    while (curSize >= 0.0) {
        [attributes setValue:[UIFont fontWithName:self.fontName size:curSize] forKey:NSFontAttributeName];
        CGSize textSize = [self.displayedText sizeWithAttributes:attributes];
        if (textSize.width <= textArea.size.width && textSize.height <= textArea.size.height) {
            self.fontSize = curSize;
            break;
        }
        curSize -= 0.5;
    }
    
    
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self calculateFontSize];
}

- (void)setFontSize:(CGFloat)fontSize {
    _fontSize = fontSize;
    self.font = [UIFont fontWithName:self.fontName size:self.fontSize];
}

- (void)setFontName:(NSString *)newName
{
    fontName = newName;
    self.font = [UIFont fontWithName:fontName size:self.fontSize];
    [self calculateFontSize];
}

- (void)drawRect:(CGRect)rect
{
    CGRect textRect;
    
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                self.font, NSFontAttributeName,
                                [UIColor whiteColor], NSForegroundColorAttributeName,
                                paragraphStyle,NSParagraphStyleAttributeName,
                                nil];
    textRect.size = [self.displayedText sizeWithAttributes:attributes];
    // Let's put that string in the center of the view
    CGPoint center = CGPointMake(rect.origin.x + rect.size.width/2, rect.origin.y + rect.size.height/2);
    textRect.origin.x = center.x - textRect.size.width / 2.0;
    textRect.origin.y = center.y - textRect.size.height / 2.0; // Set the fill color of the current context to black
    [self.displayedText drawInRect:textRect withAttributes:attributes];
}

@end
