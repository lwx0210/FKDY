#import "AwemeHeaders.h"
#import "DYYYManager.h"
#import "CityManager.h"
#import "DYYYUtils.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>

#pragma mark

static bool getUserDefaults(NSString *key) { return [[NSUserDefaults standardUserDefaults] boolForKey:key]; }
#define DYYYALLOW_KEY @"DYYYAllowConcurrentPlay"

//允许应用同时播放
%hook AVAudioSession

- (BOOL)setCategory:(AVAudioSessionCategory)category withOptions:(AVAudioSessionCategoryOptions)options error:(NSError **)outError {
    if (getUserDefaults(DYYYALLOW_KEY) &&
        ([category isEqualToString:AVAudioSessionCategoryPlayback] ||
        [category isEqualToString:AVAudioSessionCategoryPlayAndRecord] ||
        [category isEqualToString:AVAudioSessionCategoryMultiRoute])) {
        options |= AVAudioSessionCategoryOptionMixWithOthers;
        %log;
    }
    return %orig(category, options, outError);
}

- (BOOL)setCategory:(AVAudioSessionCategory)category error:(NSError **)outError {
    if (getUserDefaults(DYYYALLOW_KEY) &&
        ([category isEqualToString:AVAudioSessionCategoryPlayback] ||
        [category isEqualToString:AVAudioSessionCategoryPlayAndRecord] ||
        [category isEqualToString:AVAudioSessionCategoryMultiRoute])) {
        return [self setCategory:category
                     withOptions:AVAudioSessionCategoryOptionMixWithOthers
                           error:outError];
    }
    return %orig;
}

- (BOOL)setCategory:(AVAudioSessionCategory)category mode:(AVAudioSessionMode)mode options:(AVAudioSessionCategoryOptions)options error:(NSError **)outError {
 
    if (getUserDefaults(DYYYALLOW_KEY) &&
        ([category isEqualToString:AVAudioSessionCategoryPlayback] ||
        [category isEqualToString:AVAudioSessionCategoryPlayAndRecord] ||
        [category isEqualToString:AVAudioSessionCategoryMultiRoute])) {
        options |= AVAudioSessionCategoryOptionMixWithOthers;
        %log;
    }
    return %orig(category, mode, options, outError);
}

- (BOOL)setActive:(BOOL)active withOptions:(AVAudioSessionSetActiveOptions)options error:(NSError **)outError {
    BOOL result = %orig;
    if (getUserDefaults(DYYYALLOW_KEY) && active && result) {
        AVAudioSessionCategoryOptions currentOptions = [self categoryOptions];
        if (!(currentOptions & AVAudioSessionCategoryOptionMixWithOthers)) {
            AVAudioSessionCategory currentCategory = [self category];
            if ([currentCategory isEqualToString:AVAudioSessionCategoryPlayback] ||
                [currentCategory isEqualToString:AVAudioSessionCategoryPlayAndRecord] ||
                [currentCategory isEqualToString:AVAudioSessionCategoryMultiRoute]) {
                [self setCategory:currentCategory
                      withOptions:currentOptions | AVAudioSessionCategoryOptionMixWithOthers
                            error:nil];
            }
        }
    }
    return result;
}

%end

//IP属地信息
%hook AWEPlayInteractionTimestampElement
- (id)timestampLabel {
    UILabel *label = %orig;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableArea"]) {
        NSString *text = label.text;
        NSString *areaCode = self.model.cityCode;

        NSLog(@"[XUUZ] 当前 areaCode: %@ (%lu 位)", areaCode, (unsigned long)areaCode.length);

        NSString *province = [CityManager.sharedInstance getProvinceNameWithCode:areaCode] ?: @"";
        NSString *city = [CityManager.sharedInstance getCityNameWithCode:areaCode] ?: @"";
        NSString *district = [CityManager.sharedInstance getDistrictNameWithCode:areaCode] ?: @"";
        NSString *street = [CityManager.sharedInstance getStreetNameWithCode:areaCode] ?: @"";

        NSMutableArray *components = [NSMutableArray new];
        NSString *prefix = areaCode.length >= 2 ? [areaCode substringToIndex:2] : @"";

        if ([@[@"81", @"82", @"71"] containsObject:prefix]) {
            
            if (province.length > 0) [components addObject:province];
            if (city.length > 0) [components addObject:city];
            if (district.length > 0) [components addObject:district];
        } else {
                
                if (province.length > 0 && areaCode.length >= 2) {
                [components addObject:province];
            }

            if (city.length > 0 && areaCode.length >= 4 && ![city isEqualToString:province]) {
                [components addObject:city];
            }

            if (district.length > 0 && areaCode.length >= 6) {
                [components addObject:district];
            } 
        }

        if (components.count > 0) {
            NSString *locationString = [components componentsJoinedByString:@" "];
            NSString *cleanedText = [text stringByReplacingOccurrencesOfString:@"IP属地：.*"
                                                                    withString:@""
                                                                       options:NSRegularExpressionSearch
                                                                         range:NSMakeRange(0, text.length)];

            if ([prefix isEqualToString:@"71"] && [district containsString:@"福建省"]) {
                locationString = [locationString stringByReplacingOccurrencesOfString:@"(福建省)"
                                                                          withString:@""
                                                                             options:NSRegularExpressionSearch
                                                                               range:NSMakeRange(0, locationString.length)];
            }

            label.text = [NSString stringWithFormat:@"% @ IP属地：%@",
                          [cleanedText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]],
                          locationString];
        }
    }
}

