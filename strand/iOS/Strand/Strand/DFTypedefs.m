#import "DFTypedefs.h"




// Permission types
DFPermissionType const DFPermissionRemoteNotifications = @"RemoteNotifications";
DFPermissionType const DFPermissionLocation = @"Location";
DFPermissionType const DFPermissionPhotos = @"Photos";
DFPermissionType const DFPermissionContacts = @"Contacts";


// Permission states
DFPermissionStateType const DFPermissionStateNotRequested = @"NotRequested";
DFPermissionStateType const DFPermissionStatePreRequested = @"PreRequested";
DFPermissionStateType const DFPermissionStateGranted = @"Granted";
DFPermissionStateType const DFPermissionStateDenied = @"Denied";
DFPermissionStateType const DFPermissionStateUnavailable = @"Unavailable";
DFPermissionStateType const DFPermissionStateRestricted = @"Restricted";

DFActionType DFActionButtonPress = @"ButtonPress";
DFActionType DFActionDoubleTap = @"DoubleTap";
