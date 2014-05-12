//
//  SldUserInfoController.m
//  Sld
//
//  Created by Wei Li on 14-5-13.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldUserInfoController.h"
#import "MMPickerView.h"

@interface SldUserInfoController ()
@property (weak, nonatomic) IBOutlet UITextField *nameInput;
@property (weak, nonatomic) IBOutlet UITextField *genderInput;
@property (weak, nonatomic) IBOutlet UITextField *teamInput;
@property (weak, nonatomic) IBOutlet UIButton *avatarImageView;

@end

@implementation SldUserInfoController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onGenderButton:(id)sender {
    [self.view endEditing:YES];
    NSArray *strings = @[@"男", @"女", @"其他"];
    
    NSDictionary *options = nil;
    if ([strings indexOfObject:_genderInput.text] != NSNotFound ) {
        options = @{MMselectedObject:_genderInput.text};
    }
    
    [MMPickerView showPickerViewInView:self.navigationController.view
                           withStrings:strings
                           withOptions:options
                            completion:^(NSString *selectedString) {
                                _genderInput.text = selectedString;
                            }];
}

- (IBAction)onTeamButton:(id)sender {
    [self.view endEditing:YES];
    NSArray *strings = @[@"安徽",@"澳门",@"北京",@"重庆",@"福建",@"甘肃",@"广东",@"广西族",@"贵州",@"海南",@"河北",@"黑龙江",@"河南",@"湖北",@"湖南",@"江苏",@"江西",@"吉林",@"辽宁",@"内蒙古",@"宁夏",@"青海",@"陕西",@"山东",@"上海",@"山西",@"四川",@"台湾",@"天津",@"香港",@"新疆",@"西藏",@"云南",@"浙江"];
    
    NSDictionary *options = nil;
    if ([strings indexOfObject:_teamInput.text] != NSNotFound ) {
        options = @{MMselectedObject:_teamInput.text};
    }
    
    [MMPickerView showPickerViewInView:self.navigationController.view
                           withStrings:strings
                           withOptions:options
                            completion:^(NSString *selectedString) {
                                _teamInput.text = selectedString;
                            }];
}

- (IBAction)onSave:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onCancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}
#pragma mark - Table view data source

//- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
//{
//
//    return 1;
//}
//
//- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
//{
//
//    return 2;
//}

/*
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:<#@"reuseIdentifier"#> forIndexPath:indexPath];
    
    // Configure the cell...
    
    return cell;
}
*/

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
