//
//  SldStarModeListController.m
//  Sld
//
//  Created by 李炜 on 14-7-7.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldChallengeListController.h"
#import "SldGameData.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldUtil.h"
#import "SldHttpSession.h"

static const int NUM_PER_SECTION = 15;
static const int NUM_PER_ROW = 3;

//=============================
@interface SldChallengeCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet SldAsyncImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *starLabel;
@property (weak, nonatomic) IBOutlet UIImageView *locker;
@property (weak, nonatomic) IBOutlet UIImageView *dimmer;
@end

@implementation SldChallengeCell

@end

//=============================
@interface SldChallengeHeader : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UILabel *cityLabel;
@end

@implementation SldChallengeHeader

@end

//=============================
@interface SldChallengeListController ()
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) UITextField *titleField;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *goButton;
@property (nonatomic) UIImage *loadingImage;
@property (nonatomic) UIImage *missingImage;
@property (nonatomic) UIImage *dollarImage;
@property (nonatomic) SldGameData *gd;
@property (nonatomic) NSMutableArray *downloadTasks;
@property (nonatomic) int rowNum;
@property (nonatomic) NSArray *cityNames;
@end

static int EVENT_NUM_PER_BATCH = 20;
static NSString *STR_GOTO = @"跳转";
static NSString *STR_BOTTOM = @"当前";

@implementation SldChallengeListController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _downloadTasks = [NSMutableArray arrayWithCapacity:20];
    
