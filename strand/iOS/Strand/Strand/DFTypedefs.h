

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

// Permission States
typedef NSString *DFPermissionStateType;

extern DFPermissionStateType const DFPermissionStateNotRequested;
extern DFPermissionStateType const DFPermissionStateGranted;
extern DFPermissionStateType const DFPermissionStateDenied;
extern DFPermissionStateType const DFPermissionStateUnavailable;

// Screens
typedef enum {
  DFScreenNone = -1,
  DFScreenCamera,
  DFScreenGallery
} DFScreenType;