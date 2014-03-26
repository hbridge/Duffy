//
//  DFPhotoNavigationControllerViewController.m
//  Duffy
//
//  Created by Henry Bridge on 3/26/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoNavigationControllerViewController.h"
#import "DFPhotoViewController.h"
#import "DFMultiPhotoViewController.h"
#import "DFPhotosGridViewController.h"

@interface DFPhotoNavigationControllerViewController ()

@property (nonatomic, retain) UIImageView *zoomedCellImageView;
@property (nonatomic, retain) UIView *pushedCellView;
@property (nonatomic) CGRect pushedCellViewOriginalFrame;
@property (atomic) BOOL isPushingPhoto;

@end

@implementation DFPhotoNavigationControllerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


+ (CGRect) aspectFittedSize:(CGSize)inSize max:(CGRect)maxRect
{
	float originalAspectRatio = inSize.width / inSize.height;
	float maxAspectRatio = maxRect.size.width / maxRect.size.height;
    
	CGRect newRect = maxRect;
	if (originalAspectRatio > maxAspectRatio) { // scale by width
		newRect.size.height = maxRect.size.width * (inSize.height / inSize.width);
		newRect.origin.y += (maxRect.size.height - newRect.size.height)/2.0;
	} else {
		newRect.size.width = maxRect.size.height  * inSize.width / inSize.height;
		newRect.origin.x += (maxRect.size.width - newRect.size.width)/2.0;
	}
    
	return CGRectIntegral(newRect);
}

static const CGFloat AnimationDuration = 0.3f;

- (void)pushMultiPhotoViewController:(DFMultiPhotoViewController *)multiPhotoViewController
        withFrontPhotoViewController:(DFPhotoViewController *)photoViewController
                        fromCellView:(UIView *)cellView
             withFrameInScreenCoords:(CGRect)frame
{
    if (self.isPushingPhoto) return;
    self.isPushingPhoto = YES;
    
    self.zoomedCellImageView = [[UIImageView alloc] initWithImage:photoViewController.image];
    self.zoomedCellImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.zoomedCellImageView.clipsToBounds = YES;
    
    self.pushedCellView = cellView;
    self.zoomedCellImageView.frame = frame;
    [self.view addSubview:self.zoomedCellImageView];
    cellView.alpha = 0.0;
    photoViewController.imageView.alpha = 0.0;
    
    [UIView animateWithDuration:AnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.zoomedCellImageView.frame = [DFPhotoNavigationControllerViewController aspectFittedSize:self.zoomedCellImageView.image.size max:[[UIScreen mainScreen] bounds]];
    } completion:^(BOOL finished) {
        photoViewController.imageView.alpha = 1.0;
        cellView.alpha =  1.0;
        [self.zoomedCellImageView removeFromSuperview];
        self.isPushingPhoto = NO;
    }];
    
    CATransition* transition = [CATransition animation];
    transition.duration = AnimationDuration;
    transition.type = kCATransitionFade;
    [self.view.layer addAnimation:transition forKey:kCATransition];
    
    [super pushViewController:multiPhotoViewController animated:NO];
}

- (void)zoomImage:(UIImage *)image backToCellAtIndexPath:(NSIndexPath *)parentIndexPath
{
    self.zoomedCellImageView.image = image;
    
    DFPhotosGridViewController *gridController =
        (DFPhotosGridViewController *)[self.viewControllers objectAtIndex:self.viewControllers.count-2];
    UICollectionViewCell *cell = [gridController.collectionView cellForItemAtIndexPath:parentIndexPath];
    cell.alpha = 0.0;
    CGRect cellFrame = [gridController frameForCellAtIndexPath:parentIndexPath];

    [self.view addSubview:self.zoomedCellImageView];
    [UIView animateWithDuration:AnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.zoomedCellImageView.frame = cellFrame;
    } completion:^(BOOL finished) {
        if (finished) {
            cell.alpha = 1.0;
            [self.zoomedCellImageView removeFromSuperview];
            self.zoomedCellImageView = nil;
            
        }
    }];
}


- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    if ([self.visibleViewController isKindOfClass:[DFMultiPhotoViewController class]]) {
        DFPhotoViewController *currentPhotoViewController = ((DFMultiPhotoViewController *)self.visibleViewController).currentPhotoViewController;
        NSIndexPath *parentIndexPath = currentPhotoViewController.indexPathInParent;
        
        
        [self zoomImage:currentPhotoViewController.image backToCellAtIndexPath:parentIndexPath];
        return [super popViewControllerAnimated:NO];
    } else {
        return [super popViewControllerAnimated:animated];
    }
}

@end
