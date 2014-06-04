//
//  DFJSONConvertible.h
//  Duffy
//
//  Created by Henry Bridge on 5/13/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DFJSONConvertible <NSObject>

@required
- (id)initWithJSONDict:(NSDictionary *)jsonDict;
- (NSDictionary *)JSONDictionary;

@optional
- (NSString *)JSONString;

@end
