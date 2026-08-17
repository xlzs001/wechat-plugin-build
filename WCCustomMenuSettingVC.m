#import <UIKit/UIKit.h>

@interface WCCustomMenuSettingVC : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *allMenuNames;
@property (nonatomic, strong) NSMutableSet *hiddenItems; // 黑名单
@property (nonatomic, strong) NSMutableArray *sortOrder; // 排序
@end

@implementation WCCustomMenuSettingVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"菜单自定义设置";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    
    // 初始化默认数据（实际开发中应先从 NSUserDefaults 读取）
    self.allMenuNames = [@[@"复制", @"转发", @"收藏", @"删除", @"引用", @"提醒", @"搜一搜", @"相关表情"] mutableCopy];
    self.hiddenItems = [[NSMutableSet alloc] init];
    self.sortOrder = [self.allMenuNames mutableCopy];
    
    // 创建列表视图
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView setEditing:YES animated:NO]; // 默认开启编辑模式以支持拖拽
    [self.view addSubview:self.tableView];
    
    // 添加保存按钮
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"保存" style:UIBarButtonItemStyleDone target:self action:@selector(saveSettings)];
}

// 保存配置到本地，供 Tweak.x 读取
- (void)saveSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[self.hiddenItems allObjects] forKey:@"WCCustomMenu_Blacklist"];
    [defaults setObject:self.sortOrder forKey:@"WCCustomMenu_SortOrder"];
    [defaults synchronize];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"保存成功" message:@"配置已生效，长按消息即可查看效果。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - TableView DataSource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2; // 0: 开关控制, 1: 拖拽排序
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.allMenuNames.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"显示/隐藏控制" : @"拖拽排序控制 (按住右侧图标拖动)";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"MenuCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
    }
    
    NSString *itemName = self.allMenuNames[indexPath.row];
    cell.textLabel.text = itemName;
    
    if (indexPath.section == 0) {
        // 第一组：放置开关
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = ![self.hiddenItems containsObject:itemName];
        switchView.tag = indexPath.row;
        [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
        cell.showsReorderControl = NO; // 不显示拖拽
    } else {
        // 第二组：拖拽排序
        cell.accessoryView = nil;
        cell.showsReorderControl = YES;
    }
    
    return cell;
}

// 监听开关变化
- (void)switchChanged:(UISwitch *)sender {
    NSString *itemName = self.allMenuNames[sender.tag];
    if (sender.on) {
        [self.hiddenItems removeObject:itemName];
    } else {
        [self.hiddenItems addObject:itemName];
    }
}

// 允许第二组进行拖拽排序
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 1;
}

// 处理拖拽后的数据重新排列
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    NSString *movedItem = self.sortOrder[sourceIndexPath.row];
    [self.sortOrder removeObjectAtIndex:sourceIndexPath.row];
    [self.sortOrder insertObject:movedItem atIndex:destinationIndexPath.row];
}

// 禁止跨组拖拽和删除操作
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}
- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

@end
