//
//  DFPeanutUserObject.h
//  Strand
//
//  Created by Henry Bridge on 7/7/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"
#import "DFUser.h"

@interface DFPeanutUserObject : NSObject <DFPeanutObject>

@property (nonatomic) DFUserIDType id;
@property (nonatomic, retain) NSString *phone_number;
@property (nonatomic, retain) NSString *display_name;
@property (nonatomic, retain) NSString *auth_token;

@end