+ (BOOL)shouldActiveWithData:(id)arg1 context:(id)arg2 {
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableArea"];
}

%end

// 个人自定义
#define DYYY_SOCIAL_STATS_ENABLED_KEY @"DYYYEnableSocialStatsCustom"
#define DYYY_SOCIAL_FOLLOWERS_KEY @"DYYYCustomFollowers"
#define DYYY_SOCIAL_LIKES_KEY @"DYYYCustomLikes"
#define DYYY_SOCIAL_FOLLOWING_KEY @"DYYYCustomFollowing"
#define DYYY_SOCIAL_MUTUAL_KEY @"DYYYCustomMutual"

// 静态缓存
static NSString *customFollowersCount = nil;
static NSString *customLikesCount = nil;
static NSString *customFollowingCount = nil;
static NSString *customMutualCount = nil;
static BOOL socialStatsEnabled = NO;

// 静态缓存的NSNumber值
static NSNumber *cachedFollowersNumber = nil;
static NSNumber *cachedLikesNumber = nil;
static NSNumber *cachedFollowingNumber = nil;
static NSNumber *cachedMutualNumber = nil;

// 防止重复更新
static BOOL isUpdatingViews = NO;
static NSTimeInterval lastUpdateTimestamp = 0;

// 函数声明
static void loadCustomSocialStats(void);
static void updateModelData(id model);

// 加载设置数据
static void loadCustomSocialStats() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    socialStatsEnabled = [defaults boolForKey:DYYY_SOCIAL_STATS_ENABLED_KEY];
    
    if (socialStatsEnabled) {
        customFollowersCount = [defaults objectForKey:DYYY_SOCIAL_FOLLOWERS_KEY];
        customLikesCount = [defaults objectForKey:DYYY_SOCIAL_LIKES_KEY];
        customFollowingCount = [defaults objectForKey:DYYY_SOCIAL_FOLLOWING_KEY];
        customMutualCount = [defaults objectForKey:DYYY_SOCIAL_MUTUAL_KEY];
        
        cachedFollowersNumber = customFollowersCount ? @([customFollowersCount longLongValue]) : nil;
        cachedLikesNumber = customLikesCount ? @([customLikesCount longLongValue]) : nil;
        cachedFollowingNumber = customFollowingCount ? @([customFollowingCount longLongValue]) : nil;
        cachedMutualNumber = customMutualCount ? @([customMutualCount longLongValue]) : nil;
    }
}

// 模型数据更新
static void updateModelData(id model) {
    if (!socialStatsEnabled || !model) return;
    
    // 粉丝
    if (cachedFollowersNumber) {
        NSArray *followerKeys = @[@"followerCount", @"fansCount", @"fans_count"];
        for (NSString *key in followerKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedFollowersNumber forKey:key];
            }
        }
    }
    
    // 获赞
    if (cachedLikesNumber) {
        NSArray *likeKeys = @[
            @"totalFavorited", @"favoriteCount", @"diggCount", 
            @"praiseCount", @"likeCount", @"like_count",
            @"total_favorited", @"favorite_count", @"digg_count"
        ];
        for (NSString *key in likeKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedLikesNumber forKey:key];
            }
        }
    }
    
    // 关注
    if (cachedFollowingNumber) {
        NSArray *followingKeys = @[@"followingCount", @"followCount", @"follow_count"];
        for (NSString *key in followingKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedFollowingNumber forKey:key];
            }
        }
    }
    
    // 互关
    if (cachedMutualNumber) {
        NSArray *mutualKeys = @[
            @"friendCount", @"mutualFriendCount", @"followFriendCount",
            @"mutualCount", @"friend_count", @"mutual_friend_count",
            @"follow_friend_count", @"mutual_count"
        ];
        for (NSString *key in mutualKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedMutualNumber forKey:key];
            }
        }
    }
}

%hook AWEUserModel
- (id)init {
    id instance = %orig;
    if (socialStatsEnabled && instance) {
        updateModelData(instance);
    }
    return instance;
}

- (NSNumber *)followerCount {
    return socialStatsEnabled && cachedFollowersNumber ? cachedFollowersNumber : %orig;
}

