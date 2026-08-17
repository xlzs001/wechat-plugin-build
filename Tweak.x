#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ==========================================
// 1. 微信原生数据模型声明
// ==========================================
@interface MMMenuItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) UIImage *iconImage;
@property (nonatomic, assign) SEL action;
@property (nonatomic, weak) id target;
@end

@interface MMMenuController : NSObject
@property (nonatomic, strong) NSArray *menuItems; 
- (void)setMenuItems:(NSArray *)arg1;
@end


// ==========================================
// 2. 核心逻辑：统一过滤与排序处理函数
// ==========================================
static NSArray *processMenuItems(NSArray *originItems) {
    if (!originItems || originItems.count == 0) {
        return originItems;
    }

    // 动态从本地读取用户在 UI 界面中设置的配置
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 读取黑名单配置，如果没有配置过，默认隐藏搜一搜和相关表情
    NSArray *blacklist = [defaults objectForKey:@"WCCustomMenu_Blacklist"] ?: @[
        @"搜一搜",
        @"相关表情",
        @"合拍",
        @"转自拍"
    ];

    // 读取排序优先级配置，如果没有配置过，按这个默认顺序排
    NSArray *priorityOrder = [defaults objectForKey:@"WCCustomMenu_SortOrder"] ?: @[
        @"复制",
        @"转发",
        @"删除",
        @"引用",
        @"提醒"
    ];
    
    // 【编辑项配置】：修改按钮的文字显示 (静态映射即可)
    NSDictionary *renameMap = @{
        @"多选": @"批量",
        @"从当前听": @"听语音",
        @"收藏": @"存入收藏"
    };

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


// ==========================================
// 3. Hook 微信菜单控制器
// ==========================================
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


// ==========================================
// 4. 界面入口 Hook 代码 (临时注入微信原生“设置”页面)
// ==========================================

// 声明 UI 控制器
@interface WCCustomMenuSettingVC : UIViewController
@end

// 声明微信原生设置页面的 Cell 和 Section 管理器
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

// 明确告诉编译器这是一个视图控制器
@interface NewSettingViewController : UIViewController
@end

// Hook 微信原生的设置页面控制器
%hook NewSettingViewController

- (void)reloadTableData {
    %orig; 

    WCTableViewManager *manager = [self valueForKey:@"m_tableViewManager"];
    if (manager) {
        WCTableViewSectionManager *section = [%c(WCTableViewSectionManager) sectionInfoDefaut];
        
        WCTableViewNormalCellManager *cell = [%c(WCTableViewNormalCellManager) normalCellForSel:@selector(showMyCustomMenuPlugin) target:self title:@"🛠️ 菜单自定义设置 (测试入口)"];
        [section addCell:cell];
        
        [manager insertSection:section atIndex:0];
        [[manager getTableView] reloadData];
    }
}

%new
- (void)showMyCustomMenuPlugin {
    WCCustomMenuSettingVC *vc = [[WCCustomMenuSettingVC alloc] init];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

%end
