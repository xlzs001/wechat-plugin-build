#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// --- 头文件接口声明 ---
@interface MMMenuItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) UIImage *iconImage;
@property (nonatomic, assign) SEL action;
@property (nonatomic, weak) id target;
@end

@interface MMMenuController : NSObject
@property (nonatomic, strong) NSArray *menuItems; // <--- 之前这里写成了 NSMutableArray，已修正
- (void)setMenuItems:(NSArray *)arg1;
@end

// --- 统一过滤与排序处理函数 ---
static NSArray *processMenuItems(NSArray *originItems) {
    if (!originItems || originItems.count == 0) {
        return originItems;
    }

    // 1. 【删除项配置】：出现在此数组中的按钮将被完全移除
    NSArray *blacklist = @[
        @"搜一搜",
        @"相关表情",
        @"合拍",
        @"转自拍"
    ];

    // 2. 【编辑项配置】：修改按钮的文字显示
    NSDictionary *renameMap = @{
        @"多选": @"批量",
        @"从当前听": @"听语音",
        @"收藏": @"存入收藏"
    };

    // 3. 【排序优先级配置】：排在此数组前面的项，在菜单中会优先靠前展示
    NSArray *priorityOrder = @[
        @"复制",
        @"转发",
        @"删除",
        @"引用",
        @"提醒"
    ];

    NSMutableArray *remainingItems = [NSMutableArray array];
    NSMutableDictionary *priorityItemMap = [NSMutableDictionary dictionary];

    // 遍历原始列表
    for (MMMenuItem *item in originItems) {
        if (![item respondsToSelector:@selector(title)] || !item.title) {
            [remainingItems addObject:item];
            continue;
        }

        NSString *title = item.title;

        // 步骤 1：黑名单过滤（删除）
        BOOL isBlacklisted = NO;
        for (NSString *blackItem in blacklist) {
            if ([title containsString:blackItem]) {
                isBlacklisted = YES;
                break;
            }
        }
        if (isBlacklisted) {
            continue;
        }

        // 步骤 2：重命名编辑
        if (renameMap[title]) {
            item.title = renameMap[title];
            title = item.title;
        }

        // 步骤 3：分类归档以供排序
        BOOL matchedPriority = NO;
        for (NSString *pName in priorityOrder) {
            if ([title isEqualToString:pName] || [title isEqualToString:renameMap[pName]]) {
                [priorityItemMap setObject:item forKey:pName];
                matchedPriority = YES;
                break;
            }
        }

        if (!matchedPriority) {
            [remainingItems addObject:item];
        }
    }

    // 步骤 4：组装最终排序结果
    NSMutableArray *finalItems = [NSMutableArray array];

    // 先插入高优先级项
    for (NSString *pName in priorityOrder) {
        MMMenuItem *item = [priorityItemMap objectForKey:pName];
        if (item) {
            [finalItems addObject:item];
        }
    }

    // 再追加其余正常项
    [finalItems addObjectsFromArray:remainingItems];

    return [finalItems copy];
}

// --- Hook MMMenuController ---
%hook MMMenuController

- (void)setMenuItems:(NSArray *)arg1 {
    NSArray *modified = processMenuItems(arg1);
    %orig(modified);
}

- (NSArray *)menuItems {
    NSArray *origList = %orig;
    return processMenuItems(origList);
}

%end

// 1. 声明微信原生的表格管理类（大部分第三方插件复用这个机制）
@interface WCTableViewNormalCellManager : NSObject
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionInfoDefaut;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewManager : NSObject
- (void)insertSection:(id)arg1 atIndex:(unsigned int)arg2;
- (id)getTableView;
@end

// 2. 声明我们的自定义设置页面
@interface WCCustomMenuSettingVC : UIViewController
@end

// 3. Hook 插件收纳的控制器 (重点：你需要替换下面这个类名)
// 假设“插件收纳”的类名叫做 PluginCenterViewController
%hook PluginCenterViewController

- (void)reloadTableData {
    %orig; // 先让它加载原本的其他插件列表

    // 获取页面的 table manager (大部分类似插件把这个属性命名为 m_tableViewManager)
    WCTableViewManager *manager = [self valueForKey:@"m_tableViewManager"];
    if (manager) {
        // 创建一个新的区块 (Section)
        WCTableViewSectionManager *section = [%c(WCTableViewSectionManager) sectionInfoDefaut];
        
        // 创建一行 (Cell)，点击后执行下面的 showMyPlugin 方法
        WCTableViewNormalCellManager *cell = [%c(WCTableViewNormalCellManager) normalCellForSel:@selector(showMyPlugin) target:self title:@"菜单自定义设置"];
        [section addCell:cell];
        
        // 把我们的区块插入到列表的最上面 (Index 0)
        [manager insertSection:section atIndex:0];
        
        // 刷新列表
        [[manager getTableView] reloadData];
    }
}

// 4. 给这个类动态添加一个点击事件方法
%new
- (void)showMyPlugin {
    WCCustomMenuSettingVC *vc = [[WCCustomMenuSettingVC alloc] init];
    // 隐藏底部导航栏（如果存在）
    vc.hidesBottomBarWhenPushed = YES;
    // 推出我们的自定义 UI
    [self.navigationController pushViewController:vc animated:YES];
}

%end
// ==========================================
// 以下为界面入口 Hook 代码
// 临时注入到微信原生的“设置”页面中进行测试
// ==========================================

// 1. 声明 UI 控制器
@interface WCCustomMenuSettingVC : UIViewController
@end

// 2. 声明微信原生设置页面的 Cell 和 Section 管理器
@interface WCTableViewNormalCellManager : NSObject
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionInfoDefaut;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewManager : NSObject
- (void)insertSection:(id)arg1 atIndex:(unsigned int)arg2;
- (id)getTableView;
@end

// 3. Hook 微信原生的设置页面控制器
%hook NewSettingViewController

- (void)reloadTableData {
    %orig; // 先让微信加载原本的设置列表（账号与安全、新消息通知等）

    // 获取页面的 table manager
    WCTableViewManager *manager = [self valueForKey:@"m_tableViewManager"];
    if (manager) {
        // 创建一个新的区块
        WCTableViewSectionManager *section = [%c(WCTableViewSectionManager) sectionInfoDefaut];
        
        // 创建一行菜单
        WCTableViewNormalCellManager *cell = [%c(WCTableViewNormalCellManager) normalCellForSel:@selector(showMyCustomMenuPlugin) target:self title:@"🛠️ 菜单自定义设置 (测试入口)"];
        [section addCell:cell];
        
        // 把它插入到设置列表的最上面 (Index 0)
        [manager insertSection:section atIndex:0];
        
        // 刷新列表显示
        [[manager getTableView] reloadData];
    }
}

// 给原生设置页面动态添加一个点击跳转方法
%new
- (void)showMyCustomMenuPlugin {
    WCCustomMenuSettingVC *vc = [[WCCustomMenuSettingVC alloc] init];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

%end
