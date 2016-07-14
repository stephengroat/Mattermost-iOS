//
//  KGChatViewController.m
//  Mattermost
//
//  Created by Maxim Gubin on 10/06/16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

#import "KGChatViewController.h"
#import "KGChatRootCell.h"

#import "KGBusinessLogic.h"
#import "KGBusinessLogic+Posts.h"
#import "KGChannel.h"
#import <IQKeyboardManager/IQKeyboardManager.h>
#import "UIFont+KGPreparedFont.h"
#import "UIColor+KGPreparedColor.h"
#import "KGChatNavigationController.h"
#import <MFSideMenu/MFSideMenu.h>
#import "KGLeftMenuViewController.h"
#import "KGBusinessLogic+Socket.h"
#import "KGBusinessLogic+File.h"
#import "KGBusinessLogic+Channel.h"
#import "KGRightMenuViewController.h"
#import "KGPresentNavigationController.h"
#import <Masonry/Masonry.h>
#import "KGConstants.h"
#import <CTAssetsPickerController/CTAssetsPickerController.h>
#import "KGBusinessLogic+Session.h"
#import "NSStringUtils.h"
#import "KGFollowUpChatCell.h"
#import "KGImageChatCell.h"
#import "KGChatCommonTableViewCell.h"
#import "KGChatAttachmentsTableViewCell.h"
#import "KGAutoCompletionCell.h"
#import "KGChannelNotification.h"
#import "UIImage+KGRotate.h"
#import <UITableView_Cache/UITableView+Cache.h>
#import "KGNotificationValues.h"
#import "UIImage+Resize.h"
#import "UIImageView+UIActivityIndicatorForSDWebImage.h"
#import "KGProfileTableViewController.h"
#import "KGChatRootCell.h"
#import "UIImage+Resize.h"
#import <QuickLook/QuickLook.h>
#import "NSMutableURLRequest+KGHandleCookies.h"
#import "KGPreferences.h"
#import "KGBusinessLogic+Commands.h"
#import "KGImagePickerController.h"
#import "KGAction.h"
#import "KGChatViewController+KGCoreData.h"
#import "KGCommand.h"
#import "KGChatViewController+KGLoading.h"
#import "KGChatViewController+KGTableView.h"

#import <RestKit/RestKit.h>
#import "KGObjectManager.h"
#import <SOCKit/SOCKit.h>

#import "KGImagePicker.h"

static NSString *const kShowSettingsSegueIdentier = @"showSettings";

static NSString *const kUsernameAutocompletionPrefix = @"@";
static NSString *const kCommandAutocompletionPrefix = @"/";

static NSString *const kErrorAlertViewTitle = @"Your message was not sent. Tap Resend to send this message.";

@interface KGChatViewController () <UINavigationControllerDelegate, KGLeftMenuDelegate,
                            KGRightMenuDelegate, UIDocumentInteractionControllerDelegate>

@property (nonatomic, strong) KGChannel *channel;
@property (nonatomic, strong) NSString *previousMessageAuthorId;
// TODO: Code Review: Убрать currentPost как избыточный.
@property (nonatomic, strong) KGPost *currentPost;
@property (nonatomic, strong) NSArray *searchResultArray;
// TODO: Code Review: Этот флаг должен быть реализован на уровне базового контроллера и передаваться параметром в перегруженные viewDidLoad/appear и прочее.
@property (assign) BOOL isFirstLoad;
@property (assign) BOOL loadingInProgress;

@property (assign) BOOL errorOccured;

@property (nonatomic, strong) NSOperationQueue *filesInfoQueue;

@property (nonatomic, strong) UIView *loadingView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingActivityIndicator;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (weak, nonatomic) IBOutlet UILabel *noMessadgesLabel;
@property (nonatomic, strong) UIActivityIndicatorView *topActivityIndicator;
@property (strong, nonatomic) KGImagePicker* picker;


- (IBAction)rightBarButtonAction:(id)sender;

@end

