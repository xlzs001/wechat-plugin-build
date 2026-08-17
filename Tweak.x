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

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSArray *blacklist = [defaults objectForKey:@"WCCustomMenu_Blacklist"] ?: @[
        @"搜一搜",
        @"相关表情",
        @"合拍",
        @"转自拍"
    ];

    NSArray *priorityOrder = [defaults objectForKey:@"WCCustomMenu_SortOrder"] ?: @[
        @"复制",
        @"转发",
        @"删除",
        @"引用",
        @"提醒"
    ];
    
    NSDictionary *renameMap = @{
        @"多选": @"批量",
        @"从当前听": @"听语音",
        @"收藏": @"存入收藏"
    };

    NSMutableArray *remainingItems = [NSMutableArray array];
    NSMutableDictionary *priorityItemMap = [NSMutableDictionary dictionary];

    for (MMMenuItem *item in originItems) {
        if (![item respondsToSelector:@selector(title)] || !item.title) {
            [remainingItems addObject:item];
            continue;
        }

        NSString *title = item.title;

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

        if (renameMap[title]) {
            item.title = renameMap[title];
            title = item.title;
        }

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

    NSMutableArray *finalItems = [NSMutableArray array];

    for (NSString *pName in priorityOrder) {
        MMMenuItem *item = [priorityItemMap objectForKey:pName];
        if (item) {
            [finalItems addObject:item];
        }
    }

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

@interface WCCustomMenuSettingVC : UIViewController
@end

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

@interface NewSettingViewController : UIViewController
@end

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
