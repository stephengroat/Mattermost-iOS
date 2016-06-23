//
//  KGSideMenuContainerViewController.m
//  Envolved
//
//  Created by Dmitry Arbuzov on 19/01/16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

#import "KGSideMenuContainerViewController.h"
#import "KGNavigationController.h"
#import "KGConstants.h"
#import "KGLeftMenuViewController.h"
#import "KGRightMenuViewController.h"
#import "UIStatusBar+SharedBar.h"
#import <Masonry/Masonry.h>


// Public Morozov
@interface MFSideMenuContainerViewController()

- (void) setCenterViewControllerOffset:(CGFloat)xOffset;

@end

@interface KGSideMenuContainerViewController ()
@property (nonatomic, assign) CGFloat *oldX;
@end

@implementation KGSideMenuContainerViewController

#pragma mark - Init

+ (instancetype)containerWithCenterViewController:(id)centerViewController
                           leftMenuViewController:(id)leftMenuViewController
                          rightMenuViewController:(id)rightMenuViewController {
    KGSideMenuContainerViewController *controller = [KGSideMenuContainerViewController new];
    controller.leftMenuViewController = leftMenuViewController;
    controller.centerViewController = centerViewController;
    controller.rightMenuViewController = rightMenuViewController;
    return controller;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDefault;
}


+ (instancetype)configuredContainerViewController {
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Chat" bundle:nil];
    UINavigationController *navController = [sb instantiateInitialViewController];
    KGLeftMenuViewController *leftMenuViewController = [sb instantiateViewControllerWithIdentifier:NSStringFromClass([KGLeftMenuViewController class])];
    KGRightMenuViewController *rightMenuViewController = [sb instantiateViewControllerWithIdentifier:NSStringFromClass([KGRightMenuViewController class])];
    KGSideMenuContainerViewController *sideMenuContainer = [KGSideMenuContainerViewController containerWithCenterViewController:navController
                                                                                                         leftMenuViewController:leftMenuViewController
                                                                                                        rightMenuViewController:rightMenuViewController];
    sideMenuContainer.leftMenuWidth = CGRectGetWidth([UIScreen mainScreen].bounds) - KGLeftMenuOffset;
    sideMenuContainer.menuAnimationDefaultDuration = KGStandartAnimationDuration;
    sideMenuContainer.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    return sideMenuContainer;
}


#pragma mark - Override

- (void)setMenuState:(MFSideMenuState)menuState completion:(void (^)(void))completion {
    __weak typeof (self) wSelf = self;
    [super setMenuState:menuState completion: ^{
        if (completion) {
            completion();
        }

        [wSelf toogleStatusBarState];
    }];
}

- (void)toogleStatusBarState {
 
//    BOOL isStatusBarHidden = self.menuState == MFSideMenuStateClosed;
//    [[UIApplication sharedApplication] setStatusBarHidden:!isStatusBarHidden withAnimation:UIStatusBarAnimationSlide];
    
  }


- (void) setCenterViewControllerOffset:(CGFloat)xOffset {
    UIView *bar = [UIStatusBar sharedStatusBar];
    CGRect frame = bar.frame;
    frame.origin.x = xOffset;
    [bar setFrame:frame];

    [super setCenterViewControllerOffset:xOffset];
}
#pragma mark - Orientations

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

@end