//@interface KGChatViewController (UI)
//@property (nonatomic, strong) UIView *loadingView;
//@property (nonatomic, strong) UIActivityIndicatorView *loadingActivityIndicator;
//@property (nonatomic, strong) UIRefreshControl *refreshControl;
//@property (weak, nonatomic) IBOutlet UILabel *noMessadgesLabel;
//@property (nonatomic, strong) UIActivityIndicatorView *topActivityIndicator;
//@end

@implementation KGChatViewController



#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    [self initialSetup];
    // TODO: Code Review: Переименовать все setup методы, которые используют уже проинициализированные вьюхи на configure
    [self setupFilesInfoOperationQueue];
    [self configureTableView];
    [self configureAutocompletionView];
    [self setupIsNoMessagesLabelShow:YES];
    [self configureKeyboardToolbar];
    [self setupLeftBarButtonItem];
    [self setupRefreshControl];
    [self registerObservers];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Todo, Code Review: Нарушение абстракции
    [self.textView isFirstResponder];
    [self.textView resignFirstResponder];
    [self.textView refreshFirstResponder];
    [self setNeedsStatusBarAppearanceUpdate];
    [IQKeyboardManager sharedManager].enable = NO;

}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
 
    if (_isFirstLoad) {
        [self replaceStatusBar];
        _isFirstLoad = NO;
    }
    
    self.temporaryIgnoredObjects = [NSCountedSet set];
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if ([self isMovingFromParentViewController]) {
        self.navigationController.delegate = nil;
    }
}

- (void)dealloc {
    [self removeObservers];
}


#pragma mark - Setup

// TODO: Code Review: Разнести по отдельным методам. InitialSetup - каша из мелкой конфигурации. Ничего страшного, если она разнесется на три-четыре разных метода
- (void)initialSetup {
    _isFirstLoad = YES;
    self.navigationController.delegate = self;
    self.edgesForExtendedLayout = UIRectEdgeNone;
    KGLeftMenuViewController *leftVC = (KGLeftMenuViewController *)self.menuContainerViewController.leftMenuViewController;
    KGRightMenuViewController *rightVC  = (KGRightMenuViewController *)self.menuContainerViewController.rightMenuViewController;
    leftVC.delegate = self;
    rightVC.delegate = self;
    self.autoCompletionView.backgroundColor = [UIColor kg_autocompletionViewBackgroundColor];
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, -100, 0);
}


- (void)configureTableView {
    [self.tableView registerClass:[KGChatAttachmentsTableViewCell class]
     // TODO: Code Review: Заменить константы на enum со значениями: часто используемая ячейка, редко и прочее.
           forCellReuseIdentifier:[KGChatAttachmentsTableViewCell reuseIdentifier] cacheSize:5];
    [self.tableView registerClass:[KGChatCommonTableViewCell class]
           forCellReuseIdentifier:[KGChatCommonTableViewCell reuseIdentifier] cacheSize:10];
    [self.tableView registerClass:[KGFollowUpChatCell class]
           forCellReuseIdentifier:[KGFollowUpChatCell reuseIdentifier] cacheSize:10];

    [self.tableView registerClass:[KGTableViewSectionHeader class]
           forHeaderFooterViewReuseIdentifier:[KGTableViewSectionHeader reuseIdentifier]];

    [self.tableView registerNib:[KGAutoCompletionCell nib]
         forCellReuseIdentifier:[KGAutoCompletionCell reuseIdentifier] cacheSize:15];
    [self.tableView registerNib:[KGCommandTableViewCell nib]
         forCellReuseIdentifier:[KGCommandTableViewCell reuseIdentifier] cacheSize:15];

    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    // TODO: Code Review: Заменить на стиль из темы
    self.tableView.tableFooterView.backgroundColor = [UIColor whiteColor];
    // TODO: Code Review: Заменить на стиль из темы
    self.tableView.backgroundColor = [UIColor kg_whiteColor];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
}

- (void)configureKeyboardToolbar {
    [self configureTextView];
    [self configureInputBarRightButton];
    [self configureTextInputBar];
}