- (void)setFollowerCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedFollowersNumber) {
        %orig(cachedFollowersNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)followingCount {
    return socialStatsEnabled && cachedFollowingNumber ? cachedFollowingNumber : %orig;
}

- (void)setFollowingCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedFollowingNumber) {
        %orig(cachedFollowingNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)totalFavorited {
    return socialStatsEnabled && cachedLikesNumber ? cachedLikesNumber : %orig;
}

- (void)setTotalFavorited:(NSNumber *)count {
    if (socialStatsEnabled && cachedLikesNumber) {
        %orig(cachedLikesNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)diggCount {
    return socialStatsEnabled && cachedLikesNumber ? cachedLikesNumber : %orig;
}

- (void)setDiggCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedLikesNumber) {
        %orig(cachedLikesNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)likeCount {
    return socialStatsEnabled && cachedLikesNumber ? cachedLikesNumber : %orig;
}

- (void)setLikeCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedLikesNumber) {
        %orig(cachedLikesNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)friendCount {
    return socialStatsEnabled && cachedMutualNumber ? cachedMutualNumber : %orig;
}

- (void)setFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedMutualNumber) {
        %orig(cachedMutualNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)mutualFriendCount {
    return socialStatsEnabled && cachedMutualNumber ? cachedMutualNumber : %orig;
}

- (void)setMutualFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedMutualNumber) {
        %orig(cachedMutualNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)followFriendCount {
    return socialStatsEnabled && cachedMutualNumber ? cachedMutualNumber : %orig;
}

- (void)setFollowFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedMutualNumber) {
        %orig(cachedMutualNumber);
    } else {
        %orig;
    }
}
%end


// 统计视图
%hook AWEProfileSocialStatisticView
- (void)setFansCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedFollowersNumber) {
        %orig(cachedFollowersNumber);
    } else {
        %orig;
    }
}

- (void)setPraiseCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedLikesNumber) {
        %orig(cachedLikesNumber);
    } else {
        %orig;
    }
}
- (void)setFollowingCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedFollowingNumber) {
        %orig(cachedFollowingNumber);
    } else {
        %orig;
    }
}
- (void)setFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedMutualNumber) {
        %orig(cachedMutualNumber);
    } else {
        %orig;
    }
}
- (void)p_updateSocialStatisticContent:(BOOL)animated {
    %orig;
    if (socialStatsEnabled && !isUpdatingViews) {
        isUpdatingViews = YES;
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        if (now - lastUpdateTimestamp < 0.5) {
            isUpdatingViews = NO;
            return;
        }
        lastUpdateTimestamp = now;
        
        __weak __typeof__(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong __typeof__(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                isUpdatingViews = NO;
                return;
            }
            
            @try {
                if (cachedFollowersNumber) [strongSelf setFansCount:cachedFollowersNumber];
                if (cachedLikesNumber) [strongSelf setPraiseCount:cachedLikesNumber];
                if (cachedFollowingNumber) [strongSelf setFollowingCount:cachedFollowingNumber];
                if (cachedMutualNumber) [strongSelf setFriendCount:cachedMutualNumber];
            } @catch (NSException *e) {
                NSLog(@"[DYYY] Exception in updating stats: %@", e);
            } @finally {
                isUpdatingViews = NO;
            }
        });
    }
}
- (void)layoutSubviews {
    %orig;
    
    if (socialStatsEnabled && !isUpdatingViews) {
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        if (now - lastUpdateTimestamp < 0.5) return;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self p_updateSocialStatisticContent:YES];
        });
    }
}
%end


// 字典数据源
%hook NSDictionary
- (id)objectForKey:(id)aKey {
    id originalValue = %orig;
    if (!socialStatsEnabled || !aKey || !originalValue || ![aKey isKindOfClass:[NSString class]]) {
        return originalValue;
    }
    
    NSString *keyString = (NSString *)aKey;
    
    // 粉丝
    if (cachedFollowersNumber && 
        ([keyString isEqualToString:@"follower_count"] ||
         [keyString isEqualToString:@"fans_count"] ||
         [keyString isEqualToString:@"follower"] ||
         [keyString isEqualToString:@"fans"])) {
        if ([originalValue isKindOfClass:[NSNumber class]]) {
            return cachedFollowersNumber;
        }
    }
    
    // 获赞
    if (cachedLikesNumber && 
        ([keyString isEqualToString:@"total_favorited"] ||
         [keyString isEqualToString:@"favorite_count"] ||
         [keyString isEqualToString:@"digg_count"] ||
         [keyString isEqualToString:@"like_count"] ||
         [keyString isEqualToString:@"praise_count"])) {
        if ([originalValue isKindOfClass:[NSNumber class]]) {
            return cachedLikesNumber;
        }
    }
    
    // 关注
    if (cachedFollowingNumber && 
        ([keyString isEqualToString:@"following_count"] ||
         [keyString isEqualToString:@"follow_count"] ||
         [keyString isEqualToString:@"following"] ||
         [keyString isEqualToString:@"follow"])) {
        if ([originalValue isKindOfClass:[NSNumber class]]) {
            return cachedFollowingNumber;
        }
    }
    
    // 互关
    if (cachedMutualNumber && 
        ([keyString isEqualToString:@"friend_count"] ||
         [keyString isEqualToString:@"mutual_friend_count"] ||
         [keyString isEqualToString:@"mutual_count"] ||
         [keyString isEqualToString:@"friendship_count"])) {
        if ([originalValue isKindOfClass:[NSNumber class]]) {
            return cachedMutualNumber;
        }
    }
    
    return originalValue;
}
%end

%ctor {
    loadCustomSocialStats();
}