//    //refresh control
//    self.refreshControl = [[UIRefreshControl alloc] init];
//    self.collectionView.alwaysBounceVertical = YES;
//    [self.collectionView addSubview:self.refreshControl];
//    [self.refreshControl addTarget:self action:@selector(refershControlAction) forControlEvents:UIControlEventValueChanged];
    
    self.collectionView.decelerationRate = UIScrollViewDecelerationRateFast;
    
    //title
    _titleField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 100, 30)];
    self.navigationItem.titleView = _titleField;
    _titleField.text = @"0";
    _titleField.borderStyle = UITextBorderStyleRoundedRect;
    _titleField.textAlignment = NSTextAlignmentCenter;
    _titleField.backgroundColor = [UIColor clearColor];
    _titleField.keyboardType = UIKeyboardTypeNumberPad;
    
    //tap gesture
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTapGestureCaptured:)];
    singleTap.cancelsTouchesInView = NO;
    [self.collectionView addGestureRecognizer:singleTap];
    
    //title tap notification
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onTitleTap:)
                                                 name:UITextFieldTextDidBeginEditingNotification object:nil];
    
    
    _goButton.title = STR_BOTTOM;
    _gd = [SldGameData getInstance];
    _loadingImage = [UIImage imageNamed:@"ui/loading.png"];
    _missingImage = [UIImage imageNamed:@"ui/gift.png"];
    _dollarImage = [UIImage imageNamed:@"ui/dollar.png"];
    
    //
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"challenge/count" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        _rowNum = [(NSNumber*)[dict objectForKey:@"Count"] intValue];
        
        if (_gd.challengeInfos == nil) {
            _gd.challengeInfos = [NSMutableArray arrayWithCapacity:_rowNum];
            for (int i = 0; i < _rowNum; i++) {
                ChallengeInfo *cha = [[ChallengeInfo alloc] init];
                [_gd.challengeInfos addObject:cha];
            }
        } else if (_gd.challengeInfos.count < _rowNum) {
            for (int i = 0; i < _rowNum-_gd.challengeInfos.count; i++) {
                ChallengeInfo *cha = [[ChallengeInfo alloc] init];
                [_gd.challengeInfos addObject:cha];
            }
        } else if (_gd.challengeInfos.count > _rowNum) {
            for (int i = 0; i < _gd.challengeInfos.count-_rowNum; i++) {
                [_gd.challengeInfos removeLastObject];
            }
        }
        [self.collectionView reloadData];
    }];
    
    _cityNames = @[@"伦敦",@"纽约",@"香港",@"巴黎",@"新加坡",@"上海",@"东京",@"北京",@"悉尼",@"迪拜",@"芝加哥",@"孟买",@"米兰",@"莫斯科",@"圣保罗",@"法兰克福",@"多伦多",@"洛杉矶",@"马德里",@"墨西哥城",@"阿姆斯特丹",@"吉隆坡",@"布鲁塞尔	",@"首尔",@"约翰内斯堡",@"布宜诺斯艾利斯",@"维也纳",@"旧金山",@"伊斯坦布尔",@"雅加达",@"苏黎世",@"华沙",@"华盛顿特区",@"墨尔本",@"新德里",@"迈阿密",@"巴塞罗那",@"曼谷",@"波士顿",@"都柏林",@"台北",@"慕尼黑",@"斯德哥尔摩",@"布拉格",@"亚特兰大",@"班加罗尔",@"里斯本",@"哥本哈根",@"圣地亚哥",@"广州",@"罗马",@"开罗",@"达拉斯",@"汉堡",@"杜塞尔多夫",@"雅典",@"马尼拉",@"蒙特利尔",@"费城",@"特拉维夫",@"利马",@"布达佩斯",@"柏林",@"开普敦",@"卢森堡城",@"休斯顿",@"基辅",@"布加勒斯特",@"贝鲁特",@"胡志明市",@"波哥大",@"奥克兰",@"蒙得维的亚",@"加拉加斯",@"利雅得",@"温哥华",@"金奈",@"曼彻斯特",@"奥斯陆",@"布里斯班",@"赫尔辛基",@"卡拉奇",@"多哈",@"达尔贝达",@"斯图加特",@"里约热内卢",@"日内瓦",@"危地马拉城",@"里昂",@"巴拿马城",@"圣何塞",@"布拉迪斯拉发",@"明尼阿波利斯",@"突尼斯城",@"内罗毕",@"克利夫兰",@"拉各斯",@"阿布扎比",@"西雅图",@"河内",@"索非亚",@"里加",@"路易港",@"底特律",@"卡尔加里",@"丹佛",@"珀斯",@"加尔各答",@"圣迭戈",@"安曼",@"安特卫普",@"麦纳麦",@"伯明翰",@"尼科西亚",@"基多",@"鹿特丹",@"贝尔格莱德",@"蒙特雷",@"阿拉木图",@"深圳",@"科威特城",@"海德拉巴",@"爱丁堡",@"萨格勒布",@"拉合尔",@"圣彼得堡",@"吉达",@"德班",@"圣多明各",@"圣路易斯",@"伊斯兰堡",@"瓜亚基尔",@"巴尔的摩",@"圣萨尔瓦多",@"科隆",@"菲尼克斯",@"阿德莱德",@"布里斯托尔",@"夏洛特",@"乔治敦",@"大阪",@"坦帕",@"格拉斯哥",@"圣胡安",@"马赛",@"瓜达拉哈拉",@"利兹",@"巴库",@"维尔纽斯",@"塔林",@"罗利",@"安卡拉",@"贝尔法斯特",@"圣何塞",@"科伦坡",@"巴伦西亚",@"辛辛那提",@"密尔沃基",@"马斯喀特",@"卢布尔雅那",@"南特",@"天津",@"阿克拉",@"阿尔及尔",@"哥德堡",@"波尔图",@"哥伦布",@"乌得勒支",@"奥兰多",@"艾哈迈达巴德",@"亚松森",@"堪萨斯城",@"塞维利亚",@"都灵",@"达累斯萨拉姆",@"波特兰",@"克拉科夫",@"马那瓜",@"浦那",@"莱比锡",@"马尔默",@"拉巴斯",@"南安普敦",@"印第安纳波利斯",@"阿雷格里港",@"斯特拉斯堡",@"哈博罗内",@"成都",@"里士满",@"匹兹堡",@"蒂华纳",@"奥斯汀",@"青岛",@"拿骚",@"特古西加尔巴",@"里尔",@"库里奇巴",@"海牙",@"哈特福德",@"弗罗茨瓦夫",@"埃德蒙顿",@"洛桑",@"达卡",@"纽伦堡",@"卢萨卡",@"坎帕拉",@"毕尔巴鄂",@"杜阿拉",@"阿比让",@"盐湖城",@"杭州",@"波兹南",@"惠灵顿",@"渥太华",@"达喀尔",@"克雷塔罗",@"德累斯顿",@"泰因河畔纽卡斯尔",@"斯科普里",@"南京",@"地拉那",@"重庆",@"贝洛奥里藏特"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (_gd.needReloadEventList) {
        [self.collectionView reloadData];
    }
    
//    [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:10 inSection:0] atScrollPosition:UICollectionViewScrollPositionTop animated:NO];
}