- (void)configureTextInputBar {
    self.textInputbar.autoHideRightButton = NO;
    self.textInputbar.textView.font = [UIFont kg_regular15Font];
    self.textInputbar.textView.placeholder = NSLocalizedString(@"Type something...", nil);
    self.textInputbar.textView.layer.borderWidth = 0.f;
    self.textInputbar.translucent = NO;
    // TODO: Code Review: Заменить на стиль из темы
    self.textInputbar.barTintColor = [UIColor kg_whiteColor];
}

- (void)configureInputBarRightButton {
    self.rightButton.titleLabel.font = [UIFont kg_semibold16Font];
    [self.rightButton setTitle:NSLocalizedString(@"Send", nil) forState:UIControlStateNormal];
    [self.rightButton addTarget:self action:@selector(sendPost) forControlEvents:UIControlEventTouchUpInside];
    [self.leftButton setImage:[UIImage imageNamed:@"icn_upload"] forState:UIControlStateNormal];
    [self.leftButton addTarget:self action:@selector(assignPhotos) forControlEvents:UIControlEventTouchUpInside];
}

- (void)configureTextView {
    self.shouldClearTextAtRightButtonPress = NO;
    self.textView.delegate = self;
}

- (void)configureAutocompletionView {
    self.autoCompletionView.scrollsToTop = NO;
    self.textView.scrollsToTop = NO;
    [self registerPrefixesForAutoCompletion:@[ kUsernameAutocompletionPrefix, kCommandAutocompletionPrefix ]];
}

- (void)setupLeftBarButtonItem {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"menu_button"]
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(toggleLeftSideMenuAction)];
}

// Todo, Code Review: Разделить на два разных метода, аргумент тут не к месту
- (void)setupIsNoMessagesLabelShow:(BOOL)isShow {
    self.noMessadgesLabel.hidden = isShow;
    if (isShow) {
        [self.view bringSubviewToFront:self.noMessadgesLabel];
    }
}

- (void)setupFilesInfoOperationQueue {
    self.filesInfoQueue = [[NSOperationQueue alloc] init];
    self.filesInfoQueue.maxConcurrentOperationCount = 1;
}

#pragma mark - SLKViewController

+ (UITableViewStyle)tableViewStyleForCoder:(NSCoder *)decoder{
    return UITableViewStyleGrouped;
}

// TODO: Code Review: Слишком много логики в интерфейсном методе.
- (void)didChangeAutoCompletionPrefix:(NSString *)prefix andWord:(NSString *)word {
    [self setupAutoCompletionDataSourceWithAutocompletionPrefix:prefix word:word];
    BOOL show = (self.autocompletionDataSource.count > 0);
    self.shouldShowCommands = [prefix isEqualToString:kCommandAutocompletionPrefix];
    [self showAutoCompletionView:show];
}


#pragma mark - NSFetchedResultsController

- (void)setupFetchedResultsController {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"channel = %@", self.channel];
    
    self.fetchedResultsController = [KGPost MR_fetchAllSortedBy:[KGPostAttributes createdAt]
                                                      ascending:NO
                                                  withPredicate:predicate
                                                        groupBy:[KGPostAttributes creationDay]
                                                       delegate:self inContext:[NSManagedObjectContext MR_defaultContext]];

    self.fetchedResultsController.fetchedObjects.count == 0 ?
            [self setupIsNoMessagesLabelShow:NO] : [self setupIsNoMessagesLabelShow:YES];
}


#pragma mark - Requests

- (void)loadFirstPageOfData {
    self.loadingInProgress = YES;
    [[KGBusinessLogic sharedInstance] loadFirstPageForChannel:self.channel completion:^(BOOL isLastPage, KGError *error) {
        // TODO: Code Review: Слишком много логики в интерфейсном методе. Разнести на два - handleSuccess и handleError
        [self.refreshControl performSelector:@selector(endRefreshing) withObject:nil afterDelay:0.05];
        if (error) {
            [[KGAlertManager sharedManager] showError:error];
        }
        [self setupFetchedResultsController];
        [self.tableView reloadData];
        [self hideLoadingViewAnimated:YES];
        self.loadingInProgress = NO;
        self.hasNextPage = !isLastPage;
        self.errorOccured = error ? YES : NO;
    }];
}

