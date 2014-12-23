//
//  DFSection.h
//  Strand
//
//  Created by Henry Bridge on 12/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFSection : NSObject

@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) id object;
@property (nonatomic, retain) NSArray *rows;


+ (DFSection *)sectionWithTitle:(NSString *)title
                         object:(id)object
                           rows:(NSArray *)rows;

@end
