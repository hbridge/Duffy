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
#import "DFCGRectHelpers.h"

@interface DFPhotoNavigationControllerViewController ()

@property (nonatomic, retain) UIImageView *animatingImageView;

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

static const CGFloat AnimationDuration = 0.3f;

- (void)pushMultiPhotoViewController:(DFMultiPhotoViewController *)multiPhotoViewController
        withFrontPhotoViewController:(DFPhotoViewController *)photoViewController
            fromPhotosGridController:(DFPhotosGridViewController *)photosGridController
                     itemAtIndexPath:(NSIndexPath *)indexPath
{
    // get the tapped cell and its frame so we can animate from it
    // using tappedCell.frame is unreliable since the view may be hidden, so ask the controller itself
    UIView *tappedCell = [photosGridController.collectionView cellForItemAtIndexPath:indexPath];
    CGRect tappedCellFrame = [photosGridController frameForCellAtIndexPath:indexPath];
    [self animateTappedCell:tappedCell
                  withFrame:tappedCellFrame
              upToFullImage:photoViewController.image
       displayedInImageView:photoViewController.imageView];
    
    
    [super pushViewController:multiPhotoViewController animated:NO];
}

- (void)animateTappedCell:(UIView *)tappedCell
                withFrame:(CGRect)frame
            upToFullImage:(UIImage *)image
     displayedInImageView:(UIImageView *)imageView
{
    // create the image view that will scale upward
    self.animatingImageView = [[UIImageView alloc] initWithImage:image];
    self.animatingImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.animatingImageView.clipsToBounds = YES;
    self.animatingImageView.frame = frame;
    [self.view addSubview:self.animatingImageView];
    
    // set the original non animating views to be clear while the animation is happening
    tappedCell.alpha = 0.0;
    imageView.alpha = 0.0;
    
    // animate the photo zoom
    [UIView animateWithDuration:AnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.animatingImageView.frame = [DFCGRectHelpers aspectFittedSize:self.animatingImageView.image.size max:[[UIScreen mainScreen] bounds]];
    } completion:^(BOOL finished) {
        imageView.alpha = 1.0;
        tappedCell.alpha =  1.0;
        [self.animatingImageView removeFromSuperview];
    }];
    
    // animate the navigation controller changes
    CATransition* transition = [CATransition animation];
    transition.duration = AnimationDuration;
    transition.type = kCATransitionFade;
    [self.view.layer addAnimation:transition forKey:kCATransition];
}

- (void)animateFullImage:(UIImage *)image backToCell:(UIView *)cell withFrame:(CGRect)frame
{
    self.animatingImageView.image = image;
    cell.alpha = 0.0;
    
    [self.view addSubview:self.animatingImageView];
    [UIView animateWithDuration:AnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.animatingImageView.frame = frame;
    } completion:^(BOOL finished) {
        if (finished) {
            cell.alpha = 1.0;
            [self.animatingImageView removeFromSuperview];
            self.animatingImageView = nil;
            
        }
    }];
}

- (UIViewController *)popMultiPhotoViewController
{
    // get the current photo view controller so we can set the image and figure out which cell it is in the parent
    DFPhotoViewController *currentPhotoViewController =
        ((DFMultiPhotoViewController *)self.visibleViewController).currentPhotoViewController;
    NSIndexPath *parentIndexPath = currentPhotoViewController.indexPathInParent;
    DFPhotosGridViewController *gridController =
        (DFPhotosGridViewController *)[self.viewControllers objectAtIndex:self.viewControllers.count-2];
    UICollectionViewCell *cell = [gridController.collectionView cellForItemAtIndexPath:parentIndexPath];
    CGRect destinationFrame = [gridController frameForCellAtIndexPath:parentIndexPath];
    
    
    [self animateFullImage:currentPhotoViewController.image
                backToCell:cell
                 withFrame:destinationFrame];
    
    return [super popViewControllerAnimated:NO];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    if ([self.visibleViewController isKindOfClass:[DFMultiPhotoViewController class]]) {
        return [self popMultiPhotoViewController];
    } else {
        return [super popViewControllerAnimated:animated];
    }
}

#pragma mark - Helpers



@end