- (void)loadNextPageOfData {
    // TODO: Code Review: Вынести в метод shouldBeginLoadingNextPage
    if (self.loadingInProgress || !self.hasNextPage) {
        return;
    }
    
    self.loadingInProgress = YES;
    self.lastPath = [self indexPathForLastRow];
    [self showTopActivityIndicator];
    [[KGBusinessLogic sharedInstance] loadNextPageForChannel:self.channel completion:^(BOOL isLastPage, KGError *error) {
        // TODO: Code Review: Разнести на два метода
        if (error) {
            [[KGAlertManager sharedManager] showError:error];
        }
        [self hideTopActivityIndicator];
        self.loadingInProgress = NO;
        self.hasNextPage = !isLastPage;
        self.errorOccured = error ? YES : NO;
    }];
}

- (void)applyCommand {
    [[KGBusinessLogic sharedInstance] executeCommandWithMessage:self.textInputbar.textView.text
                                                      inChannel:self.channel withCompletion:^(KGAction *action, KGError *error) {
                                                          [action execute];
                                                      }];
    [self clearTextView];
}


// TODO: Code Review: Разнести отправку поста и отправку команды в два метода
- (void)sendPost {
    // TODO: Code Review: Вынести условие в отдельный метод
    if ([self.textInputbar.textView.text hasPrefix:kCommandAutocompletionPrefix]) {
        [self applyCommand];
        return;
    }

    [self configureCurrentPost];
    [self clearTextView];
    
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];

    __block KGPost* postToSend = self.currentPost;
    [self.temporaryIgnoredObjects addObject:postToSend.backendPendingId];
    [self.temporaryIgnoredObjects addObject:postToSend.backendPendingId];

    [[KGBusinessLogic sharedInstance] sendPost:postToSend completion:^(KGError *error) {
        // TODO: Code Review: Слишком много логики в интерфейсно методе
        KGTableViewCell* cell = [self.tableView cellForRowAtIndexPath: [self.fetchedResultsController indexPathForObject:postToSend]];
        [cell finishAnimation];
        if (error) {
            postToSend.error = @YES;
            [[KGAlertManager sharedManager] showError:error];
            [cell showError];
        }

        [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
        [self resetCurrentPost];
    }];
}


- (void)loadAdditionalPostFilesInfo:(KGPost *)post indexPath:(NSIndexPath *)indexPath {
    NSArray *files = post.nonImageFiles;
    
    for (KGFile *file in files) {
        if (file.sizeValue == 0) {
            [self loadAdditionalInfoForFile:file];
        }
    }
}

- (void)loadAdditionalInfoForFile:(KGFile *)file {
    NSString* path = SOCStringFromStringWithObject([KGFile updatePathPattern], file);
    NSURLRequest *request = [[KGBusinessLogic sharedInstance].defaultObjectManager requestWithObject:nil
                                                                                              method:RKRequestMethodGET
                                                                                                path:path
                                                                                          parameters:nil];
    RKManagedObjectRequestOperation* operation =
            [[KGBusinessLogic sharedInstance].defaultObjectManager managedObjectRequestOperationWithRequest:request
                                                                                       managedObjectContext:[NSManagedObjectContext MR_defaultContext]
                                                                                                    success:nil
                                                                                                    failure:nil];
    [self.filesInfoQueue addOperation:operation];
}


#pragma mark - Private

- (void)setupAutoCompletionDataSourceWithAutocompletionPrefix:(NSString *)prefix word:(NSString *)word {
    NSString *filterTerm;
    
    if ([prefix isEqualToString:kUsernameAutocompletionPrefix]) {
        filterTerm = [KGUserAttributes username];
        self.autocompletionDataSource = [KGUser MR_findAll];
    } else  if ([prefix isEqualToString:kCommandAutocompletionPrefix]) {
        filterTerm = [KGCommandAttributes trigger];
        self.autocompletionDataSource = [KGCommand MR_findAll];
    }
    
    if (word.length) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.%@ BEGINSWITH[c] %@", filterTerm, word];
        self.autocompletionDataSource = [self.autocompletionDataSource filteredArrayUsingPredicate:predicate];
    }
    
}