- (void)onTitleTap:(NSNotification*)aNotification {
    [_titleField setSelectedTextRange:[_titleField textRangeFromPosition:_titleField.beginningOfDocument toPosition:_titleField.endOfDocument]];
    
    _goButton.title = STR_GOTO;
}

- (IBAction)onGotoBottom:(id)sender {
    if ([_goButton.title compare:STR_GOTO] == 0) {
        NSInteger index = ([_titleField.text integerValue]-1)*NUM_PER_ROW;
        if (index >= _rowNum) {
            index = _rowNum - 1;
            _titleField.text = [NSString stringWithFormat:@"%d", index/NUM_PER_ROW+1];
            [self scrollViewDidScroll:self.collectionView];
        }
        NSIndexPath *indexPath = [self getChallengeIndexPath:index];
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section] atScrollPosition:UICollectionViewScrollPositionTop animated:NO];
        [self.navigationItem.titleView resignFirstResponder];
        _goButton.title = STR_BOTTOM;
        
        [self scrollViewDidScroll:self.collectionView];
    } else {
        NSInteger index = _gd.playerInfo.currChallengeId-1;
        if (index > _rowNum-1) {
            index = _rowNum-1;
        }
        NSIndexPath *indexPath = [self getChallengeIndexPath:index];
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section] atScrollPosition:UICollectionViewScrollPositionTop animated:NO];
    }
}

- (void)singleTapGestureCaptured:(UITapGestureRecognizer *)gesture {
    [self.navigationItem.titleView resignFirstResponder];
    
    _goButton.title = STR_BOTTOM;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:CGPointMake(0, scrollView.contentOffset.y+scrollView.contentInset.top)];
    int chaIdx = [self getChallengeIndex:indexPath];
    
    if (chaIdx == 0 && scrollView.contentOffset.y > 50) {
        return;
    }
    _titleField.text = [NSString stringWithFormat:@"%d", chaIdx/NUM_PER_ROW+1];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    if (_rowNum%NUM_PER_SECTION == 0) {
        return _rowNum/NUM_PER_SECTION;
    }
    return _rowNum/NUM_PER_SECTION + 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (section == [self numberOfSectionsInCollectionView:collectionView]-1) {
        int num = _rowNum % NUM_PER_SECTION;
        if (num == 0) {
            return NUM_PER_SECTION;
        }
        return _rowNum % NUM_PER_SECTION;
    }
    return NUM_PER_SECTION;
    //return _rowNum;
}

- (int)getChallengeIndex:(NSIndexPath*)indexPath {
    return indexPath.section * NUM_PER_SECTION + indexPath.row;
}

