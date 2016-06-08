//
//  KGLoginViewController.m
//  Mattermost
//
//  Created by Igor Vedeneev on 07.06.16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

#import "KGLoginViewController.h"
#import "UIFont+KGPreparedFont.h"
#import "UIColor+KGPreparedColor.h"
#import "KGConstants.h"

@interface KGLoginViewController ()
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *loginPromtLabel;
@property (weak, nonatomic) IBOutlet UILabel *passwordPromtLabel;
@property (weak, nonatomic) IBOutlet UITextField *loginTextField;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;
@property (weak, nonatomic) IBOutlet UIButton *loginButton;
@property (weak, nonatomic) IBOutlet UIButton *recoveryButton;

@end

@implementation KGLoginViewController


#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setup];
    [self setupTitleLabel];
    [self setupSubtitleLabel];
    [self setupPromtLabels];
    [self setupLoginButton];
    [self setupRecoveryButton];
    [self setupLoginTextfield];
    [self setupPasswordTextField];
    [self configureLabels];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self.loginTextField becomeFirstResponder];
}


#pragma mark - Setup

- (void)setup {
    self.title = @"Sign in";
}

- (void)setupTitleLabel {
    self.titleLabel.font = [UIFont kg_semibold30Font];
    self.titleLabel.textColor = [UIColor kg_blackColor];
}

- (void)setupSubtitleLabel {
    self.subtitleLabel.font = [UIFont kg_light18Font];
    self.subtitleLabel.textColor = [UIColor kg_grayColor];
}

- (void)setupPromtLabels {
    self.loginPromtLabel.font = [UIFont kg_regular14Font];
    self.loginPromtLabel.textColor = [UIColor kg_grayColor];
    
    self.passwordPromtLabel.font = [UIFont kg_regular14Font];
    self.passwordPromtLabel.textColor = [UIColor kg_grayColor];
}

- (void)setupLoginButton {
    self.loginButton.layer.cornerRadius = KGStandartCornerRadius;
    self.loginButton.backgroundColor = [UIColor kg_blueColor];
    [self.loginButton setTitle:NSLocalizedString(@"Sign in", nil) forState:UIControlStateNormal];
    [self.loginButton setTintColor:[UIColor whiteColor]];
    self.loginButton.titleLabel.font = [UIFont kg_regular16Font];
    self.loginButton.contentEdgeInsets = UIEdgeInsetsMake(0, 15, 0, 15);
}

- (void)setupRecoveryButton {
    self.recoveryButton.layer.cornerRadius = KGStandartCornerRadius;
    self.recoveryButton.backgroundColor = [UIColor kg_whiteColor];
    [self.recoveryButton setTitle:NSLocalizedString(@"I forgot password", nil) forState:UIControlStateNormal];
    [self.recoveryButton setTintColor:[UIColor kg_blueColor]];
    self.recoveryButton.titleLabel.font = [UIFont kg_regular16Font];
}

- (void)setupLoginTextfield {
    self.loginTextField.textColor = [UIColor kg_blackColor];
    self.loginTextField.font = [UIFont kg_regular16Font];
    self.loginTextField.placeholder = @"your_name@example.com";
    self.loginTextField.keyboardType = UIKeyboardTypeEmailAddress;
    self.loginTextField.autocorrectionType = UITextAutocorrectionTypeNo;
}

- (void)setupPasswordTextField {
    self.passwordTextField.textColor = [UIColor kg_blackColor];
    self.passwordTextField.font = [UIFont kg_regular16Font];
    self.passwordTextField.placeholder = @"password";
    self.passwordTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.passwordTextField.secureTextEntry = YES;
}


#pragma mark - Configuration

- (void)configureLabels {
    self.titleLabel.text = @"Mattermost";
    self.subtitleLabel.text = @"All your team communication in one place, searchable and accessable anywhere";
    self.loginPromtLabel.text = @"Email";
    self.passwordPromtLabel.text = @"Password";
}


#pragma mark - Actions

- (IBAction)loginAction:(id)sender {
}

- (IBAction)recoveryAction:(id)sender {
}

@end