- (KGAutoCompletionCell *)autoCompletionCellAtIndexPath:(NSIndexPath *)indexPath {
    KGAutoCompletionCell *cell;
    NSString *reuseIdentifier = self.shouldShowCommands ?
                                        [KGCommandTableViewCell reuseIdentifier] : [KGAutoCompletionCell reuseIdentifier];
    
    cell = [self.tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    [cell configureWithObject:self.autocompletionDataSource[indexPath.row]];
    
    return cell;
}

- (void)configureCell:(KGTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    // Todo, Code Review: Лишнее, если конфигурация autocompletion будет из категории
    if ([cell isKindOfClass:[KGTableViewCell class]]) {
        [cell configureWithObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
        cell.transform = self.tableView.transform;
    }
}

- (void)assignPhotos {
    
    __block BOOL operationCancelled = NO;
    __block BOOL photosLoad = YES;
    self.picker = [KGImagePicker new];
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    
    __weak typeof(self) wSelf = self;
    
    [[UIStatusBar sharedStatusBar] moveTemporaryToRootView];
    [self.picker launchPickerFromController:self didHidePickerHandler:^{
        [[UIStatusBar sharedStatusBar] moveToPreviousView];
    } willBeginPickingHandler:^{
        [[KGAlertManager sharedManager] showProgressHud];
    } didPickImageHandler:^(UIImage *image) {
        dispatch_group_enter(group);
        [[KGBusinessLogic sharedInstance] uploadImage:[image kg_normalizedImage]
                                            atChannel:wSelf.channel
                                       withCompletion:^(KGFile* file, KGError* error) {
                                           if (self.currentPost.files.count < 5) {
                                               [self.currentPost addFilesObject:file];
                                           } else {
                                               photosLoad = NO;
                                           }
                                           dispatch_group_leave(group);
                                       }];
    } didFinishPickingHandler:^(BOOL isCancelled){
        operationCancelled = isCancelled;
        dispatch_group_leave(group);
    }];
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (!operationCancelled){
            [[KGAlertManager sharedManager] hideHud];
            if (!photosLoad) {
                [[KGAlertManager sharedManager] showWarningWithMessage:@"Uploads limited to 5 files maximum. Please use additional posts for more files."];
            }
            [self sendPost];
        }
    });
    
}



- (void)updateNavigationBarAppearance:(BOOL)loadingInProgress errorOccured:(BOOL)errorOccured {
    NSString *subtitleString;
    BOOL shouldHighlight = NO;
    if (self.channel.type == KGChannelTypePrivate) {
        KGUser *user = [KGUser managedObjectById:self.channel.interlocuterId];
        if (user) {
            subtitleString = user.stringFromNetworkStatus;
            shouldHighlight = user.networkStatus == KGUserOnlineStatus;
        }
    } else {
        subtitleString = [NSString stringWithFormat:@"%d members", (int)self.channel.members.count];
    }

    [(KGChatNavigationController *)self.navigationController setupTitleViewWithUserName:self.channel.displayName
                                                                               subtitle:subtitleString
                                                                        shouldHighlight:shouldHighlight
                                                                      loadingInProgress:loadingInProgress
                                                                           errorOccured:errorOccured];
}

- (void)updateNavigationBarAppearanceFromNotification:(NSNotification *)notification {
    [self updateNavigationBarAppearance:NO errorOccured:self.errorOccured];
}
- (void)photoBrowser:(IDMPhotoBrowser *)photoBrowser willDismissAtPageIndex:(NSUInteger)index {
    [[UIStatusBar sharedStatusBar] moveToPreviousView];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDefault;
}

// TODO: Code Review: Переименовать на более говорящее название
- (void)replaceStatusBar {
    [[UIStatusBar sharedStatusBar] moveToView:self.navigationController.view];
}

- (void)resetCurrentPost {
    self.currentPost = nil;
}

