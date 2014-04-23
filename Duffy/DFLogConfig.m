//
//  DFLogConfig.m
//  Duffy
//
//  Created by Henry Bridge on 4/23/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFLogConfig.h"

#ifdef DEBUG
int const ddLogLevel = LOG_LEVEL_VERBOSE;
#else
int const ddLogLevel = LOG_LEVEL_WARN;
#endif