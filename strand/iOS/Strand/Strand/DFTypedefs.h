
// User type
typedef UInt64 DFUserIDType;

// Photo types
typedef UInt64 DFPhotoIDType;
typedef NS_OPTIONS(unsigned int, DFImageType) {
  DFImageNone,
  DFImageFull,
  DFImageThumbnail,
};


// Permissions
typedef NSString *DFPermissionType;
extern DFPermissionType const DFPermissionRemoteNotifications;
extern DFPermissionType const DFPermissionLocation;
extern DFPermissionType const DFPermissionPhotos;
extern DFPermissionType const DFPermissionContacts;

// Permission States
typedef NSString *DFPermissionStateType;

extern DFPermissionStateType const DFPermissionStateNotRequested;
extern DFPermissionStateType const DFPermissionStatePreRequestedNotNow;
extern DFPermissionStateType const DFPermissionStatePreRequestedYes;
extern DFPermissionStateType const DFPermissionStateGranted;
extern DFPermissionStateType const DFPermissionStateDenied;
extern DFPermissionStateType const DFPermissionStateUnavailable;
extern DFPermissionStateType const DFPermissionStateRestricted;

// Screens
typedef enum {
  DFScreenNone = -1,
  DFScreenCamera,
  DFScreenGallery
} DFScreenType;

// Push notif types
typedef enum {
  DFPushNotifUnknown = 0,
  DFPushNotifNewPhotos = 1,
  DFPushNotifJoinable = 2,
  DFPushNotifFavorited = 3,
  DFPushNotifFetchGPS = 4,
  DFPushNotifFirestarter = 5,
  DFPushNotifFirestarterPhotoTaken = 6,
  DFPushNotifRefreshFeed = 7
} DFPushNotifType;

typedef NSString *DFUIActionType;
extern DFUIActionType DFUIActionButtonPress;
extern DFUIActionType DFUIActionDoubleTap;

typedef NSString *const DFPeanutActionType;
extern DFPeanutActionType DFPeanutActionFavorite;