- (void)configureCurrentPost {
    self.currentPost.message = self.textInputbar.textView.text;
    self.currentPost.author = [[KGBusinessLogic sharedInstance] currentUser];
    self.currentPost.channel = self.channel;
    self.currentPost.createdAt = [NSDate date];
    [self.currentPost configureBackendPendingId];
}

- (void)clearTextView {
    self.textView.text = nil;
}


#pragma mark - Notifications

- (void)handleChannelNotification:(NSNotification *)notification {
    if ([notification.object isKindOfClass:[KGChannelNotification class]]) {
        KGChannelNotification *kg_notification = notification.object;

        switch (kg_notification.action) {
            case KGActionTyping: {
                // TODO: Code Review: Вынести в отдельный метод
                NSString *currentUserID = [[KGPreferences sharedInstance] currentUserId];
                KGUser *user = [KGUser managedObjectById:kg_notification.userIdentifier];
                if (![user.identifier isEqualToString:currentUserID]) {
                    [self.typingIndicatorView insertUsername:user.nickname];
                }
                
                break;
            }

            case KGActionPosted: {
                // TODO: Code Review: Вынести в отдельный метод
                KGUser *user = [KGUser managedObjectById:kg_notification.userIdentifier];
                [self.typingIndicatorView removeUsername: user.nickname];

                break;
            }

            default:
                break;
        }
    }
}


- (void)registerObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateNavigationBarAppearanceFromNotification:)
                                                 name:KGNotificationUsersStatusUpdate
                                               object:nil];
}

- (void)removeObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {

    if ([navigationController isKindOfClass:[KGChatNavigationController class]]) {
        if (navigationController.viewControllers.count == 1) {
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"navbar_menu_icon"]
                                                                                     style:UIBarButtonItemStylePlain
                                                                                    target:self
                                                                                    action:@selector(toggleLeftSideMenuAction)];

        }
    }
}


#pragma mark - KGLeftMenuDelegate

// Todo, Code Review: Каша из абстракции
- (void)didSelectChannelWithIdentifier:(NSString *)idetnfifier {
    
    [self dismissKeyboard:YES];
    if (self.channel) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:self.channel.notificationsName
                                                      object:nil];
    }

    self.channel = [KGChannel managedObjectById:idetnfifier];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleChannelNotification:)
                                                 name:self.channel.notificationsName
                                               object:nil];

    [self updateNavigationBarAppearance:YES errorOccured:NO];
    // Todo, Code Review: Мертвый код
    self.channel.lastViewDate = [NSDate date];
    [self.tableView slk_scrollToTopAnimated:NO];

    [[KGBusinessLogic sharedInstance] loadExtraInfoForChannel:self.channel withCompletion:^(KGError *error) {
        if (error) {
            [[KGAlertManager sharedManager] showError:error];
            [self setupFetchedResultsController];
            [self.tableView reloadData];
        } else {
            NSTimeInterval interval = self.channel.updatedAt.timeIntervalSinceNow;
            //FIXME: refactor
            if ([self.channel.firstLoaded boolValue] || self.channel.hasNewMessages || fabs(interval) > 1000) {
                self.channel.lastViewDate = [NSDate date];
                self.channel.firstLoaded = @NO;
                [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
                [self showLoadingView];
                [self loadFirstPageOfData];
            } else {
                self.hasNextPage = YES;
                [self setupFetchedResultsController];
                [self.tableView reloadData];
            }
        }
        self.errorOccured = error ? YES : NO;
        [self updateNavigationBarAppearance:NO errorOccured:self.errorOccured];
    }];

    [[KGBusinessLogic sharedInstance] updateLastViewDateForChannel:self.channel withCompletion:nil];
    if ([self.navigationController.viewControllers.lastObject isKindOfClass:[KGProfileTableViewController class]]) {
        [self.navigationController popViewControllerAnimated:NO];
    }
}


#pragma mark - KGRightMenuDelegate

- (void)navigationToProfile {
    if ([self.navigationController.viewControllers.lastObject isKindOfClass:[KGProfileTableViewController class]]) {
        [self.navigationController popViewControllerAnimated:NO];
    }
    self.title = @"";
    [self toggleRightSideMenuAction];
    self.selectedUsername = [KGBusinessLogic sharedInstance].currentUser.username;
    [self performSegueWithIdentifier:kPresentProfileSegueIdentier sender:nil];
}

