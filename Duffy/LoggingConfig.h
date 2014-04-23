#import "LoggingConfig.h"

#import <CocoaLumberjack/DDLog.h>

#ifdef DEBUG
int const ddLogLevel = LOG_LEVEL_VERBOSE;
#else
int const ddLogLevel = LOG_LEVEL_WARN;
#endif