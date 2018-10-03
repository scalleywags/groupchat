//
//  ViewController.m
//  sample-messages
//
//  Created by Quickblox Team on 6/11/15.
//  Copyright (c) 2015 QuickBlox. All rights reserved.
//

#import "ViewController.h"
#import <Quickblox/Quickblox.h>
#import <SVProgressHUD.h>
#import "SAMTextView.h"
#import <UserNotifications/UserNotifications.h>
#define CHECK_VERSION(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

@interface ViewController () <UITableViewDataSource, UITableViewDelegate, UNUserNotificationCenterDelegate>

@property (weak, nonatomic) IBOutlet SAMTextView *pushMessageTextView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *sendPushButton;

@property (nonatomic, strong) NSMutableArray *pushMessages;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSDictionary* attributes = @{NSFontAttributeName : [UIFont systemFontOfSize:17.0f],
                                 NSForegroundColorAttributeName : [UIColor colorWithWhite:0.0f alpha:0.3f]};
    self.pushMessageTextView.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Enter push message here" attributes:attributes];
    self.pushMessageTextView.textContainerInset = (UIEdgeInsets){10.0f, 10.0f, 0.0f, 0.0f};
    
    CALayer *bottomBorder = [CALayer layer];
    bottomBorder.frame = CGRectMake(0.0f, self.pushMessageTextView.frame.size.height - 1.0f, self.pushMessageTextView.frame.size.width, 1.0f);
    bottomBorder.backgroundColor = [UIColor colorWithRed:200.0f/255.0f
                                                   green:199.0f/255.0f
                                                    blue:204.0f/255.0f
                                                   alpha:1.0f].CGColor;
    [self.pushMessageTextView.layer addSublayer:bottomBorder];
    
    self.pushMessages = [NSMutableArray array];
    self.tableView.hidden = YES;
   
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pushDidReceive:)
                                                 name:@"kPushDidReceive"
                                               object:nil];

    self.sendPushButton.enabled = NO;
    
    __weak typeof(self) weakSelf = self;
    
    [self checkCurrentUserWithCompletion:^(NSError *authError) {
        
        if (!authError) {
            weakSelf.sendPushButton.enabled = YES;
            [weakSelf registerForRemoteNotifications];
        } else {
            [ViewController showAlertViewWithErrorMessage:[authError localizedDescription]];
        }
        
    }];
}

- (void)pushDidReceive:(NSNotification *)notification
{
    NSString *message = [notification userInfo][@"message"];
    
    [self.pushMessages addObject:message];
    self.tableView.hidden = NO;
    
    [self.tableView reloadData];
}

#pragma mark - Push Notifications

- (void)registerForRemoteNotifications{
    
    if(CHECK_VERSION(@"10.0")) { // iOS 10+
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = self;
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError * _Nullable error){
            if( !error ){
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] registerForRemoteNotifications];
                });
                [self getNotificationSettings];
            }
        }];
    }
    else { // < iOS 10
        UIUserNotificationSettings *settings =
        [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound |
                                                      UIUserNotificationTypeAlert |
                                                      UIUserNotificationTypeBadge)
                                          categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
        [self getNotificationSettings];
    }
}

-(void) getNotificationSettings{
    
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings){
        
        //1. Query the authorization status of the UNNotificationSettings object
        switch (settings.authorizationStatus) {
            case UNAuthorizationStatusAuthorized:
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] registerForRemoteNotifications];
                });
                NSLog(@"Status Authorized");
                break;
            case UNAuthorizationStatusDenied:
                NSLog(@"Status Denied");
                break;
            case UNAuthorizationStatusNotDetermined:
                NSLog(@"Undetermined");
                break;
            default:
                break;
        }
        
        
        //2. To learn the status of specific settings, query them directly
        NSLog(@"Checking Badge settings");
        if (settings.badgeSetting == UNAuthorizationStatusAuthorized)
            NSLog(@"Yeah. We can badge this puppy!");
        else
            NSLog(@"Not authorized");
        
    }];
}

//- (void)registerForRemoteNotifications {
//
//    UIUserNotificationSettings *settings =
//    [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound |
//                                                  UIUserNotificationTypeAlert |
//                                                  UIUserNotificationTypeBadge)
//                                      categories:nil];
//    [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
//    [[UIApplication sharedApplication] registerForRemoteNotifications];
//}

- (void)sendPushWithMessage:(NSString *)message
{
    NSString *currentUserId = [NSString stringWithFormat:@"%lu", (unsigned long)[QBSession currentSession].currentUser.ID];
    
    [SVProgressHUD showWithStatus:@"Sending a push"];
    
    [QBRequest sendPushWithText:message toUsers:currentUserId successBlock:^(QBResponse *response, NSArray *events) {
        
        [SVProgressHUD  dismiss];
        
        [ViewController showNotificationAlertViewWithTitle:@"Alert" message:@"Your message successfully sent"];
        
    } errorBlock:^(QBError *error) {
        
        [SVProgressHUD  dismiss];
        
        [ViewController showAlertViewWithErrorMessage:[error description]];
    }];
    
}

- (void)checkCurrentUserWithCompletion:(void(^)(NSError *authError))completion
{
    if ([[QBSession currentSession] currentUser] != nil) {
        
        if (completion) completion(nil);
        
    } else {
        
        [SVProgressHUD showWithStatus:@"Initialising"];
        
        [QBRequest logInWithUserLogin:@"test_user_id1" password:@"test_user_id1" successBlock:^(QBResponse *response, QBUUser *user) {
            
            [SVProgressHUD dismiss];
            
            if (completion) completion(nil);
            
        } errorBlock:^(QBResponse *response) {
            
            [SVProgressHUD dismiss];
            
            if (completion) completion(response.error.error);
        }];
    }
}

- (IBAction)sendPush:(id)sender
{
    [self.view endEditing:YES];
    NSString *message = self.pushMessageTextView.text;
    
    // empty text
    if([message length] == 0) {
        
        [ViewController showNotificationAlertViewWithTitle:@"Validation" message:@"Please enter some text"];
        
    } else {
        
        [self sendPushWithMessage:message];
        
        [self.pushMessageTextView resignFirstResponder];
        self.pushMessageTextView.text = nil;
    }
}

#pragma mark -
#pragma mark TableViewDataSource & TableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.pushMessages count];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PushMessageCellIdentifier"];
    
    cell.textLabel.text = self.pushMessages[indexPath.row];
    
    return cell;
}

#pragma mark -
#pragma mark Helpers

+ (void)showAlertViewWithErrorMessage:(NSString *)errorMessage
{
    NSLog(@"Errors = %@", errorMessage);
    
    [self showNotificationAlertViewWithTitle:@"Error" message:errorMessage];
}

+ (void)showNotificationAlertViewWithTitle:(NSString *)title message:(NSString *)message
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

@end