- (void)navigateToSettings {

    [self performSegueWithIdentifier:kShowSettingsSegueIdentier sender:nil];
}


#pragma mark - Actions

- (void)toggleLeftSideMenuAction {
    [self.menuContainerViewController toggleLeftSideMenuCompletion:nil];
}

- (void)toggleRightSideMenuAction {
    [self.menuContainerViewController toggleRightSideMenuCompletion:nil];
}

- (IBAction)rightBarButtonAction:(id)sender {
    [self toggleRightSideMenuAction];
}

- (void)showProfile: (KGUser *)user {
    if (([self.channel.backendType isEqualToString:@"O"]) && (![[KGBusinessLogic sharedInstance].currentUser isEqual: user])) {
        //[self showLoadingView];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"displayName = %@", user.nickname];
        KGChannel *channel = [[KGChannel MR_findAllWithPredicate:predicate] firstObject];
        if (channel) {
            [self didSelectChannelWithIdentifier:channel.identifier];
            [[KGPreferences sharedInstance] setLastChannelId:channel.identifier];
        } else {
            [[KGAlertManager sharedManager] showWarningWithMessage:@"This section is under development"];
        }
    } else {
        self.title = @"";
        self.selectedUsername = user.username;
        [self performSegueWithIdentifier:kPresentProfileSegueIdentier sender:self.selectedUsername];
    }
 }


#pragma mark - Loading View

- (UIActivityIndicatorView *)loadingActivityIndicator {
    if (!_loadingActivityIndicator) {
        _loadingActivityIndicator = [[UIActivityIndicatorView alloc]
                initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _loadingActivityIndicator.hidesWhenStopped = YES;
    }

    return _loadingActivityIndicator;
}

- (void)showLoadingView {
//    if (!_loadingView) {
        self.loadingView = [[UIView alloc] init];
        self.loadingView.backgroundColor = [UIColor whiteColor];
//    }
        NSLog(@"SHOW_LOADING_VIEW");
    [self.view addSubview:self.loadingView];
    [self.loadingView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    [self.loadingView addSubview:self.loadingActivityIndicator];
    [self.loadingActivityIndicator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.loadingView);
    }];
    [self.loadingActivityIndicator startAnimating];
}

- (void)hideLoadingViewAnimated:(BOOL)animated {
    NSLog(@"HIDE_LOADING_VIEW");
    NSTimeInterval duration = animated ? KGStandartAnimationDuration : 0;
    
    [UIView animateWithDuration:duration animations:^{
        self.loadingView.alpha = 0;
    } completion:^(BOOL finished) {
        [self.loadingActivityIndicator stopAnimating];
        [self.loadingView removeFromSuperview];
    }];
}