- (NSIndexPath*)getChallengeIndexPath:(int)index {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index%NUM_PER_SECTION inSection:index/NUM_PER_SECTION];
    return indexPath;
}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SldChallengeCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"challengeCell" forIndexPath:indexPath];
    [cell.imageView releaseImage];
    cell.imageView.image = _loadingImage;
    cell.starLabel.text = @"";
    cell.dimmer.hidden = YES;
    
    int chaIdx = [self getChallengeIndex:indexPath];
    ChallengeInfo *cha = [_gd.challengeInfos objectAtIndex:chaIdx];
    
    if (cha.missing) {
        if (chaIdx+1 == _gd.playerInfo.currChallengeId) {
            cell.imageView.image = _missingImage;
        } else {
            cell.imageView.image = _dollarImage;
        }
        
        
        return cell;
    }
    
    if (chaIdx < _gd.challengeInfos.count) {
        //is locked?
        if (cha.id > _gd.playerInfo.currChallengeId) {
            cell.locker.hidden = NO;
        } else {
            cell.locker.hidden = YES;
        }
        
        //
        if (cha.thumb) { //event info loaded
            [cell.imageView asyncLoadImageWithKey:cha.thumb showIndicator:NO completion:nil];
            if (cell.imageView.task) {
                [_downloadTasks addObject:cell.imageView.task];
                if (_downloadTasks.count > 24) {
                    NSURLSessionDownloadTask *task = [_downloadTasks firstObject];
                    [task cancel];
                    [_downloadTasks removeObjectAtIndex:0];
                }
            }
            
            //
            if (cha.cupType == CUP_BRONZE) {
                cell.starLabel.text = @"⭐️";
            } else if (cha.cupType == CUP_SILVER) {
                cell.starLabel.text = @"⭐️⭐️";
            } else if (cha.cupType == CUP_GOLD) {
                cell.starLabel.text = @"⭐️⭐️⭐️";
            }
            if (cha.cupType == CUP_NONE) {
                cell.dimmer.hidden = YES;
            } else {
                cell.dimmer.hidden = NO;
            }
            
        } else if (cha.isLoading == NO){ //no event info
            
            int batchIdx = chaIdx / EVENT_NUM_PER_BATCH;
            int offset = batchIdx * EVENT_NUM_PER_BATCH;
            
            SldHttpSession *session = [SldHttpSession defaultSession];
            NSDictionary *body = @{@"Offset":@(offset), @"Limit":@(EVENT_NUM_PER_BATCH)};
            for (int i = offset; i < offset + EVENT_NUM_PER_BATCH; i++) {
                if (i >= _gd.challengeInfos.count) {
                    break;
                }
                ChallengeInfo *cha = [_gd.challengeInfos objectAtIndex:i];
                cha.isLoading = YES;
            }
            [session postToApi:@"challenge/list" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error) {
                    alertHTTPError(error, data);
                    return;
                }
                
                NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                if (error) {
                    lwError("Json error:%@", [error localizedDescription]);
                    return;
                }
                
                NSMutableArray *reloads = [NSMutableArray array];
                int index = offset;
                for (NSDictionary *dict in array) {
                    ChallengeInfo *cha = [ChallengeInfo challengeWithDictionary:dict];
                    if (index >= _gd.challengeInfos.count) {
                        break;
                    }
                    NSIndexPath *indexPath = [self getChallengeIndexPath:index];
                    [_gd.challengeInfos replaceObjectAtIndex:index withObject:cha];
                    [reloads addObject:indexPath];
                    index++;
                }
                
                //check missing event
                int imax = MIN(_gd.challengeInfos.count, chaIdx + EVENT_NUM_PER_BATCH);
                for (int i = chaIdx; i < imax; i++) {
                    ChallengeInfo *cha = _gd.challengeInfos[i];
                    if (cha.id == 0) {
                        cha.missing = YES;
                        cha.id = i + 1;
                        NSIndexPath *indexPath = [self getChallengeIndexPath:i];
                        [reloads addObject:indexPath];
                    }
                }
                
                [self.collectionView reloadItemsAtIndexPaths:reloads];
            }];
        }
        
