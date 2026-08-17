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
// 4. 适配“插件收纳”专用 API (微信->我->插件)
// ==========================================
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

%ctor {
    // 为了防止你的多个 dylib 加载顺序随机导致找不到 WCPluginsMgr，
    // 我们把注册时机推迟到 App 启动完成的瞬间，这样是最稳妥的。
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        
        if (NSClassFromString(@"WCPluginsMgr")) {
            // 调用对方的 API，把我们的 UI 界面 (WCCustomMenuSettingVC) 交给它托管
            [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:@"菜单自定义" 
                                                                                version:@"1.0.0" 
                                                                             controller:@"WCCustomMenuSettingVC"];
        }
        
    }];
}