- (void)errorActionWithPost: (KGPost *)post {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:kErrorAlertViewTitle message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    
    UIAlertAction *resendAction =
    [UIAlertAction actionWithTitle:NSLocalizedString(@"Resend", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        
        __block KGPost* postToSend = post;
        
        postToSend.error = nil;
        
        
        
        [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfWithCompletion:^(BOOL contextDidSave, NSError * _Nullable error) {
            [[NSManagedObjectContext MR_defaultContext] refreshObject:postToSend mergeChanges:NO];
        }];
        
        KGTableViewCell* cell = [self.tableView cellForRowAtIndexPath: [self.fetchedResultsController indexPathForObject:postToSend]];
        
        [cell hideError];
        [cell startAnimation];
        [self.temporaryIgnoredObjects addObject:postToSend.backendPendingId];
        [self.temporaryIgnoredObjects addObject:postToSend.backendPendingId];
        
        [[KGBusinessLogic sharedInstance] sendPost:postToSend completion:^(KGError *error) {
            
            KGTableViewCell* cell = [self.tableView cellForRowAtIndexPath: [self.fetchedResultsController indexPathForObject:postToSend]];
            [cell finishAnimation];
            if (error) {
                postToSend.error = @YES;
                [[KGAlertManager sharedManager] showError:error];
                [cell showError];
                [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
            } 
        
            // Todo, Code Review: Не соблюдение абстракции, вынести сброс текущего поста в отдельный метод
            
    }];

    }];
    
    UIAlertAction *deleteAction =
    [UIAlertAction actionWithTitle:NSLocalizedString(@"Delete", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        
        [post MR_deleteEntity];
        [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
        
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:resendAction];
    [alertController addAction:deleteAction];
    [alertController addAction:cancelAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - RefreshControl

- (void)setupRefreshControl {
    UITableViewController *tableViewController = [[UITableViewController alloc] init];
    tableViewController.tableView = self.tableView;
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self
                            action:@selector(refreshControlValueChanged:)
                  forControlEvents:UIControlEventValueChanged];
    tableViewController.refreshControl = self.refreshControl;
}

- (void)refreshControlValueChanged:(UIRefreshControl *)refreshControl {
    [self loadFirstPageOfData];
}


#pragma mark - ActivityIndicator

- (void)showTopActivityIndicator {
    CGFloat bottomActivityIndicatorHeight = CGRectGetHeight(self.topActivityIndicator.bounds);
    UIView *tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.tableView.bounds), 2 * bottomActivityIndicatorHeight)];
    self.topActivityIndicator.center = CGPointMake(tableFooterView.center.x, tableFooterView.center.y - bottomActivityIndicatorHeight / 5);
    [tableFooterView addSubview:self.topActivityIndicator];
    self.tableView.tableFooterView = tableFooterView;
    [self.topActivityIndicator startAnimating];
}

- (void)hideTopActivityIndicator {
    [self.topActivityIndicator stopAnimating];
    if (!self.hasNextPage) {
        self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    }
}

- (UIActivityIndicatorView *)topActivityIndicator {
    if (!_topActivityIndicator) {
        _topActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _topActivityIndicator.transform = self.tableView.transform;
    }
    
    return _topActivityIndicator;
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:kPresentProfileSegueIdentier]) {
        KGProfileTableViewController *vc = segue.destinationViewController;
        KGUser *user = [KGUser MR_findFirstByAttribute:NSStringFromSelector(@selector(username)) withValue:self.selectedUsername];
        vc.userId = user.identifier;
        [vc.menuContainerViewController setMenuState:MFSideMenuStateClosed completion:nil];
    }
}


#pragma mark - Private Setters

- (void)setShouldShowCommands:(BOOL)shouldShowCommands {
    if (shouldShowCommands != _shouldShowCommands) {
        [self.autoCompletionView reloadData];
    }
    self.autoCompletionView.separatorStyle = shouldShowCommands ?
            UITableViewCellSeparatorStyleNone : UITableViewCellSeparatorStyleSingleLine;

    _shouldShowCommands = shouldShowCommands;
}


#pragma mark - Private Getters

- (KGPost *)currentPost {
    if (!_currentPost) {
        _currentPost = [KGPost MR_createEntityInContext:[NSManagedObjectContext MR_defaultContext]];
    }
    
    return _currentPost;
}


#pragma mark - Files
// Todo, Code Review: Вынести в бизнес логику
- (void)openFile:(KGFile *)file {
    NSURL *URL = [NSURL fileURLWithPath:file.localLink];

    if (URL) {
        UIDocumentInteractionController *documentInteractionController =
                [UIDocumentInteractionController interactionControllerWithURL:URL];
        [documentInteractionController setDelegate:self];
        BOOL result = [documentInteractionController presentPreviewAnimated:YES];
        if (!result) {
            [[KGAlertManager sharedManager] showError:cannotOpenFileError()];
        }
    } else {
        [[KGAlertManager sharedManager] showError:fileDoesntExsistError()];
    }
}

- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
    return self;
}

- (nullable UIView *)documentInteractionControllerViewForPreview:(UIDocumentInteractionController *)controller {
    return self.view;
}


#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    [super textView:textView shouldChangeTextInRange:range replacementText:text];
    
    return YES;
}

@end