//        //fixme
//        NSString *gravatarKey = [NSString stringWithFormat:@"%d", indexPath.row];
//        NSString *url = [SldUtil makeGravatarUrlWithKey:gravatarKey width:48];
//        [cell.imageView asyncLoadImageWithUrl:url showIndicator:NO completion:^{
//            if (cell.imageView.task) {
//                [_downloadTasks removeObject:cell.imageView.task];
//            }
//        }];
//        if (cell.imageView.task) {
//            [_downloadTasks addObject:cell.imageView.task];
//            if (_downloadTasks.count > 24) {
//                NSURLSessionDownloadTask *task = [_downloadTasks firstObject];
//                [task cancel];
//                [_downloadTasks removeObjectAtIndex:0];
//                lwInfo("%d", _downloadTasks.count);
//            }
//        }
    }
    
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (kind == UICollectionElementKindSectionHeader) {
        SldChallengeHeader *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"challengeHeader" forIndexPath:indexPath];
        
        //bg color
        float h = (float)(indexPath.section * 50 % 360)/360.0;
        headerView.backgroundColor = [UIColor colorWithHue:h saturation:0.74 brightness:0.90 alpha:1.0];
        
        //city
        NSInteger sec = indexPath.section;
        sec = sec % _cityNames.count;
        headerView.cityLabel.text = [_cityNames objectAtIndex:sec];
        return headerView;
    }
    return nil;
}

#pragma mark - Navigation

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if (identifier && [identifier compare:@"toChallengeSeg"] == 0) {
        UIButton *button = sender;
        SldChallengeCell *cell = (SldChallengeCell*)button.superview.superview;
        NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
        int chaIdx = [self getChallengeIndex:indexPath];
        if (chaIdx < [_gd.challengeInfos count]) {
            ChallengeInfo *cha = [_gd.challengeInfos objectAtIndex:chaIdx];
            if (cha.missing) {
                if (cha.id == _gd.playerInfo.currChallengeId) {
                    SldHttpSession *session = [SldHttpSession defaultSession];
                    NSDictionary *body = @{@"ChallengeId":@(cha.id)};
                    UIAlertView *alt =  alertNoButton(@"抽奖中...");
                    [session postToApi:@"challenge/passMissingChallenge" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                        [alt dismissWithClickedButtonIndex:0 animated:YES];
                        if (error) {
                            alertHTTPError(error, data);
                            return;
                        }
                        
                        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                        if (error) {
                            lwError("Json error:%@", [error localizedDescription]);
                            return;
                        }
                        
                        int addMoney = [(NSNumber*)[dict objectForKey:@"AddMoney"] intValue];
                        SInt64 money = [(NSNumber*)[dict objectForKey:@"Money"] longLongValue];
                        int currChallengeId = [(NSNumber*)[dict objectForKey:@"CurrChallengeId"] intValue];
                        
                        alert([NSString stringWithFormat:@"恭喜中奖！！！你赢了%d金币！！！", addMoney], nil);
                        _gd.playerInfo.money = money;
                        _gd.playerInfo.currChallengeId = currChallengeId;
                        
                        NSIndexPath *ip = [NSIndexPath indexPathForRow:indexPath.row+1 inSection:indexPath.section];
                        [self.collectionView reloadItemsAtIndexPaths:[NSArray arrayWithObject:ip]];
                        cell.imageView.image = _dollarImage;
                    }];
                } else {
                    [[AdMoGoInterstitialManager shareInstance] interstitialShow:YES];
                }
                return NO;
            }else if (cha.id <= _gd.playerInfo.currChallengeId && cha.id > 0) {
                return YES;
            }
            
        }
    }
    return NO;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (segue.identifier && [segue.identifier compare:@"toChallengeSeg"] == 0) {
        UIButton *button = sender;
        UICollectionViewCell *cell = (UICollectionViewCell*)button.superview.superview;
        NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
        int chaIdx = [self getChallengeIndex:indexPath];
        if (chaIdx < [_gd.challengeInfos count]) {
            _gd.challengeInfo = [_gd.challengeInfos objectAtIndex:chaIdx];
        }
    }
}

@end
