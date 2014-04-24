//
//  DFUploadProgressView.m
//  Duffy
//
//  Created by Henry Bridge on 4/9/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFUploadProgressView.h"

@implementation DFUploadProgressView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}


- (void)awakeFromNib
{
    DDLogVerbose(@"uploadview awake");
}

- (id) awakeAfterUsingCoder:(NSCoder*)aDecoder {
    BOOL theThingThatGotLoadedWasJustAPlaceholder = ([[self subviews] count] == 0);
    if (theThingThatGotLoadedWasJustAPlaceholder) {
        DFUploadProgressView* theRealThing = (id) [DFUploadProgressView loadInstanceOfViewFromNib];
        
        // pass properties through
        theRealThing.frame = self.frame;
        theRealThing.autoresizingMask = self.autoresizingMask;
        theRealThing.alpha = self.alpha;
        theRealThing.hidden = self.hidden;
        theRealThing.backgroundColor = self.backgroundColor;
        
        return theRealThing;
    }
    return self;
}


+ (id)loadInstanceOfViewFromNib
{
    UINib *nib = [UINib nibWithNibName:@"DFUploadProgressView" bundle:nil];
    return [[nib instantiateWithOwner:nil options:nil] firstObject];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
