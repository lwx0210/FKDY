//
//  DYYY
//
//  Copyright (c) 2024 huami. All rights reserved.
//  Channel: @huamidev
//  Created on: 2024/10/04
//
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "AwemeHeaders.h"
#import "CityManager.h"
#import "DYYYBottomAlertView.h"
#import "DYYYManager.h"

#import "DYYYConstants.h"
#import "DYYYSettingViewController.h"
#import "DYYYToast.h"
#import "DYYYUtils.h"

// 关闭不可见水印
%hook AWEHPChannelInvisibleWaterMarkModel

- (BOOL)isEnter {
	return NO;
}

- (BOOL)isAppear {
	return NO;
}

%end

// 长按复制个人简介
%hook AWEProfileMentionLabel

- (void)layoutSubviews {
	%orig;

	if (!DYYYGetBool(@"DYYYBioCopyText")) {
		return;
	}

	BOOL hasLongPressGesture = NO;
	for (UIGestureRecognizer *gesture in self.gestureRecognizers) {
		if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]]) {
			hasLongPressGesture = YES;
			break;
		}
	}

	if (!hasLongPressGesture) {
		UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
		longPressGesture.minimumPressDuration = 0.5;
		[self addGestureRecognizer:longPressGesture];
		self.userInteractionEnabled = YES;
	}
}

%new
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
	if (gesture.state == UIGestureRecognizerStateBegan) {
		NSString *bioText = self.text;
		if (bioText && bioText.length > 0) {
			[[UIPasteboard generalPasteboard] setString:bioText];
			[DYYYToast showSuccessToastWithMessage:@"个人简介已复制"];
		}
	}
}

%end

// 默认视频流最高画质
%hook AWEVideoModel

- (AWEURLModel *)playURL {
	if (!DYYYGetBool(@"DYYYEnableVideoHighestQuality")) {
		return %orig;
	}

	// 获取比特率模型数组
	NSArray *bitrateModels = [self bitrateModels];
	if (!bitrateModels || bitrateModels.count == 0) {
		return %orig;
	}

	// 查找比特率最高的模型
	id highestBitrateModel = nil;
	NSInteger highestBitrate = 0;

	for (id model in bitrateModels) {
		NSInteger bitrate = 0;
		BOOL validModel = NO;

		if ([model isKindOfClass:NSClassFromString(@"AWEVideoBSModel")]) {
			id bitrateValue = [model bitrate];
			if (bitrateValue) {
				bitrate = [bitrateValue integerValue];
				validModel = YES;
			}
		}

		if (validModel && bitrate > highestBitrate) {
			highestBitrate = bitrate;
			highestBitrateModel = model;
		}
	}

	// 如果找到了最高比特率模型，获取其播放地址
	if (highestBitrateModel) {
		id playAddr = [highestBitrateModel valueForKey:@"playAddr"];
		if (playAddr && [playAddr isKindOfClass:%c(AWEURLModel)]) {
			return playAddr;
		}
	}

	return %orig;
}

- (NSArray *)bitrateModels {

	NSArray *originalModels = %orig;

	if (!DYYYGetBool(@"DYYYEnableVideoHighestQuality")) {
		return originalModels;
	}

	if (originalModels.count == 0) {
		return originalModels;
	}

	// 查找比特率最高的模型
	id highestBitrateModel = nil;
	NSInteger highestBitrate = 0;

	for (id model in originalModels) {

		NSInteger bitrate = 0;
		BOOL validModel = NO;

		if ([model isKindOfClass:NSClassFromString(@"AWEVideoBSModel")]) {
			id bitrateValue = [model bitrate];
			if (bitrateValue) {
				bitrate = [bitrateValue integerValue];
				validModel = YES;
			}
		}

		if (validModel) {
			if (bitrate > highestBitrate) {
				highestBitrate = bitrate;
				highestBitrateModel = model;
			}
		}
	}

	if (highestBitrateModel) {
		return @[ highestBitrateModel ];
	}

	return originalModels;
}

%end

// 禁用自动进入直播间
%hook AWELiveGuideElement

- (BOOL)enableAutoEnterRoom {
	if (DYYYGetBool(@"DYYYDisableAutoEnterLive")) {
		return NO;
	}
	return %orig;
}

- (BOOL)enableNewAutoEnter {
	if (DYYYGetBool(@"DYYYDisableAutoEnterLive")) {
		return NO;
	}
	return %orig;
}

%end

%hook AWEFeedChannelManager

- (void)reloadChannelWithChannelModels:(id)arg1 currentChannelIDList:(id)arg2 reloadType:(id)arg3 selectedChannelID:(id)arg4 {
	NSArray *channelModels = arg1;
	NSMutableArray *newChannelModels = [NSMutableArray array];
	NSArray *currentChannelIDList = arg2;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableArray *newCurrentChannelIDList = [NSMutableArray arrayWithArray:currentChannelIDList];
	NSString *hideOtherChannels = [defaults objectForKey:@"DYYYHideOtherChannel"] ?: @"";
	NSArray *hideChannelKeywords = [hideOtherChannels componentsSeparatedByString:@","];

	for (AWEHPTopTabItemModel *tabItemModel in channelModels) {
		NSString *channelID = tabItemModel.channelID;
		NSString *newChannelTitle = tabItemModel.title;
		NSString *oldChannelTitle = tabItemModel.channelTitle;
		BOOL isHideChannel = NO;

		if ([channelID isEqualToString:@"homepage_hot_container"]) {
			isHideChannel = [defaults boolForKey:@"DYYYHideHotContainer"];
		} else if ([channelID isEqualToString:@"homepage_follow"]) {
			isHideChannel = [defaults boolForKey:@"DYYYHideFollow"];
		} else if ([channelID isEqualToString:@"homepage_mediumvideo"]) {
			isHideChannel = [defaults boolForKey:@"DYYYHideMediumVideo"];
		} else if ([channelID isEqualToString:@"homepage_mall"]) {
			isHideChannel = [defaults boolForKey:@"DYYYHideMall"];
		} else if ([channelID isEqualToString:@"homepage_nearby"]) {
			isHideChannel = [defaults boolForKey:@"DYYYHideNearby"];
		} else if ([channelID isEqualToString:@"homepage_groupon"]) {
			isHideChannel = [defaults boolForKey:@"DYYYHideGroupon"];
		} else if ([channelID isEqualToString:@"homepage_tablive"]) {
			isHideChannel = [defaults boolForKey:@"DYYYHideTabLive"];
		} else if ([channelID isEqualToString:@"homepage_pad_hot"]) {
			isHideChannel = [defaults boolForKey:@"DYYYHidePadHot"];
		} else if ([channelID isEqualToString:@"homepage_hangout"]) {
			isHideChannel = [defaults boolForKey:@"DYYYHideHangout"];
		} else if ([channelID isEqualToString:@"homepage_familiar"]) {
			isHideChannel = [defaults boolForKey:@"DYYYHideFriend"];
		} else if ([channelID isEqualToString:@"homepage_playlet_stream"]) {
			isHideChannel = [defaults boolForKey:@"DYYYHidePlaylet"];
		} else if ([channelID isEqualToString:@"homepage_pad_cinema"]) {
			isHideChannel = [defaults boolForKey:@"DYYYHideCinema"];
		} else if ([channelID isEqualToString:@"homepage_pad_kids_v2"]) {
			isHideChannel = [defaults boolForKey:@"DYYYHideKidsV2"];
		} else if ([channelID isEqualToString:@"homepage_pad_game"]) {
			isHideChannel = [defaults boolForKey:@"DYYYHideGame"];
		}
		if (oldChannelTitle.length > 0 || newChannelTitle.length > 0) {
			for (NSString *keyword in hideChannelKeywords) {
				if (keyword.length > 0 && ([oldChannelTitle containsString:keyword] || [newChannelTitle containsString:keyword])) {
					isHideChannel = YES;
				}
			}
		}
		if (!isHideChannel) {
			[newChannelModels addObject:tabItemModel];
		} else {
			[newCurrentChannelIDList removeObject:channelID];
		}
	}

	%orig(newChannelModels, newCurrentChannelIDList, arg3, arg4);
}

%end

%hook AWELandscapeFeedViewController
- (void)viewDidLoad {
	%orig;

	// 尝试优先走属性
	gFeedCV = self.collectionView;

	// 保险起见再fallback,遍历 subviews
	if (!gFeedCV) {
		gFeedCV = [DYYYUtils findSubviewOfClass:[UICollectionView class] inView:self.view];
	}
}
%end

%hook UICollectionView

// 拦截手指拖动
- (void)handlePan:(UIPanGestureRecognizer *)pan {

	/* 仅处理横屏Feed列表。其余collectionView直接走系统逻辑 */
	if (self != gFeedCV || !DYYYGetBool(@"DYYYVideoGesture")) {
		%orig;
		return;
	}

	/* 取触点坐标、手势状态 */
	CGPoint loc = [pan locationInView:self];
	CGFloat w = self.bounds.size.width;
	CGFloat xPct = loc.x / w; // 0.0 ~ 1.0
	UIGestureRecognizerState st = pan.state;

	/* BEGAN：判定左右 20 % 区域 → 进入亮度 / 音量模式 */
	if (st == UIGestureRecognizerStateBegan) {

		gStartY = loc.y;

		if (xPct <= 0.20) { // 左边缘 → 亮度
			gMode = DYEdgeModeBrightness;
			gStartVal = [UIScreen mainScreen].brightness;

		} else if (xPct >= 0.80) { // 右边缘 → 音量
			gMode = DYEdgeModeVolume;
			gStartVal = [[objc_getClass("AVSystemController") sharedAVSystemController] volumeForCategory:@"Audio/Video"];

		} else {
			gMode = DYEdgeModeNone; // 中间区域走原逻辑
		}
	}

	/* 调节阶段：左右边缘时吞掉滚动、修改亮度/音量 */
	if (gMode != DYEdgeModeNone) {

		if (st == UIGestureRecognizerStateChanged) {

			CGFloat delta = (gStartY - loc.y) / self.bounds.size.height; // ↑ 为正
			const CGFloat kScale = 2.0;				     // 灵敏度
			float newVal = gStartVal + delta * kScale;
			newVal = fminf(fmaxf(newVal, 0.0), 1.0); // Clamp 0~1

			if (gMode == DYEdgeModeBrightness) {
				[UIScreen mainScreen].brightness = newVal;
				// 弹系统亮度 HUD
				[[%c(SBHUDController) sharedInstance] presentHUDWithIcon:@"Brightness" level:newVal];

			} else { // DYEdgeModeVolume
				// iOS 18 音量控制 + 系统音量 HUD
				[[objc_getClass("AVSystemController") sharedAVSystemController] setVolumeTo:newVal forCategory:@"Audio/Video"];
			}

			// 吞掉滚动：归零 translation，防止内容位移
			[pan setTranslation:CGPointZero inView:self];
		}

		/* 结束／取消：状态复位 */
		if (st == UIGestureRecognizerStateEnded || st == UIGestureRecognizerStateCancelled || st == UIGestureRecognizerStateFailed) {
			gMode = DYEdgeModeNone;
		}

		return; // 左右边缘：彻底阻断 %orig，避免翻页
	}

	/* 中间区域：直接执行原先翻页逻辑 */
	%orig;
}

%end

%hook AWELeftSideBarAddChildTransitionObject

- (void)handleShowSliderPanGesture:(id)gr {
	if (DYYYGetBool(@"DYYYDisableSidebarGesture")) {
		return;
	}
	%orig(gr);
}

%end

%hook AWEPlayInteractionUserAvatarElement
- (void)onFollowViewClicked:(UITapGestureRecognizer *)gesture {
	if (DYYYGetBool(@"DYYYfollowTips")) {
		// 获取用户信息
		AWEUserModel *author = nil;
		NSString *nickname = @"";
		NSString *signature = @"";
		NSString *avatarURL = @"";

		if ([self respondsToSelector:@selector(model)]) {
			id model = [self model];
			if ([model isKindOfClass:NSClassFromString(@"AWEAwemeModel")]) {
				author = [model valueForKey:@"author"];
			}
		}

		if (author) {
			// 获取昵称
			if ([author respondsToSelector:@selector(nickname)]) {
				nickname = [author valueForKey:@"nickname"] ?: @"";
			}

			// 获取签名
			if ([author respondsToSelector:@selector(signature)]) {
				signature = [author valueForKey:@"signature"] ?: @"";
			}

			// 获取头像URL
			if ([author respondsToSelector:@selector(avatarThumb)]) {
				AWEURLModel *avatarThumb = [author valueForKey:@"avatarThumb"];
				if (avatarThumb && avatarThumb.originURLList.count > 0) {
					avatarURL = avatarThumb.originURLList.firstObject;
				}
			}
		}

		NSMutableString *messageContent = [NSMutableString string];
		if (signature.length > 0) {
			[messageContent appendFormat:@"%@", signature];
		}

		NSString *title = nickname.length > 0 ? nickname : @"关注确认";

		[DYYYBottomAlertView showAlertWithTitle:title
						message:messageContent
					      avatarURL:avatarURL
				       cancelButtonText:@"取消"
				      confirmButtonText:@"关注"
					   cancelAction:nil
					    closeAction:nil
					  confirmAction:^{
					    %orig(gesture);
					  }];
	} else {
		%orig;
	}
}

%end

%hook AWEPlayInteractionUserAvatarFollowController
- (void)onFollowViewClicked:(UITapGestureRecognizer *)gesture {
	if (DYYYGetBool(@"DYYYfollowTips")) {
		// 获取用户信息
		AWEUserModel *author = nil;
		NSString *nickname = @"";
		NSString *signature = @"";
		NSString *avatarURL = @"";

		if ([self respondsToSelector:@selector(model)]) {
			id model = [self model];
			if ([model isKindOfClass:NSClassFromString(@"AWEAwemeModel")]) {
				author = [model valueForKey:@"author"];
			}
		}

		if (author) {
			// 获取昵称
			if ([author respondsToSelector:@selector(nickname)]) {
				nickname = [author valueForKey:@"nickname"] ?: @"";
			}

			// 获取签名
			if ([author respondsToSelector:@selector(signature)]) {
				signature = [author valueForKey:@"signature"] ?: @"";
			}

			// 获取头像URL
			if ([author respondsToSelector:@selector(avatarThumb)]) {
				AWEURLModel *avatarThumb = [author valueForKey:@"avatarThumb"];
				if (avatarThumb && avatarThumb.originURLList.count > 0) {
					avatarURL = avatarThumb.originURLList.firstObject;
				}
			}
		}

		NSMutableString *messageContent = [NSMutableString string];
		if (signature.length > 0) {
			[messageContent appendFormat:@"%@", signature];
		}

		NSString *title = nickname.length > 0 ? nickname : @"关注确认";

		[DYYYBottomAlertView showAlertWithTitle:title
						message:messageContent
					      avatarURL:avatarURL
				       cancelButtonText:@"取消"
				      confirmButtonText:@"关注"
					   cancelAction:nil
					    closeAction:nil
					  confirmAction:^{
					    %orig(gesture);
					  }];
	} else {
		%orig;
	}
}

%end

%hook AWENormalModeTabBarGeneralPlusButton
+ (id)button {
	BOOL isHiddenJia = DYYYGetBool(@"DYYYisHiddenJia");
	if (isHiddenJia) {
		return nil;
	}
	return %orig;
}
%end

%hook AWEFeedContainerContentView
- (void)setAlpha:(CGFloat)alpha {
	// 纯净模式功能
	static dispatch_source_t timer = nil;
	static int attempts = 0;
	static BOOL pureModeSet = NO;
	if (DYYYGetBool(@"DYYYisEnablePure")) {
		%orig(0.0);
		if (pureModeSet) {
			return;
		}
		if (!timer) {
			timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
			dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC, 0);
			dispatch_source_set_event_handler(timer, ^{
			  UIWindow *keyWindow = [DYYYUtils getActiveWindow];
			  if (keyWindow && keyWindow.rootViewController) {
				  UIViewController *feedVC = [DYYYUtils findViewControllerOfClass:NSClassFromString(@"AWEFeedTableViewController") inViewController:keyWindow.rootViewController];
				  if (feedVC) {
					  [feedVC setValue:@YES forKey:@"pureMode"];
					  pureModeSet = YES;
					  dispatch_source_cancel(timer);
					  timer = nil;
					  attempts = 0;
					  return;
				  }
			  }
			  attempts++;
			  if (attempts >= 10) {
				  dispatch_source_cancel(timer);
				  timer = nil;
				  attempts = 0;
			  }
			});
			dispatch_resume(timer);
		}
		return;
	} else {
		if (timer) {
			dispatch_source_cancel(timer);
			timer = nil;
		}
		attempts = 0;
		pureModeSet = NO;
	}
	NSString *transparentValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYtopbartransparent"];
	if (transparentValue && transparentValue.length > 0) {
		CGFloat alphaValue = [transparentValue floatValue];
		if (alphaValue >= 0.0 && alphaValue <= 1.0) {
			CGFloat finalAlpha = (alphaValue < 0.011) ? 0.011 : alphaValue;
			%orig(finalAlpha);
		} else {
			%orig(1.0);
		}
	} else {
		%orig(1.0);
	}
}
%end

%hook AWEFeedTopBarContainer
- (void)layoutSubviews {
	%orig;
	applyTopBarTransparency(self);
}
- (void)didMoveToSuperview {
	%orig;
	applyTopBarTransparency(self);
}
- (void)setAlpha:(CGFloat)alpha {
	NSString *transparentValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYtopbartransparent"];
	if (transparentValue && transparentValue.length > 0) {
		CGFloat alphaValue = [transparentValue floatValue];
		if (alphaValue >= 0.0 && alphaValue <= 1.0) {
			CGFloat finalAlpha = (alphaValue < 0.011) ? 0.011 : alphaValue;
			%orig(finalAlpha);
		} else {
			%orig(1.0);
		}
	} else {
		%orig(1.0);
	}
}
%end

// 设置修改顶栏标题
%hook AWEHPTopTabItemTextContentView

- (void)layoutSubviews {
	%orig;

	NSString *topTitleConfig = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYModifyTopTabText"];
	if (topTitleConfig.length == 0)
		return;

	NSArray *titlePairs = [topTitleConfig componentsSeparatedByString:@"#"];

	NSString *accessibilityLabel = nil;
	if ([self.superview respondsToSelector:@selector(accessibilityLabel)]) {
		accessibilityLabel = self.superview.accessibilityLabel;
	}
	if (accessibilityLabel.length == 0)
		return;

	for (NSString *pair in titlePairs) {
		NSArray *components = [pair componentsSeparatedByString:@"="];
		if (components.count != 2)
			continue;

		NSString *originalTitle = components[0];
		NSString *newTitle = components[1];

		if ([accessibilityLabel isEqualToString:originalTitle]) {
			if ([self respondsToSelector:@selector(setContentText:)]) {
				[self setContentText:newTitle];
			} else {
				[self setValue:newTitle forKey:@"contentText"];
			}
			break;
		}
	}
}

%end

%hook AWEDanmakuContentLabel
- (void)setTextColor:(UIColor *)textColor {
	if (DYYYGetBool(@"DYYYEnableDanmuColor")) {
		NSString *danmuColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYdanmuColor"];
		if (DYYYGetBool(@"DYYYDanmuRainbowRotating")) {
			danmuColor = @"rainbow_rotating";
		}
		[DYYYUtils applyColorSettingsToLabel:self colorHexString:danmuColor];
	} else {
		%orig(textColor);
	}
}

- (void)setStrokeWidth:(double)strokeWidth {
	if (DYYYGetBool(@"DYYYEnableDanmuColor")) {
		%orig(FLT_MIN);
	} else {
		%orig(strokeWidth);
	}
}

- (void)setStrokeColor:(UIColor *)strokeColor {
	if (DYYYGetBool(@"DYYYEnableDanmuColor")) {
		%orig(nil);
	} else {
		%orig(strokeColor);
	}
}

%end

%hook XIGDanmakuPlayerView

- (id)initWithFrame:(CGRect)frame {
	id orig = %orig;

	((UIView *)orig).tag = DYYY_IGNORE_GLOBAL_ALPHA_TAG;

	return orig;
}

- (void)setAlpha:(CGFloat)alpha {
	if (DYYYGetBool(@"DYYYCommentShowDanmaku") && alpha == 0.0) {
		return;
	} else {
		%orig(alpha);
	}
}

%end

%hook DDanmakuPlayerView

- (void)setAlpha:(CGFloat)alpha {
	if (DYYYGetBool(@"DYYYCommentShowDanmaku") && alpha == 0.0) {
		return;
	} else {
		%orig(alpha);
	}
}

%end

%hook AWEMarkView

- (void)layoutSubviews {
	%orig;

	UIViewController *vc = [DYYYUtils firstAvailableViewControllerFromView:self];

	if ([vc isKindOfClass:%c(AWEPlayInteractionViewController)]) {
		if (self.markLabel) {
			self.markLabel.textColor = [UIColor whiteColor];
		}
	}

	if (DYYYGetBool(@"DYYYHideLocation")) {
		self.hidden = YES;
		return;
	}
}

%end

%group DYYYSettingsGesture

%hook UIWindow
- (instancetype)initWithFrame:(CGRect)frame {
	UIWindow *window = %orig(frame);
	if (window) {
		UILongPressGestureRecognizer *doubleFingerLongPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleFingerLongPressGesture:)];
		doubleFingerLongPressGesture.numberOfTouchesRequired = 2;
		[window addGestureRecognizer:doubleFingerLongPressGesture];
	}
	return window;
}

%new
- (void)handleDoubleFingerLongPressGesture:(UILongPressGestureRecognizer *)gesture {
	if (gesture.state == UIGestureRecognizerStateBegan) {
		UIViewController *rootViewController = self.rootViewController;
		if (rootViewController) {
			UIViewController *settingVC = [[DYYYSettingViewController alloc] init];

			if (settingVC) {
				BOOL isIPad = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
				if (@available(iOS 15.0, *)) {
					if (!isIPad) {
						settingVC.modalPresentationStyle = UIModalPresentationPageSheet;
					} else {
						settingVC.modalPresentationStyle = UIModalPresentationFullScreen;
					}
				} else {
					settingVC.modalPresentationStyle = UIModalPresentationFullScreen;
				}

				if (settingVC.modalPresentationStyle == UIModalPresentationFullScreen) {
					UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
					[closeButton setTitle:@"关闭" forState:UIControlStateNormal];
					closeButton.translatesAutoresizingMaskIntoConstraints = NO;

					[settingVC.view addSubview:closeButton];

					[NSLayoutConstraint activateConstraints:@[
						[closeButton.trailingAnchor constraintEqualToAnchor:settingVC.view.trailingAnchor constant:-10],
						[closeButton.topAnchor constraintEqualToAnchor:settingVC.view.topAnchor constant:40], [closeButton.widthAnchor constraintEqualToConstant:80],
						[closeButton.heightAnchor constraintEqualToConstant:40]
					]];

					[closeButton addTarget:self action:@selector(closeSettings:) forControlEvents:UIControlEventTouchUpInside];
				}

				UIView *handleBar = [[UIView alloc] init];
				handleBar.backgroundColor = [UIColor whiteColor];
				handleBar.layer.cornerRadius = 2.5;
				handleBar.translatesAutoresizingMaskIntoConstraints = NO;
				[settingVC.view addSubview:handleBar];

				[NSLayoutConstraint activateConstraints:@[
					[handleBar.centerXAnchor constraintEqualToAnchor:settingVC.view.centerXAnchor],
					[handleBar.topAnchor constraintEqualToAnchor:settingVC.view.topAnchor constant:8], [handleBar.widthAnchor constraintEqualToConstant:40],
					[handleBar.heightAnchor constraintEqualToConstant:5]
				]];

				[rootViewController presentViewController:settingVC animated:YES completion:nil];
			}
		}
	}
}

%new
- (void)closeSettings:(UIButton *)button {
	[button.superview.window.rootViewController dismissViewControllerAnimated:YES completion:nil];
}
%end

%end

%hook AWEBaseListViewController
- (void)viewDidLayoutSubviews {
	%orig;
	[self applyBlurEffectIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated {
	%orig;
	[self applyBlurEffectIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated {
	%orig;
	[self applyBlurEffectIfNeeded];
}

%new
- (void)applyBlurEffectIfNeeded {
	if (DYYYGetBool(@"DYYYisEnableCommentBlur") && [self isKindOfClass:NSClassFromString(@"AWECommentPanelContainerSwiftImpl.CommentContainerInnerViewController")]) {
		// 动态获取用户设置的透明度
		float userTransparency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCommentBlurTransparent"] floatValue];
		if (userTransparency <= 0 || userTransparency > 1) {
			userTransparency = 0.9;
		}

		// 应用毛玻璃效果
		[DYYYUtils applyBlurEffectToView:self.view transparency:userTransparency blurViewTag:999];

		// 递归清除所有子视图的背景色，防止遮挡模糊效果
		[DYYYUtils clearBackgroundRecursivelyInView:self.view];
	}
}
%end

%hook UIView
// 关键方法,勿删！
%new
- (UIViewController *)firstAvailableUIViewController {
	return [DYYYUtils firstAvailableViewControllerFromView:self];
}

%end

// 重写全局透明方法
%hook AWEPlayInteractionViewController

- (UIView *)view {
	UIView *originalView = %orig;

	NSString *transparentValue = DYYYGetString(@"DYYYGlobalTransparency");
	if (transparentValue.length > 0) {
		CGFloat alphaValue = transparentValue.floatValue;
		if (alphaValue >= 0.0 && alphaValue <= 1.0) {
			for (UIView *subview in originalView.subviews) {
				if (subview.tag != DYYY_IGNORE_GLOBAL_ALPHA_TAG) {
					if (subview.alpha > 0) {
						subview.alpha = alphaValue;
					}
				}
			}
		}
	}

	return originalView;
}

%end

%hook AWEAwemeDetailNaviBarContainerView

- (void)layoutSubviews {
	%orig;

	NSString *transparentValue = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYGlobalTransparency"];
	if (!transparentValue.length)
		return;

	CGFloat alphaValue = transparentValue.floatValue;
	if (alphaValue < 0.0 || alphaValue > 1.0)
		return;

	if ([NSStringFromClass([self.superview class]) isEqualToString:NSStringFromClass([self class])])
		return;

	static char kDYYNaviAlphaCacheKey;
	NSArray *alphaViews = objc_getAssociatedObject(self, &kDYYNaviAlphaCacheKey);
	if (!alphaViews) {
		NSMutableArray *tmp = [NSMutableArray array];
		for (UIView *subview in self.subviews) {
			if (subview.tag != DYYY_IGNORE_GLOBAL_ALPHA_TAG && subview.superview == self && subview.alpha > 0) {
				[tmp addObject:subview];
			}
		}
		alphaViews = [tmp copy];
		objc_setAssociatedObject(self, &kDYYNaviAlphaCacheKey, alphaViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	for (UIView *v in alphaViews) {
		v.alpha = alphaValue;
	}
}

%end

%hook AWEFeedVideoButton
- (id)touchUpInsideBlock {
	id r = %orig;

	// 只有收藏按钮才显示确认弹窗
	if (DYYYGetBool(@"DYYYcollectTips") && [self.accessibilityLabel isEqualToString:@"收藏"]) {

		dispatch_async(dispatch_get_main_queue(), ^{
		  [DYYYBottomAlertView showAlertWithTitle:@"收藏确认"
						  message:@"是否确认/取消收藏？"
						avatarURL:nil
					 cancelButtonText:nil
					confirmButtonText:nil
					     cancelAction:nil
					      closeAction:nil
					    confirmAction:^{
					      if (r && [r isKindOfClass:NSClassFromString(@"NSBlock")]) {
						      ((void (^)(void))r)();
					      }
					    }];
		});

		return nil; // 阻止原始 block 立即执行
	}

	return r;
}
%end

%hook AWEPlayInteractionProgressContainerView
- (void)layoutSubviews {
	%orig;

	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"]) {
		return;
	}

	static char kDYProgressBgKey;
	NSArray *bgViews = objc_getAssociatedObject(self, &kDYProgressBgKey);
	if (!bgViews) {
		NSMutableArray *tmp = [NSMutableArray array];
		for (UIView *subview in self.subviews) {
			if ([subview class] == [UIView class]) {
				[tmp addObject:subview];
			}
		}
		bgViews = [tmp copy];
		objc_setAssociatedObject(self, &kDYProgressBgKey, bgViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	for (UIView *v in bgViews) {
		v.backgroundColor = [UIColor clearColor];
	}
}

%end

%hook AWEFeedProgressSlider

// layoutSubviews 保持不变
- (void)layoutSubviews {
	%orig;
}

- (void)setAlpha:(CGFloat)alpha {
	if (DYYYGetBool(@"DYYYisShowScheduleDisplay")) {
		if (DYYYGetBool(@"DYYYHideVideoProgress")) {
			%orig(0);
		} else {
			%orig(1.0);
		}
	} else {
		%orig;
	}
}

static CGFloat leftLabelLeftMargin = -1;
static CGFloat rightLabelRightMargin = -1;

- (void)setLimitUpperActionArea:(BOOL)arg1 {
	%orig;

	NSString *durationFormatted = [self.progressSliderDelegate formatTimeFromSeconds:floor(self.progressSliderDelegate.model.videoDuration / 1000)];

	if (DYYYGetBool(@"DYYYisShowScheduleDisplay")) {
		UIView *parentView = self.superview;
		if (!parentView)
			return;

		[[parentView viewWithTag:10001] removeFromSuperview];
		[[parentView viewWithTag:10002] removeFromSuperview];

		CGRect sliderOriginalFrameInParent = [self convertRect:self.bounds toView:parentView];
		CGRect sliderFrame = self.frame;

		CGFloat verticalOffset = -12.5;
		NSString *offsetValueString = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimelineVerticalPosition"];
		if (offsetValueString.length > 0) {
			CGFloat configOffset = [offsetValueString floatValue];
			if (configOffset != 0)
				verticalOffset = configOffset;
		}

		NSString *scheduleStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYScheduleStyle"];
		BOOL showRemainingTime = [scheduleStyle isEqualToString:@"进度条右侧剩余"];
		BOOL showCompleteTime = [scheduleStyle isEqualToString:@"进度条右侧完整"];
		BOOL showLeftRemainingTime = [scheduleStyle isEqualToString:@"进度条左侧剩余"];
		BOOL showLeftCompleteTime = [scheduleStyle isEqualToString:@"进度条左侧完整"];

		NSString *labelColorHex = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYProgressLabelColor"];

		CGFloat labelYPosition = sliderOriginalFrameInParent.origin.y + verticalOffset;
		CGFloat labelHeight = 15.0;
		UIFont *labelFont = [UIFont systemFontOfSize:8];

		if (!showRemainingTime && !showCompleteTime) {
			UILabel *leftLabel = [[UILabel alloc] init];
			leftLabel.backgroundColor = [UIColor clearColor];
			leftLabel.font = labelFont;
			leftLabel.tag = 10001;
			if (showLeftRemainingTime)
				leftLabel.text = @"00:00";
			else if (showLeftCompleteTime)
				leftLabel.text = [NSString stringWithFormat:@"00:00/%@", durationFormatted];
			else
				leftLabel.text = @"00:00";

			[leftLabel sizeToFit];

			if (leftLabelLeftMargin == -1) {
				leftLabelLeftMargin = sliderFrame.origin.x;
			}

			leftLabel.frame = CGRectMake(leftLabelLeftMargin, labelYPosition, leftLabel.frame.size.width, labelHeight);
			[parentView addSubview:leftLabel];

			[DYYYUtils applyColorSettingsToLabel:leftLabel colorHexString:labelColorHex];
		}

		if (!showLeftRemainingTime && !showLeftCompleteTime) {
			UILabel *rightLabel = [[UILabel alloc] init];
			rightLabel.backgroundColor = [UIColor clearColor];
			rightLabel.font = labelFont;
			rightLabel.tag = 10002;
			if (showRemainingTime)
				rightLabel.text = @"00:00";
			else if (showCompleteTime)
				rightLabel.text = [NSString stringWithFormat:@"00:00/%@", durationFormatted];
			else
				rightLabel.text = durationFormatted;

			[rightLabel sizeToFit];

			if (rightLabelRightMargin == -1) {
				rightLabelRightMargin = sliderFrame.origin.x + sliderFrame.size.width - rightLabel.frame.size.width;
			}

			rightLabel.frame = CGRectMake(rightLabelRightMargin, labelYPosition, rightLabel.frame.size.width, labelHeight);
			[parentView addSubview:rightLabel];

			[DYYYUtils applyColorSettingsToLabel:rightLabel colorHexString:labelColorHex];
		}

		[self setNeedsLayout];
	} else {
		UIView *parentView = self.superview;
		if (parentView) {
			[[parentView viewWithTag:10001] removeFromSuperview];
			[[parentView viewWithTag:10002] removeFromSuperview];
		}
		[self setNeedsLayout];
	}
}

%end

%hook AWEPlayInteractionProgressController

%new
- (NSString *)formatTimeFromSeconds:(CGFloat)seconds {
	NSInteger hours = (NSInteger)seconds / 3600;
	NSInteger minutes = ((NSInteger)seconds % 3600) / 60;
	NSInteger secs = (NSInteger)seconds % 60;

	if (hours > 0) {
		return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)secs];
	} else {
		return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)secs];
	}
}

- (void)updateProgressSliderWithTime:(CGFloat)arg1 totalDuration:(CGFloat)arg2 {
	%orig;

	if (DYYYGetBool(@"DYYYisShowScheduleDisplay")) {
		AWEFeedProgressSlider *progressSlider = self.progressSlider;
		UIView *parentView = progressSlider.superview;
		if (!parentView)
			return;

		UILabel *leftLabel = [parentView viewWithTag:10001];
		UILabel *rightLabel = [parentView viewWithTag:10002];

		NSString *labelColorHex = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYProgressLabelColor"];

		NSString *scheduleStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYScheduleStyle"];
		BOOL showRemainingTime = [scheduleStyle isEqualToString:@"进度条右侧剩余"];
		BOOL showCompleteTime = [scheduleStyle isEqualToString:@"进度条右侧完整"];
		BOOL showLeftRemainingTime = [scheduleStyle isEqualToString:@"进度条左侧剩余"];
		BOOL showLeftCompleteTime = [scheduleStyle isEqualToString:@"进度条左侧完整"];

		// 更新左标签
		if (arg1 >= 0 && leftLabel) {
			NSString *newLeftText = @"";
			if (showLeftRemainingTime) {
				CGFloat remainingTime = arg2 - arg1;
				if (remainingTime < 0)
					remainingTime = 0;
				newLeftText = [self formatTimeFromSeconds:remainingTime];
			} else if (showLeftCompleteTime) {
				newLeftText = [NSString stringWithFormat:@"%@/%@", [self formatTimeFromSeconds:arg1], [self formatTimeFromSeconds:arg2]];
			} else {
				newLeftText = [self formatTimeFromSeconds:arg1];
			}

			if (![leftLabel.text isEqualToString:newLeftText]) {
				leftLabel.text = newLeftText;
				[leftLabel sizeToFit];
				CGRect leftFrame = leftLabel.frame;
				leftFrame.size.height = 15.0;
				leftLabel.frame = leftFrame;
			}
			[DYYYUtils applyColorSettingsToLabel:leftLabel colorHexString:labelColorHex];
		}

		// 更新右标签
		if (arg2 > 0 && rightLabel) {
			NSString *newRightText = @"";
			if (showRemainingTime) {
				CGFloat remainingTime = arg2 - arg1;
				if (remainingTime < 0)
					remainingTime = 0;
				newRightText = [self formatTimeFromSeconds:remainingTime];
			} else if (showCompleteTime) {
				newRightText = [NSString stringWithFormat:@"%@/%@", [self formatTimeFromSeconds:arg1], [self formatTimeFromSeconds:arg2]];
			} else {
				newRightText = [self formatTimeFromSeconds:arg2];
			}

			if (![rightLabel.text isEqualToString:newRightText]) {
				rightLabel.text = newRightText;
				[rightLabel sizeToFit];
				CGRect rightFrame = rightLabel.frame;
				rightFrame.size.height = 15.0;
				rightLabel.frame = rightFrame;
			}
			[DYYYUtils applyColorSettingsToLabel:rightLabel colorHexString:labelColorHex];
		}
	}
}

- (void)setHidden:(BOOL)hidden {
	%orig;
	BOOL hideVideoProgress = DYYYGetBool(@"DYYYHideVideoProgress");
	BOOL showScheduleDisplay = DYYYGetBool(@"DYYYisShowScheduleDisplay");
	if (hideVideoProgress && showScheduleDisplay && !hidden) {
		self.alpha = 0;
	}
}

%end
%hook AWENormalModeTabBarTextView

- (void)layoutSubviews {
	%orig;

	NSString *indexTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYIndexTitle"];
	NSString *friendsTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFriendsTitle"];
	NSString *msgTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYMsgTitle"];
	NSString *selfTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYSelfTitle"];

	if (!(indexTitle.length || friendsTitle.length || msgTitle.length || selfTitle.length)) {
		return;
	}

	static char kDYTabLabelCacheKey;
	NSArray *labelCache = objc_getAssociatedObject(self, &kDYTabLabelCacheKey);
	if (!labelCache) {
		NSMutableArray *tmp = [NSMutableArray array];
		for (UIView *subview in [self subviews]) {
			if ([subview isKindOfClass:[UILabel class]]) {
				[tmp addObject:subview];
			}
		}
		labelCache = [tmp copy];
		objc_setAssociatedObject(self, &kDYTabLabelCacheKey, labelCache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	for (UILabel *label in labelCache) {
		if ([label.text isEqualToString:@"首页"] && indexTitle.length > 0) {
			label.text = indexTitle;
			[self setNeedsLayout];
		} else if ([label.text isEqualToString:@"朋友"] && friendsTitle.length > 0) {
			label.text = friendsTitle;
			[self setNeedsLayout];
		} else if ([label.text isEqualToString:@"消息"] && msgTitle.length > 0) {
			label.text = msgTitle;
			[self setNeedsLayout];
		} else if ([label.text isEqualToString:@"我"] && selfTitle.length > 0) {
			label.text = selfTitle;
			[self setNeedsLayout];
		}
	}
}
%end
%hook AWEPlayInteractionTimestampElement

- (id)timestampLabel {
	UILabel *label = %orig;
	NSString *labelColorHex = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYLabelColor"];
	if (DYYYGetBool(@"DYYYEnabsuijiyanse")) {
		labelColorHex = @"random_gradient";
	}
	if (DYYYGetBool(@"DYYYisEnableArea")) {
		NSString *originalText = label.text ?: @"";
		NSString *cityCode = self.model.cityCode;

		if (cityCode.length > 0) {
			NSString *cityName = [CityManager.sharedInstance getCityNameWithCode:cityCode];
			NSString *provinceName = [CityManager.sharedInstance getProvinceNameWithCode:cityCode];
			// 使用 GeoNames API
			if (!cityName || cityName.length == 0) {
				NSString *cacheKey = cityCode;

				static NSCache *geoNamesCache = nil;
				static dispatch_once_t onceToken;
				dispatch_once(&onceToken, ^{
				  geoNamesCache = [[NSCache alloc] init];
				  geoNamesCache.name = @"com.dyyy.geonames.cache";
				  geoNamesCache.countLimit = 1000;
				});

				NSDictionary *cachedData = [geoNamesCache objectForKey:cacheKey];

				if (!cachedData) {
					NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
					NSString *geoNamesCacheDir = [cachesDir stringByAppendingPathComponent:@"DYYYGeoNamesCache"];

					NSFileManager *fileManager = [NSFileManager defaultManager];
					if (![fileManager fileExistsAtPath:geoNamesCacheDir]) {
						[fileManager createDirectoryAtPath:geoNamesCacheDir withIntermediateDirectories:YES attributes:nil error:nil];
					}

					NSString *cacheFilePath = [geoNamesCacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", cacheKey]];

					if ([fileManager fileExistsAtPath:cacheFilePath]) {
						cachedData = [NSDictionary dictionaryWithContentsOfFile:cacheFilePath];
						if (cachedData) {
							[geoNamesCache setObject:cachedData forKey:cacheKey];
						}
					}
				}

				if (cachedData) {
					NSString *countryName = cachedData[@"countryName"];
					NSString *adminName1 = cachedData[@"adminName1"];
					NSString *localName = cachedData[@"name"];
					NSString *displayLocation = @"未知";

					if (countryName.length > 0) {
						if (adminName1.length > 0 && localName.length > 0 && ![countryName isEqualToString:@"中国"] && ![countryName isEqualToString:localName]) {
							// 国外位置：国家 + 州/省 + 地点
							displayLocation = [NSString stringWithFormat:@"%@ %@ %@", countryName, adminName1, localName];
						} else if (localName.length > 0 && ![countryName isEqualToString:localName]) {
							// 只有国家和地点名
							displayLocation = [NSString stringWithFormat:@"%@ %@", countryName, localName];
						} else {
							// 只有国家名
							displayLocation = countryName;
						}
					} else if (localName.length > 0) {
						displayLocation = localName;
					}

					dispatch_async(dispatch_get_main_queue(), ^{
					  NSString *currentLabelText = label.text ?: @"";
					  if ([currentLabelText containsString:@"IP属地："]) {
						  NSRange range = [currentLabelText rangeOfString:@"IP属地："];
						  if (range.location != NSNotFound) {
							  NSString *baseText = [currentLabelText substringToIndex:range.location];
							  if (![currentLabelText containsString:displayLocation]) {
								  label.text = [NSString stringWithFormat:@"%@IP属地：%@", baseText, displayLocation];
							  }
						  }
					  } else {
						  if (currentLabelText.length > 0 && ![displayLocation isEqualToString:@"未知"]) {
							  label.text = [NSString stringWithFormat:@"%@  IP属地：%@", currentLabelText, displayLocation];
						  } else if (![displayLocation isEqualToString:@"未知"]) {
							  label.text = [NSString stringWithFormat:@"IP属地：%@", displayLocation];
						  }
					  }

					  [DYYYUtils applyColorSettingsToLabel:label colorHexString:labelColorHex];
					});
				} else {
					[CityManager
					    fetchLocationWithGeonameId:cityCode
						     completionHandler:^(NSDictionary *locationInfo, NSError *error) {
						       if (locationInfo) {
							       NSString *countryName = locationInfo[@"countryName"];
							       NSString *adminName1 = locationInfo[@"adminName1"]; // 州/省级名称
							       NSString *localName = locationInfo[@"name"];	   // 当前地点名称
							       NSString *displayLocation = @"未知";

							       // 根据返回数据构建位置显示文本
							       if (countryName.length > 0) {
								       if (adminName1.length > 0 && localName.length > 0 && ![countryName isEqualToString:@"中国"] &&
									   ![countryName isEqualToString:localName]) {
									       // 国外位置：国家 + 州/省 + 地点
									       displayLocation = [NSString stringWithFormat:@"%@ %@ %@", countryName, adminName1, localName];
								       } else if (localName.length > 0 && ![countryName isEqualToString:localName]) {
									       // 只有国家和地点名
									       displayLocation = [NSString stringWithFormat:@"%@ %@", countryName, localName];
								       } else {
									       // 只有国家名
									       displayLocation = countryName;
								       }
							       } else if (localName.length > 0) {
								       displayLocation = localName;
							       }

							       // 修改：仅当位置不为"未知"时才缓存
							       if (![displayLocation isEqualToString:@"未知"]) {
								       [geoNamesCache setObject:locationInfo forKey:cacheKey];

								       NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
								       NSString *geoNamesCacheDir = [cachesDir stringByAppendingPathComponent:@"DYYYGeoNamesCache"];
								       NSString *cacheFilePath = [geoNamesCacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", cacheKey]];

								       [locationInfo writeToFile:cacheFilePath atomically:YES];
							       }

							       dispatch_async(dispatch_get_main_queue(), ^{
								 NSString *currentLabelText = label.text ?: @"";

								 if ([currentLabelText containsString:@"IP属地："]) {
									 NSRange range = [currentLabelText rangeOfString:@"IP属地："];
									 if (range.location != NSNotFound) {
										 NSString *baseText = [currentLabelText substringToIndex:range.location];
										 if (![currentLabelText containsString:displayLocation]) {
											 label.text = [NSString stringWithFormat:@"%@IP属地：%@", baseText, displayLocation];
										 }
									 }
								 } else {
									 if (currentLabelText.length > 0 && ![displayLocation isEqualToString:@"未知"]) {
										 label.text = [NSString stringWithFormat:@"%@  IP属地：%@", currentLabelText, displayLocation];
									 } else if (![displayLocation isEqualToString:@"未知"]) {
										 label.text = [NSString stringWithFormat:@"IP属地：%@", displayLocation];
									 }
								 }

								 [DYYYUtils applyColorSettingsToLabel:label colorHexString:labelColorHex];
							       });
						       }
						     }];
				}
			} else if (![originalText containsString:cityName]) {
				BOOL isDirectCity = [provinceName isEqualToString:cityName] ||
						    ([cityCode hasPrefix:@"11"] || [cityCode hasPrefix:@"12"] || [cityCode hasPrefix:@"31"] || [cityCode hasPrefix:@"50"]);
				if (!self.model.ipAttribution) {
					if (isDirectCity) {
						label.text = [NSString stringWithFormat:@"%@  IP属地：%@", originalText, cityName];
					} else {
						label.text = [NSString stringWithFormat:@"%@  IP属地：%@ %@", originalText, provinceName, cityName];
					}
				} else {
					BOOL containsProvince = [originalText containsString:provinceName];
					BOOL containsCity = [originalText containsString:cityName];
					if (containsProvince && !isDirectCity && !containsCity) {
						label.text = [NSString stringWithFormat:@"%@ %@", originalText, cityName];
					} else if (isDirectCity && !containsCity) {
						label.text = [NSString stringWithFormat:@"%@  IP属地：%@", originalText, cityName];
					}
				}
			}
		}
	}
	// 应用IP属地标签上移
	NSString *ipScaleValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYNicknameScale"];
	if (ipScaleValue.length > 0) {
		UIFont *originalFont = label.font;
		CGRect originalFrame = label.frame;
		CGFloat offset = DYYYGetFloat(@"DYYYIPLabelVerticalOffset");
		if (offset > 0) {
			CGAffineTransform translationTransform = CGAffineTransformMakeTranslation(0, -offset);
			label.transform = translationTransform;
		} else {
			CGAffineTransform translationTransform = CGAffineTransformMakeTranslation(0, -3);
			label.transform = translationTransform;
		}

		label.font = originalFont;
	}

	[DYYYUtils applyColorSettingsToLabel:label colorHexString:labelColorHex];

	return label;
}

+ (BOOL)shouldActiveWithData:(id)arg1 context:(id)arg2 {
	return DYYYGetBool(@"DYYYisEnableArea");
}

%end

%hook AWEPlayInteractionDescriptionScrollView

- (void)layoutSubviews {
	%orig;

	self.transform = CGAffineTransformIdentity;

	NSString *descriptionOffsetValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDescriptionVerticalOffset"];
	CGFloat verticalOffset = 0;
	if (descriptionOffsetValue.length > 0) {
		verticalOffset = [descriptionOffsetValue floatValue];
	}

	UIView *parentView = self.superview;
	UIView *grandParentView = nil;

	if (parentView) {
		grandParentView = parentView.superview;
	}

	if (grandParentView && verticalOffset != 0) {
		CGAffineTransform translationTransform = CGAffineTransformMakeTranslation(0, verticalOffset);
		grandParentView.transform = translationTransform;
	}
}

%end

// 对新版文案的偏移（33.0以上）
%hook AWEPlayInteractionDescriptionLabel

static char kLongPressGestureKey;
static NSString *const kDYYYLongPressCopyEnabledKey = @"DYYYLongPressCopyTextEnabled";

- (void)didMoveToWindow {
	%orig;

	BOOL longPressCopyEnabled = DYYYGetBool(kDYYYLongPressCopyEnabledKey);

	if (![[NSUserDefaults standardUserDefaults] objectForKey:kDYYYLongPressCopyEnabledKey]) {
		longPressCopyEnabled = NO;
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kDYYYLongPressCopyEnabledKey];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}

	UIGestureRecognizer *existingGesture = objc_getAssociatedObject(self, &kLongPressGestureKey);
	if (existingGesture && !longPressCopyEnabled) {
		[self removeGestureRecognizer:existingGesture];
		objc_setAssociatedObject(self, &kLongPressGestureKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		return;
	}

	if (longPressCopyEnabled && !objc_getAssociatedObject(self, &kLongPressGestureKey)) {
		UILongPressGestureRecognizer *highPriorityLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleHighPriorityLongPress:)];
		highPriorityLongPress.minimumPressDuration = 0.3;

		[self addGestureRecognizer:highPriorityLongPress];

		UIView *currentView = self;
		while (currentView.superview) {
			currentView = currentView.superview;

			for (UIGestureRecognizer *recognizer in currentView.gestureRecognizers) {
				if ([recognizer isKindOfClass:[UILongPressGestureRecognizer class]] || [recognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
					[recognizer requireGestureRecognizerToFail:highPriorityLongPress];
				}
			}
		}

		objc_setAssociatedObject(self, &kLongPressGestureKey, highPriorityLongPress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
	if ([gestureRecognizer.view isEqual:self] && [gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
		return NO;
	}
	return YES;
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
	if ([gestureRecognizer.view isEqual:self] && [gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
		return YES;
	}
	return NO;
}

%new
- (void)handleHighPriorityLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
	if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {

		NSString *description = self.text;

		if (description.length > 0) {
			[[UIPasteboard generalPasteboard] setString:description];
			[DYYYToast showSuccessToastWithMessage:@"视频文案已复制"];
		}
	}
}

- (void)layoutSubviews {
	%orig;
	self.transform = CGAffineTransformIdentity;

	NSString *descriptionOffsetValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDescriptionVerticalOffset"];
	CGFloat verticalOffset = 0;
	if (descriptionOffsetValue.length > 0) {
		verticalOffset = [descriptionOffsetValue floatValue];
	}

	UIView *parentView = self.superview;
	UIView *grandParentView = nil;

	if (parentView) {
		grandParentView = parentView.superview;
	}

	if (grandParentView && verticalOffset != 0) {
		CGAffineTransform translationTransform = CGAffineTransformMakeTranslation(0, verticalOffset);
		grandParentView.transform = translationTransform;
	}
}

%end

%hook AWEUserNameLabel

- (void)layoutSubviews {
	%orig;

	self.transform = CGAffineTransformIdentity;

	// 添加垂直偏移支持
	NSString *verticalOffsetValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYNicknameVerticalOffset"];
	CGFloat verticalOffset = 0;
	if (verticalOffsetValue.length > 0) {
		verticalOffset = [verticalOffsetValue floatValue];
	}

	UIView *parentView = self.superview;
	UIView *grandParentView = nil;

	if (parentView) {
		grandParentView = parentView.superview;
	}

	// 检查祖父视图是否为 AWEBaseElementView 类型
	if (grandParentView && [grandParentView.superview isKindOfClass:%c(AWEBaseElementView)]) {
		CGRect scaledFrame = grandParentView.frame;
		CGFloat translationX = -scaledFrame.origin.x;

		CGAffineTransform translationTransform = CGAffineTransformMakeTranslation(translationX, verticalOffset);
		grandParentView.transform = translationTransform;
	}
}

%end

%hook AWEFeedVideoButton

- (void)setImage:(id)arg1 {
	NSString *nameString = nil;

	if ([self respondsToSelector:@selector(imageNameString)]) {
		nameString = [self performSelector:@selector(imageNameString)];
	}

	if (!nameString) {
		%orig;
		return;
	}

	NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
	NSString *dyyyFolderPath = [documentsPath stringByAppendingPathComponent:@"DYYY"];

	[[NSFileManager defaultManager] createDirectoryAtPath:dyyyFolderPath withIntermediateDirectories:YES attributes:nil error:nil];

	NSDictionary *iconMapping = @{
		@"icon_home_like_after" : @"like_after.png",
		@"icon_home_like_before" : @"like_before.png",
		@"icon_home_comment" : @"comment.png",
		@"icon_home_unfavorite" : @"unfavorite.png",
		@"icon_home_favorite" : @"favorite.png",
		@"iconHomeShareRight" : @"share.png"
	};

	NSString *customFileName = nil;
	if ([nameString containsString:@"_comment"]) {
		customFileName = @"comment.png";
	} else if ([nameString containsString:@"_like"]) {
		customFileName = @"like_before.png";
	} else if ([nameString containsString:@"_collect"]) {
		customFileName = @"unfavorite.png";
	} else if ([nameString containsString:@"_share"]) {
		customFileName = @"share.png";
	}

	for (NSString *prefix in iconMapping.allKeys) {
		if ([nameString hasPrefix:prefix]) {
			customFileName = iconMapping[prefix];
			break;
		}
	}

	if (customFileName) {
		NSString *customImagePath = [dyyyFolderPath stringByAppendingPathComponent:customFileName];

		if ([[NSFileManager defaultManager] fileExistsAtPath:customImagePath]) {
			UIImage *customImage = [UIImage imageWithContentsOfFile:customImagePath];
			if (customImage) {
				CGFloat targetWidth = 44.0;
				CGFloat targetHeight = 44.0;
				CGSize originalSize = customImage.size;

				CGFloat scale = MIN(targetWidth / originalSize.width, targetHeight / originalSize.height);
				CGFloat newWidth = originalSize.width * scale;
				CGFloat newHeight = originalSize.height * scale;

				UIGraphicsBeginImageContextWithOptions(CGSizeMake(newWidth, newHeight), NO, 0.0);
				[customImage drawInRect:CGRectMake(0, 0, newWidth, newHeight)];
				UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
				UIGraphicsEndImageContext();

				if (resizedImage) {
					%orig(resizedImage);
					return;
				}
			}
		}
	}

	%orig;
}

%end

// 获取资源的地址
%hook AWEURLModel
%new - (NSURL *)getDYYYSrcURLDownload {
	NSURL *bestURL;
	for (NSString *url in self.originURLList) {
		if ([url containsString:@"video_mp4"] || [url containsString:@".jpeg"] || [url containsString:@".mp3"]) {
			bestURL = [NSURL URLWithString:url];
		}
	}

	if (bestURL == nil) {
		bestURL = [NSURL URLWithString:[self.originURLList firstObject]];
	}

	return bestURL;
}
%end

// 禁用点击首页刷新
%hook AWENormalModeTabBarGeneralButton

- (BOOL)enableRefresh {
	if ([self.accessibilityLabel isEqualToString:@"首页"]) {
		if (DYYYGetBool(@"DYYYDisableHomeRefresh")) {
			return NO;
		}
	}
	return %orig;
}

%end

// 屏蔽版本更新
%hook AWEVersionUpdateManager

- (void)startVersionUpdateWorkflow:(id)arg1 completion:(id)arg2 {
	if (DYYYGetBool(@"DYYYNoUpdates")) {
		if (arg2) {
			void (^completionBlock)(void) = arg2;
			completionBlock();
		}
	} else {
		%orig;
	}
}

- (id)workflow {
	return DYYYGetBool(@"DYYYNoUpdates") ? nil : %orig;
}

- (id)badgeModule {
	return DYYYGetBool(@"DYYYNoUpdates") ? nil : %orig;
}

%end

// 应用内推送毛玻璃效果
%hook AWEInnerNotificationWindow

- (id)initWithFrame:(CGRect)frame {
	id orig = %orig;
	if (DYYYGetBool(@"DYYYEnableNotificationTransparency")) {
		[self setupBlurEffectForNotificationView];
	}
	return orig;
}

- (void)layoutSubviews {
	%orig;
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableNotificationTransparency"]) {
		[self setupBlurEffectForNotificationView];
	}
}

- (void)didMoveToWindow {
	%orig;
	if (DYYYGetBool(@"DYYYEnableNotificationTransparency")) {
		[self setupBlurEffectForNotificationView];
	}
}

- (void)didAddSubview:(UIView *)subview {
	%orig;
	if (DYYYGetBool(@"DYYYEnableNotificationTransparency") && [NSStringFromClass([subview class]) containsString:@"AWEInnerNotificationContainerView"]) {
		[self setupBlurEffectForNotificationView];
	}
}

%new
- (void)setupBlurEffectForNotificationView {
	for (UIView *subview in self.subviews) {
		if ([NSStringFromClass([subview class]) containsString:@"AWEInnerNotificationContainerView"]) {
			[self applyBlurEffectToView:subview];
			break;
		}
	}
}

%new
- (void)applyBlurEffectToView:(UIView *)containerView {
	if (!containerView) {
		return;
	}

	containerView.backgroundColor = [UIColor clearColor];

	float userRadius = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYNotificationCornerRadius"] floatValue];
	if (!userRadius || userRadius < 0 || userRadius > 50) {
		userRadius = 12;
	}

	containerView.layer.cornerRadius = userRadius;
	containerView.layer.masksToBounds = YES;

	for (UIView *subview in containerView.subviews) {
		if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 999) {
			[subview removeFromSuperview];
		}
	}

	BOOL isDarkMode = [DYYYUtils isDarkMode];
	UIBlurEffectStyle blurStyle = isDarkMode ? UIBlurEffectStyleDark : UIBlurEffectStyleLight;
	UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
	UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];

	blurView.frame = containerView.bounds;
	blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	blurView.tag = 999;
	blurView.layer.cornerRadius = userRadius;
	blurView.layer.masksToBounds = YES;

	float userTransparency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCommentBlurTransparent"] floatValue];
	if (userTransparency <= 0 || userTransparency > 1) {
		userTransparency = 0.5;
	}

	blurView.alpha = userTransparency;

	[containerView insertSubview:blurView atIndex:0];

	[self clearBackgroundRecursivelyInView:containerView];

	[self setLabelsColorWhiteInView:containerView];
}

%new
- (void)setLabelsColorWhiteInView:(UIView *)view {
	for (UIView *subview in view.subviews) {
		if ([subview isKindOfClass:[UILabel class]]) {
			UILabel *label = (UILabel *)subview;
			NSString *text = label.text;

			if (![text isEqualToString:@"回复"] && ![text isEqualToString:@"查看"] && ![text isEqualToString:@"续火花"]) {
				label.textColor = [UIColor whiteColor];
			}
		}
		[self setLabelsColorWhiteInView:subview];
	}
}

%new
- (void)clearBackgroundRecursivelyInView:(UIView *)view {
	for (UIView *subview in view.subviews) {
		if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 999 && [subview isKindOfClass:[UIButton class]]) {
			continue;
		}
		subview.backgroundColor = [UIColor clearColor];
		subview.opaque = NO;
		[self clearBackgroundRecursivelyInView:subview];
	}
}

%end

// 为 AWEUserActionSheetView 添加毛玻璃效果
%hook AWEUserActionSheetView

- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYisEnableSheetBlur")) {
		[self applyBlurEffectAndWhiteText];
	}
}

%new
- (void)applyBlurEffectAndWhiteText {
	// 应用毛玻璃效果到容器视图
	if (self.containerView) {
		self.containerView.backgroundColor = [UIColor clearColor];

		// 动态获取用户设置的透明度
		float userTransparency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYSheetBlurTransparent"] floatValue];
		if (userTransparency <= 0 || userTransparency > 1) {
			userTransparency = 0.9; // 默认值0.9
		}

		[DYYYUtils applyBlurEffectToView:self.containerView transparency:userTransparency blurViewTag:9999];
		[DYYYUtils clearBackgroundRecursivelyInView:self.containerView];

		// 调用新的通用方法设置文本颜色，这里没有排除需求，所以传入 nil Block
		[DYYYUtils applyTextColorRecursively:[UIColor whiteColor] inView:self.containerView shouldExcludeViewBlock:nil];
	}
}

%end

%hook _TtC33AWECommentLongPressPanelSwiftImpl32CommentLongPressPanelCopyElement

- (void)elementTapped {
	if (DYYYGetBool(@"DYYYCommentCopyText")) {
		AWECommentLongPressPanelContext *commentPageContext = [self commentPageContext];
		AWECommentModel *selectdComment = [commentPageContext selectdComment];
		if (!selectdComment) {
			AWECommentLongPressPanelParam *params = [commentPageContext params];
			selectdComment = [params selectdComment];
		}
		NSString *descText = [selectdComment content];
		[[UIPasteboard generalPasteboard] setString:descText];
		[DYYYToast showSuccessToastWithMessage:@"评论已复制"];
	}
}
%end

// 启用自动勾选原图
%hook AWEIMPhotoPickerFunctionModel

- (void)setUseShadowIcon:(BOOL)arg1 {
	BOOL enabled = DYYYGetBool(@"DYYYisAutoSelectOriginalPhoto");
	if (enabled) {
		%orig(YES);
	} else {
		%orig(arg1);
	}
}

- (BOOL)isSelected {
	BOOL enabled = DYYYGetBool(@"DYYYisAutoSelectOriginalPhoto");
	if (enabled) {
		return YES;
	}
	return %orig;
}

%end

// 屏蔽直播PCDN
%hook HTSLiveStreamPcdnManager

+ (void)start {
	BOOL disablePCDN = DYYYGetBool(@"DYYYDisableLivePCDN");
	if (!disablePCDN) {
		%orig;
	} else {
		NSLog(@"[DYYY] HTSLiveStreamPcdnManager start blocked");
	}
}

+ (void)configAndStartLiveIO {
	BOOL disablePCDN = DYYYGetBool(@"DYYYDisableLivePCDN");
	if (!disablePCDN) {
		%orig;
	} else {
		NSLog(@"[DYYY] HTSLiveStreamPcdnManager configAndStartLiveIO blocked");
	}
}

%end

// PCDN启动任务hook
%hook IESLiveLaunchTaskPcdn

- (void)excute {
	BOOL disablePCDN = DYYYGetBool(@"DYYYDisableLivePCDN");
	if (disablePCDN) {
		NSLog(@"[DYYY] IESLiveLaunchTaskPcdn excute blocked");
		return;
	}
	%orig;
}

%end

// 直播默认最高清晰度功能
%hook HTSLiveStreamQualityFragment

- (void)setupStreamQuality:(id)arg1 {
	%orig;

	BOOL enableHighestQuality = DYYYGetBool(@"DYYYEnableLiveHighestQuality");
	if (enableHighestQuality) {
		NSArray *qualities = self.streamQualityArray;
		if (!qualities || qualities.count == 0) {
			qualities = [self getQualities];
		}

		if (!qualities || qualities.count == 0) {
			return;
		}
		// 选择索引0作为最高清晰度
		[self setResolutionWithIndex:0 isManual:YES beginChange:nil completion:nil];
	}
}

%end

// 强制启用新版抖音长按 UI（现代风）
%hook AWELongPressPanelDataManager
+ (BOOL)enableModernLongPressPanelConfigWithSceneIdentifier:(id)arg1 {
	return DYYYGetBool(@"DYYYisEnableModernPanel");
}
%end

%hook AWELongPressPanelABSettings
+ (NSUInteger)modernLongPressPanelStyleMode {
	if (!DYYYGetBool(@"DYYYisEnableModernPanel")) {
		return %orig;
	}

	BOOL forceBlur = DYYYGetBool(@"DYYYisLongPressPanelBlur");
	BOOL forceDark = DYYYGetBool(@"DYYYisLongPressPanelDark");

	if (forceBlur && forceDark) {
		return 1;
	} else if (!forceBlur && !forceDark) {
		BOOL isDarkMode = [DYYYUtils isDarkMode];
		return isDarkMode ? 1 : 2;
	}
}
%end

%hook AWEModernLongPressPanelUIConfig
+ (NSUInteger)modernLongPressPanelStyleMode {
	if (!DYYYGetBool(@"DYYYisEnableModernPanel")) {
		return %orig;
	}

	BOOL forceBlur = DYYYGetBool(@"DYYYisLongPressPanelBlur");
	BOOL forceDark = DYYYGetBool(@"DYYYisLongPressPanelDark");

	if (forceBlur && forceDark) {
		return 1;
	} else if (!forceBlur && !forceDark) {
		BOOL isDarkMode = [DYYYUtils isDarkMode];
		return isDarkMode ? 1 : 2;
	}
}
%end

// 禁用个人资料自动进入橱窗
%hook AWEUserTabListModel

- (NSInteger)profileLandingTab {
	if (DYYYGetBool(@"DYYYDefaultEnterWorks")) {
		return 0;
	} else {
		return %orig;
	}
}

%end

%group AutoPlay

%hook AWEAwemeDetailTableViewController

- (BOOL)hasIphoneAutoPlaySwitch {
	return YES;
}

%end

%hook AWEAwemeDetailContainerPlayControlConfig

- (BOOL)enableUserProfilePostAutoPlay {
	return YES;
}

%end

%hook AWEFeedIPhoneAutoPlayManager

- (BOOL)isAutoPlayOpen {
	return YES;
}

%end

%hook AWEFeedModuleService

- (BOOL)getFeedIphoneAutoPlayState {
	return YES;
}
%end

%hook AWEFeedIPhoneAutoPlayManager

- (BOOL)getFeedIphoneAutoPlayState {
	BOOL r = %orig;
	return YES;
}
%end

%end

%hook AWEPlayInteractionSpeedController

static BOOL hasChangedSpeed = NO;

- (CGFloat)longPressFastSpeedValue {
	float longPressSpeed = DYYYGetFloat(@"DYYYLongPressSpeed");
	if (longPressSpeed == 0) {
		longPressSpeed = 2.0;
	}
	return longPressSpeed;
}

- (void)changeSpeed:(double)speed {
	float longPressSpeed = DYYYGetFloat(@"DYYYLongPressSpeed");

	if (speed == 2.0) {
		if (!hasChangedSpeed) {
			if (longPressSpeed != 0 && longPressSpeed != 2.0) {
				hasChangedSpeed = YES;
				%orig(longPressSpeed);
				return;
			}
		} else {
			hasChangedSpeed = NO;
			%orig(1.0);
			return;
		}
	}

	if (longPressSpeed == 0 || longPressSpeed == 2) {
		%orig(speed);
		return;
	}
}

%end

%hook UILabel

- (void)setText:(NSString *)text {
	UIView *superview = self.superview;

	if ([superview isKindOfClass:%c(AFDFastSpeedView)] && text) {
		float longPressSpeed = DYYYGetFloat(@"DYYYLongPressSpeed");
		if (longPressSpeed == 0) {
			longPressSpeed = 2.0;
		}

		NSString *speedString = [NSString stringWithFormat:@"%.2f", longPressSpeed];
		if ([speedString hasSuffix:@".00"]) {
			speedString = [speedString substringToIndex:speedString.length - 3];
		} else if ([speedString hasSuffix:@"0"] && [speedString containsString:@"."]) {
			speedString = [speedString substringToIndex:speedString.length - 1];
		}

		if ([text containsString:@"2"]) {
			text = [text stringByReplacingOccurrencesOfString:@"2" withString:speedString];
		}
	}

	%orig(text);
}
%end

// 强制启用保存他人头像
%hook AFDProfileAvatarFunctionManager
- (BOOL)shouldShowSaveAvatarItem {
	BOOL shouldEnable = DYYYGetBool(@"DYYYEnableSaveAvatar");
	if (shouldEnable) {
		return YES;
	}
	return %orig;
}
%end

%hook AWECommentMediaDownloadConfigLivePhoto

bool commentLivePhotoNotWaterMark = DYYYGetBool(@"DYYYCommentLivePhotoNotWaterMark");

- (bool)needClientWaterMark {
	return commentLivePhotoNotWaterMark ? 0 : %orig;
}

- (bool)needClientEndWaterMark {
	return commentLivePhotoNotWaterMark ? 0 : %orig;
}

- (id)watermarkConfig {
	return commentLivePhotoNotWaterMark ? nil : %orig;
}

%end

%hook AWECommentImageModel
- (id)downloadUrl {
	if (DYYYGetBool(@"DYYYCommentNotWaterMark")) {
		return self.originUrl;
	}
	return %orig;
}
%end

%hook _TtC33AWECommentLongPressPanelSwiftImpl37CommentLongPressPanelSaveImageElement

static BOOL isDownloadFlied = NO;

- (BOOL)elementShouldShow {
	BOOL DYYYForceDownloadEmotion = DYYYGetBool(@"DYYYForceDownloadEmotion");
	if (DYYYForceDownloadEmotion) {
		AWECommentLongPressPanelContext *commentPageContext = [self commentPageContext];
		AWECommentModel *selectdComment = [commentPageContext selectdComment];
		if (!selectdComment) {
			AWECommentLongPressPanelParam *params = [commentPageContext params];
			selectdComment = [params selectdComment];
		}
		AWEIMStickerModel *sticker = [selectdComment sticker];
		if (sticker) {
			AWEURLModel *staticURLModel = [sticker staticURLModel];
			NSArray *originURLList = [staticURLModel originURLList];
			if (originURLList.count > 0) {
				return YES;
			}
		}
	}
	return %orig;
}

- (void)elementTapped {
	BOOL DYYYForceDownloadEmotion = DYYYGetBool(@"DYYYForceDownloadEmotion");
	if (DYYYForceDownloadEmotion) {
		AWECommentLongPressPanelContext *commentPageContext = [self commentPageContext];
		AWECommentModel *selectdComment = [commentPageContext selectdComment];
		if (!selectdComment) {
			AWECommentLongPressPanelParam *params = [commentPageContext params];
			selectdComment = [params selectdComment];
		}
		AWEIMStickerModel *sticker = [selectdComment sticker];
		if (sticker) {
			AWEURLModel *staticURLModel = [sticker staticURLModel];
			NSArray *originURLList = [staticURLModel originURLList];
			if (originURLList.count > 0) {
				NSString *urlString = @"";
				if (isDownloadFlied) {
					urlString = originURLList[originURLList.count - 1];
					isDownloadFlied = NO;
				} else {
					urlString = originURLList[0];
				}

				NSURL *heifURL = [NSURL URLWithString:urlString];
				[DYYYManager downloadMedia:heifURL
						 mediaType:MediaTypeHeic
						     audio:nil
						completion:^(BOOL success){
						}];
				return;
			}
		}
	}
	%orig;
}
%end

%group EnableStickerSaveMenu
static __weak YYAnimatedImageView *targetStickerView = nil;

%hook _TtCV28AWECommentPanelListSwiftImpl6NEWAPI27CommentCellStickerComponent

- (void)handleLongPressWithGes:(UILongPressGestureRecognizer *)gesture {
	if (gesture.state == UIGestureRecognizerStateBegan) {
		if ([gesture.view isKindOfClass:%c(YYAnimatedImageView)]) {
			targetStickerView = (YYAnimatedImageView *)gesture.view;
			NSLog(@"DYYY 长按表情：%@", targetStickerView);
		} else {
			targetStickerView = nil;
		}
	}

	%orig;
}

%end

%hook UIMenu

+ (instancetype)menuWithTitle:(NSString *)title image:(UIImage *)image identifier:(UIMenuIdentifier)identifier options:(UIMenuOptions)options children:(NSArray<UIMenuElement *> *)children {
	BOOL hasAddStickerOption = NO;
	BOOL hasSaveLocalOption = NO;

	for (UIMenuElement *element in children) {
		NSString *elementTitle = nil;

		if ([element isKindOfClass:%c(UIAction)]) {
			elementTitle = [(UIAction *)element title];
		} else if ([element isKindOfClass:%c(UICommand)]) {
			elementTitle = [(UICommand *)element title];
		}

		if ([elementTitle isEqualToString:@"添加到表情"]) {
			hasAddStickerOption = YES;
		} else if ([elementTitle isEqualToString:@"保存到相册"]) {
			hasSaveLocalOption = YES;
		}
	}

	if (hasAddStickerOption && !hasSaveLocalOption) {
		NSMutableArray *newChildren = [children mutableCopy];

		UIAction *saveAction = [%c(UIAction) actionWithTitle:@"保存到相册"
									 image:nil
								    identifier:nil
								       handler:^(__kindof UIAction *_Nonnull action) {
									 // 使用全局变量 targetStickerView 保存当前长按的表情
									 if (targetStickerView) {
										 [DYYYManager saveAnimatedSticker:targetStickerView];
									 } else {
										 [DYYYUtils showToast:@"无法获取表情视图"];
									 }
								       }];

		[newChildren addObject:saveAction];
		return %orig(title, image, identifier, options, newChildren);
	}

	return %orig;
}

%end
%end

%hook AWEIMEmoticonPreviewV2

// 添加保存按钮
- (void)layoutSubviews {
	%orig;
	static char kHasSaveButtonKey;
	BOOL DYYYForceDownloadPreviewEmotion = DYYYGetBool(@"DYYYForceDownloadPreviewEmotion");
	if (DYYYForceDownloadPreviewEmotion) {
		if (!objc_getAssociatedObject(self, &kHasSaveButtonKey)) {
			UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
			UIImage *downloadIcon = [UIImage systemImageNamed:@"arrow.down.circle"];
			[saveButton setImage:downloadIcon forState:UIControlStateNormal];
			[saveButton setTintColor:[UIColor whiteColor]];
			saveButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.9 alpha:0.5];

			saveButton.layer.shadowColor = [UIColor blackColor].CGColor;
			saveButton.layer.shadowOffset = CGSizeMake(0, 2);
			saveButton.layer.shadowOpacity = 0.3;
			saveButton.layer.shadowRadius = 3;

			saveButton.translatesAutoresizingMaskIntoConstraints = NO;
			[self addSubview:saveButton];
			CGFloat buttonSize = 24.0;
			saveButton.layer.cornerRadius = buttonSize / 2;

			[NSLayoutConstraint activateConstraints:@[
				[saveButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-15], [saveButton.rightAnchor constraintEqualToAnchor:self.rightAnchor constant:-10],
				[saveButton.widthAnchor constraintEqualToConstant:buttonSize], [saveButton.heightAnchor constraintEqualToConstant:buttonSize]
			]];

			saveButton.userInteractionEnabled = YES;
			[saveButton addTarget:self action:@selector(dyyy_saveButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
			objc_setAssociatedObject(self, &kHasSaveButtonKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
	}
}

%new
- (void)dyyy_saveButtonTapped:(UIButton *)sender {
	// 获取表情包URL
	AWEIMEmoticonModel *emoticonModel = self.model;
	if (!emoticonModel) {
		[DYYYUtils showToast:@"无法获取表情包信息"];
		return;
	}

	NSString *urlString = nil;
	MediaType mediaType = MediaTypeImage;

	// 尝试动态URL
	if ([emoticonModel valueForKey:@"animate_url"]) {
		urlString = [emoticonModel valueForKey:@"animate_url"];
	}
	// 如果没有动态URL，则使用静态URL
	else if ([emoticonModel valueForKey:@"static_url"]) {
		urlString = [emoticonModel valueForKey:@"static_url"];
	}
	// 使用animateURLModel获取URL
	else if ([emoticonModel valueForKey:@"animateURLModel"]) {
		AWEURLModel *urlModel = [emoticonModel valueForKey:@"animateURLModel"];
		if (urlModel.originURLList.count > 0) {
			urlString = urlModel.originURLList[0];
		}
	}

	if (!urlString) {
		[DYYYUtils showToast:@"无法获取表情包链接"];
		return;
	}

	NSURL *url = [NSURL URLWithString:urlString];
	[DYYYManager downloadMedia:url
			 mediaType:MediaTypeHeic
			     audio:nil
			completion:^(BOOL success){
			}];
}

%end

static AWEIMReusableCommonCell *currentCell;

%hook AWEIMCustomMenuComponent
- (void)msg_showMenuForBubbleFrameInScreen:(CGRect)bubbleFrame tapLocationInScreen:(CGPoint)tapLocation menuItemList:(id)menuItems moreEmoticon:(BOOL)moreEmoticon onCell:(id)cell extra:(id)extra {
	if (!DYYYGetBool(@"DYYYForceDownloadIMEmotion")) {
		%orig(bubbleFrame, tapLocation, menuItems, moreEmoticon, cell, extra);
		return;
	}
	NSArray *originalMenuItems = menuItems;

	NSMutableArray *newMenuItems = [originalMenuItems mutableCopy];
	currentCell = (AWEIMReusableCommonCell *)cell;

	AWEIMCustomMenuModel *newMenuItem1 = [%c(AWEIMCustomMenuModel) new];
	newMenuItem1.title = @"保存表情";
	newMenuItem1.imageName = @"im_emoticon_interactive_tab_new";
	newMenuItem1.willPerformMenuActionSelectorBlock = ^(id arg1) {
	  AWEIMMessageComponentContext *context = (AWEIMMessageComponentContext *)currentCell.currentContext;
	  if ([context.message isKindOfClass:%c(AWEIMGiphyMessage)]) {
		  AWEIMGiphyMessage *giphyMessage = (AWEIMGiphyMessage *)context.message;
		  if (giphyMessage.giphyURL && giphyMessage.giphyURL.originURLList.count > 0) {
			  NSURL *url = [NSURL URLWithString:giphyMessage.giphyURL.originURLList.firstObject];
			  [DYYYManager downloadMedia:url
					   mediaType:MediaTypeHeic
					       audio:nil
					  completion:^(BOOL success){
					  }];
		  }
	  }
	};
	newMenuItem1.trackerName = @"保存表情";
	AWEIMMessageComponentContext *context = (AWEIMMessageComponentContext *)currentCell.currentContext;
	if ([context.message isKindOfClass:%c(AWEIMGiphyMessage)]) {
		[newMenuItems addObject:newMenuItem1];
	}
	%orig(bubbleFrame, tapLocation, newMenuItems, moreEmoticon, cell, extra);
}

%end

%hook AWELongVideoControlModel
- (bool)allowDownload {
	return YES;
}
%end

%hook AWELongVideoControlModel
- (long long)preventDownloadType {
	return 0;
}
%end

%hook AWEFeedTabJumpGuideView

- (void)layoutSubviews {
	%orig;
	[self removeFromSuperview];
}

%end

%hook AWEFeedLiveMarkView
- (void)setHidden:(BOOL)hidden {
	if (DYYYGetBool(@"DYYYHideAvatarButton")) {
		hidden = YES;
	}

	%orig(hidden);
}
%end

%hook AWECommentInputBackgroundView
- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideComment")) {
		[self removeFromSuperview];
		return;
	}
}
%end

// 隐藏头像加号和透明
%hook LOTAnimationView
- (void)layoutSubviews {
	%orig;

	// 检查是否需要隐藏加号
	if (DYYYGetBool(@"DYYYHideLOTAnimationView")) {
		[self removeFromSuperview];
		return;
	}

	// 应用透明度设置
	NSString *transparencyValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYAvatarViewTransparency"];
	if (transparencyValue && transparencyValue.length > 0) {
		CGFloat alphaValue = [transparencyValue floatValue];
		if (alphaValue >= 0.0 && alphaValue <= 1.0) {
			self.alpha = alphaValue;
		}
	}
}
%end

// 首页头像隐藏和透明
%hook AWEAdAvatarView
- (void)layoutSubviews {
	%orig;

	// 检查是否需要隐藏头像
	if (DYYYGetBool(@"DYYYHideAvatarButton")) {
		[self removeFromSuperview];
		return;
	}

	// 应用透明度设置
	NSString *transparencyValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYAvatarViewTransparency"];
	if (transparencyValue && transparencyValue.length > 0) {
		CGFloat alphaValue = [transparencyValue floatValue];
		if (alphaValue >= 0.0 && alphaValue <= 1.0) {
			self.alpha = alphaValue;
		}
	}
}
%end

// 移除同城吃喝玩乐提示框
%hook AWENearbySkyLightCapsuleView
- (void)layoutSubviews {
	if (DYYYGetBool(@"DYYYHideNearbyCapsuleView")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

// 移除共创头像列表
%hook AWEPlayInteractionCoCreatorNewInfoView
- (void)layoutSubviews {
	if (DYYYGetBool(@"DYYYHideGongChuang")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

// 隐藏右下音乐和取消静音按钮
%hook AFDCancelMuteAwemeView
- (void)layoutSubviews {
	%orig;

	UIView *superview = self.superview;

	if ([superview isKindOfClass:NSClassFromString(@"AWEBaseElementView")]) {
		if (DYYYGetBool(@"DYYYHideCancelMute")) {
			self.hidden = YES;
		}
	}
}
%end

// 隐藏弹幕按钮
%hook AWEPlayDanmakuInputContainView

- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideDanmuButton")) {
		self.hidden = YES;
	}
}

%end

// 隐藏作者店铺
%hook AWEECommerceEntryView

- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideHisShop")) {
		UIView *parentView = self.superview;
		if (parentView) {
			[parentView removeFromSuperview];
		} else {
			[self removeFromSuperview];
		}
	}
}

%end

// 隐藏评论区免费去看短剧
%hook AWEShowPlayletCommentHeaderView
- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideCommentViews")) {
		[self setHidden:YES];
	}
}

%end

// 隐藏评论区定位
%hook AWEPOIEntryAnchorView

- (void)p_addViews {
	if (DYYYGetBool(@"DYYYHideCommentViews")) {
		return;
	}
	%orig;
}

%end

// 隐藏评论音乐
%hook AWECommentGuideLunaAnchorView
- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideCommentViews")) {
		[self setHidden:YES];
	}

	if (DYYYGetBool(@"DYYYMusicCopyText")) {
		UILabel *label = nil;
		if ([self respondsToSelector:@selector(preTitleLabel)]) {
			label = [self valueForKey:@"preTitleLabel"];
		}
		if (label && [label isKindOfClass:[UILabel class]]) {
			label.text = @"";
		}
	}
}

- (void)p_didClickSong {
	if (DYYYGetBool(@"DYYYMusicCopyText")) {
		// 通过 KVC 拿到内部的 songButton
		UIButton *btn = nil;
		if ([self respondsToSelector:@selector(songButton)]) {
			btn = (UIButton *)[self valueForKey:@"songButton"];
		}

		// 获取歌曲名并复制到剪贴板
		if (btn && [btn isKindOfClass:[UIButton class]]) {
			NSString *song = btn.currentTitle;
			if (song.length) {
				[UIPasteboard generalPasteboard].string = song;
				[DYYYToast showSuccessToastWithMessage:@"歌曲名已复制"];
			}
		}
	} else {
		%orig;
	}
}

%end

// Swift 类组 - 这些会在 %ctor 中动态初始化
%group CommentHeaderGeneralGroup
%hook AWECommentPanelHeaderSwiftImpl_CommentHeaderGeneralView
- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideCommentViews")) {
		[self setHidden:YES];
	}
}
%end
%end
%group CommentHeaderGoodsGroup
%hook AWECommentPanelHeaderSwiftImpl_CommentHeaderGoodsView
- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideCommentViews")) {
		[self setHidden:YES];
	}
}
%end
%end
%group CommentHeaderTemplateGroup
%hook AWECommentPanelHeaderSwiftImpl_CommentHeaderTemplateAnchorView
- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideCommentViews")) {
		[self setHidden:YES];
	}
}
%end
%end
%group CommentBottomTipsVCGroup
%hook AWECommentPanelListSwiftImpl_CommentBottomTipsContainerViewController
- (void)viewWillAppear:(BOOL)animated {
	%orig(animated);
	if (DYYYGetBool(@"DYYYHideCommentTips")) {
		((UIViewController *)self).view.hidden = YES;
	}
}
%end
%end
// Swift 类初始化
%ctor {

	// 动态获取 Swift 类并初始化对应的组
	Class commentHeaderGeneralClass = objc_getClass("AWECommentPanelHeaderSwiftImpl.CommentHeaderGeneralView");
	if (commentHeaderGeneralClass) {
		%init(CommentHeaderGeneralGroup, AWECommentPanelHeaderSwiftImpl_CommentHeaderGeneralView = commentHeaderGeneralClass);
	}

	Class commentHeaderGoodsClass = objc_getClass("AWECommentPanelHeaderSwiftImpl.CommentHeaderGoodsView");
	if (commentHeaderGoodsClass) {
		%init(CommentHeaderGoodsGroup, AWECommentPanelHeaderSwiftImpl_CommentHeaderGoodsView = commentHeaderGoodsClass);
	}

	Class commentHeaderTemplateClass = objc_getClass("AWECommentPanelHeaderSwiftImpl.CommentHeaderTemplateAnchorView");
	if (commentHeaderTemplateClass) {
		%init(CommentHeaderTemplateGroup, AWECommentPanelHeaderSwiftImpl_CommentHeaderTemplateAnchorView = commentHeaderTemplateClass);
	}

	Class tipsVCClass = objc_getClass("AWECommentPanelListSwiftImpl.CommentBottomTipsContainerViewController");
	if (tipsVCClass) {
		%init(CommentBottomTipsVCGroup, AWECommentPanelListSwiftImpl_CommentBottomTipsContainerViewController = tipsVCClass);
	}
}

// 去除隐藏大家都在搜后的留白
%hook AWESearchAnchorListModel

- (BOOL)hideWords {
	return DYYYGetBool(@"DYYYHideCommentViews");
}

%end

// 隐藏观看历史搜索
%hook AWEDiscoverFeedEntranceView
- (id)init {
	if (DYYYGetBool(@"DYYYHideInteractionSearch")) {
		return nil;
	}
	return %orig;
}
%end

// 隐藏校园提示
%hook AWETemplateTagsCommonView

- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideTemplateTags")) {
		UIView *parentView = self.superview;
		if (parentView) {
			parentView.hidden = YES;
		} else {
			self.hidden = YES;
		}
	}
}

%end

// 隐藏挑战贴纸
%hook AWEFeedStickerContainerView

- (BOOL)isHidden {
	BOOL origHidden = %orig;
	BOOL hideRecommend = DYYYGetBool(@"DYYYHideChallengeStickers");
	return origHidden || hideRecommend;
}

- (void)setHidden:(BOOL)hidden {
	BOOL forceHide = DYYYGetBool(@"DYYYHideChallengeStickers");
	%orig(forceHide ? YES : hidden);
}

%end

// 去除"我的"加入挑战横幅
%hook AWEPostWorkViewController
- (BOOL)isDouGuideTipViewShow {
	BOOL r = %orig;
	NSLog(@"Original value: %@", @(r));
	if (DYYYGetBool(@"DYYYHideChallengeStickers")) {
		NSLog(@"Force return YES");
		return YES;
	}
	return r;
}
%end

// 隐藏消息页顶栏头像气泡
%hook AFDSkylightCellBubble
- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYisHiddenAvatarBubble")) {
		[self removeFromSuperview];
		return;
	}
}
%end

// 隐藏消息页开启通知提示
%hook AWEIMMessageTabOptPushBannerView

- (instancetype)initWithFrame:(CGRect)frame {
	if (DYYYGetBool(@"DYYYHidePushBanner")) {
		return %orig(CGRectMake(frame.origin.x, frame.origin.y, 0, 0));
	}
	return %orig;
}

%end

// 隐藏合集和声明
%hook AWEAntiAddictedNoticeBarView
- (void)layoutSubviews {
	%orig;

	// 获取 tipsLabel 属性
	UILabel *tipsLabel = [self valueForKey:@"tipsLabel"];

	if (tipsLabel && [tipsLabel isKindOfClass:%c(UILabel)]) {
		NSString *labelText = tipsLabel.text;

		if (labelText) {
			// 明确判断是合集还是作者声明
			if ([labelText containsString:@"合集"]) {
				// 如果是合集，只检查合集的开关
				if (DYYYGetBool(@"DYYYHideTemplateVideo")) {
					[self removeFromSuperview];
				} else if (DYYYGetBool(@"DYYYisEnableFullScreen")) {
					self.backgroundColor = [UIColor clearColor];
				}
			} else {
				// 如果不是合集（即作者声明），只检查声明的开关
				if (DYYYGetBool(@"DYYYHideAntiAddictedNotice")) {
					[self removeFromSuperview];
				}
			}
		}
	}
}
%end

// 隐藏我的添加朋友
%hook AWEProfileNavigationButton
- (void)setupUI {

	if (DYYYGetBool(@"DYYYHideButton")) {
		return;
	}
	%orig;
}
%end

// 隐藏朋友"关注/不关注"按钮
%hook AWEFeedUnfollowFamiliarFollowAndDislikeView
- (void)showUnfollowFamiliarView {
	if (DYYYGetBool(@"DYYYHideFamiliar")) {
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

// 隐藏朋友日常按钮
%hook AWEFamiliarNavView
- (void)layoutSubviews {

	if (DYYYGetBool(@"DYYYHideFamiliar")) {
		self.hidden = YES;
	}

	%orig;
}
%end

// 隐藏分享给朋友提示
%hook AWEPlayInteractionStrongifyShareContentView

- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideShareContentView")) {
		UIView *parentView = self.superview;
		if (parentView) {
			parentView.hidden = YES;
		} else {
			self.hidden = YES;
		}
	}
}

%end

// 移除下面推荐框黑条
%hook AWEPlayInteractionRelatedVideoView
- (void)layoutSubviews {
	if (DYYYGetBool(@"DYYYHideBottomRelated")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

%hook AWEFeedRelatedSearchTipView
- (void)layoutSubviews {
	if (DYYYGetBool(@"DYYYHideBottomRelated")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

%hook AWENormalModeTabBarBadgeContainerView

- (void)layoutSubviews {
	%orig;
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisHiddenBottomDot"]) {
		return;
	}

	static char kDYBadgeCacheKey;
	NSArray *badges = objc_getAssociatedObject(self, &kDYBadgeCacheKey);
	if (!badges) {
		NSMutableArray *tmp = [NSMutableArray array];
		for (UIView *subview in [self subviews]) {
			if ([subview isKindOfClass:NSClassFromString(@"DUXBadge")]) {
				[tmp addObject:subview];
			}
		}
		badges = [tmp copy];
		objc_setAssociatedObject(self, &kDYBadgeCacheKey, badges, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	for (UIView *badge in badges) {
		badge.hidden = YES;
	}
}

%end

%hook AWELeftSideBarEntranceView
- (void)layoutSubviews {
	%orig;

	UIResponder *responder = self;
	UIViewController *parentVC = nil;
	while ((responder = [responder nextResponder])) {
		if ([responder isKindOfClass:%c(AWEFeedContainerViewController)]) {
			parentVC = (UIViewController *)responder;
			break;
		}
	}

	if (!(parentVC && [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisHiddenLeftSideBar"])) {
		return;
	}

	static char kDYLeftSideViewCacheKey;
	NSArray *cachedViews = objc_getAssociatedObject(self, &kDYLeftSideViewCacheKey);
	if (!cachedViews) {
		NSMutableArray *views = [NSMutableArray array];
		for (UIView *subview in self.subviews) {
			if ([subview isKindOfClass:%c(DUXBaseImageView)]) {
				[views addObject:subview];
			}
		}
		cachedViews = [views copy];
		objc_setAssociatedObject(self, &kDYLeftSideViewCacheKey, cachedViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	for (UIView *v in cachedViews) {
		v.hidden = YES;
	}
}

%end

%hook AWEFeedVideoButton

- (void)layoutSubviews {
	%orig;

	NSString *accessibilityLabel = self.accessibilityLabel;

	BOOL hideBtn = NO;
	BOOL hideLabel = NO;

	if ([accessibilityLabel isEqualToString:@"点赞"]) {
		hideBtn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideLikeButton"];
		hideLabel = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideLikeLabel"];
	} else if ([accessibilityLabel isEqualToString:@"评论"]) {
		hideBtn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentButton"];
		hideLabel = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentLabel"];
	} else if ([accessibilityLabel isEqualToString:@"分享"]) {
		hideBtn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideShareButton"];
		hideLabel = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideShareLabel"];
	} else if ([accessibilityLabel isEqualToString:@"收藏"]) {
		hideBtn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCollectButton"];
		hideLabel = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCollectLabel"];
	}

	if (!hideBtn && !hideLabel) {
		return; // 设置未启用，无需额外处理
	}

	if (hideBtn) {
		[self removeFromSuperview];
		return;
	}

	static char kDYLabelCacheKey;
	NSArray *cachedLabels = objc_getAssociatedObject(self, &kDYLabelCacheKey);
	if (!cachedLabels) {
		NSMutableArray *labels = [NSMutableArray array];
		for (UIView *subview in self.subviews) {
			if ([subview isKindOfClass:[UILabel class]]) {
				[labels addObject:subview];
			}
		}
		cachedLabels = [labels copy];
		objc_setAssociatedObject(self, &kDYLabelCacheKey, cachedLabels, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	for (UILabel *label in cachedLabels) {
		label.hidden = hideLabel;
	}
}

%end

%hook UIButton

- (void)setTitle:(NSString *)title forState:(UIControlState)state {
	%orig;

	if ([title isEqualToString:@"加入挑战"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
		  if (DYYYGetBool(@"DYYYHideChallengeStickers")) {
			  UIResponder *responder = self;
			  BOOL isInPlayInteractionViewController = NO;

			  while ((responder = [responder nextResponder])) {
				  if ([responder isKindOfClass:%c(AWEPlayInteractionViewController)]) {
					  isInPlayInteractionViewController = YES;
					  break;
				  }
			  }

			  if (isInPlayInteractionViewController) {
				  UIView *parentView = self.superview;
				  if (parentView) {
					  UIView *grandParentView = parentView.superview;
					  if (grandParentView) {
						  grandParentView.hidden = YES;
					  } else {
						  parentView.hidden = YES;
					  }
				  } else {
					  self.hidden = YES;
				  }
			  }
		  }
		});
	}
}

- (void)layoutSubviews {
	%orig;

	NSString *accessibilityLabel = self.accessibilityLabel;

	if ([accessibilityLabel isEqualToString:@"拍照搜同款"] || [accessibilityLabel isEqualToString:@"扫一扫"]) {
		if (DYYYGetBool(@"DYYYHideScancode")) {
			[self removeFromSuperview];
			return;
		}
	}

	if ([accessibilityLabel isEqualToString:@"返回"]) {
		if (DYYYGetBool(@"DYYYHideBack")) {
			UIView *parent = self.superview;
			// 父视图是AWEBaseElementView(排除用户主页返回按钮) 按钮类不是AWENoxusHighlightButton(排除横屏返回按钮)
			if ([parent isKindOfClass:%c(AWEBaseElementView)] && ![self isKindOfClass:%c(AWENoxusHighlightButton)]) {
				[self removeFromSuperview];
			}
			return;
		}
	}
}

%end

%hook AWEIMFeedVideoQuickReplayInputViewController

- (void)viewDidLayoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideReply")) {
		[self.view removeFromSuperview];
	}
}

%end

%hook AWEHPSearchBubbleEntranceView
- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideSearchBubble")) {
		[self removeFromSuperview];
		return;
	}
}

%end

%hook ACCGestureResponsibleStickerView
- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideChallengeStickers")) {
		[self removeFromSuperview];
		return;
	}
}
%end

%hook AWEMusicCoverButton

- (void)layoutSubviews {
	%orig;

	NSString *accessibilityLabel = self.accessibilityLabel;

	if ([accessibilityLabel isEqualToString:@"音乐详情"]) {
		if (DYYYGetBool(@"DYYYHideMusicButton")) {
			[self removeFromSuperview];
			return;
		}
	}
}

%end

%hook AWEPlayInteractionListenFeedView
- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideMusicButton")) {
		[self removeFromSuperview];
		return;
	}
}
%end

%hook AWEPlayInteractionFollowPromptView

- (void)layoutSubviews {
	%orig;

	NSString *accessibilityLabel = self.accessibilityLabel;

	if ([accessibilityLabel isEqualToString:@"关注"]) {
		if (DYYYGetBool(@"DYYYHideAvatarButton")) {
			[self removeFromSuperview];
			return;
		}
		if (DYYYGetBool(@"DYYYHideFollowPromptView")) {
			self.userInteractionEnabled = NO;
			[self removeFromSuperview];
			return;
		}
	}
}

%end

%hook AWEPlayInteractionElementMaskView
- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideGradient")) {
		[self removeFromSuperview];
		return;
	}
}
%end

%hook AWEGradientView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideGradient")) {
		UIView *parent = self.superview;
		if ([parent.accessibilityLabel isEqualToString:@"暂停，按钮"] || [parent.accessibilityLabel isEqualToString:@"播放，按钮"] ||
		    [parent.accessibilityLabel isEqualToString:@"“切换视角，按钮"]) {
			[self removeFromSuperview];
		}
		return;
	}
}
%end

%hook AWEHotSpotBlurView
- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideGradient")) {
		[self removeFromSuperview];
		return;
	}
}
%end

%hook AWEHotSearchInnerBottomView
- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideHotSearch")) {
		[self removeFromSuperview];
		return;
	}
}
%end

// 隐藏双指缩放虾线
%hook AWELoadingAndVolumeView

- (void)layoutSubviews {
	%orig;

	if ([self respondsToSelector:@selector(removeFromSuperview)]) {
		[self removeFromSuperview];
	}
	self.hidden = YES;
	return;
}

%end

// 隐藏状态栏
%hook AWEFeedRootViewController
- (BOOL)prefersStatusBarHidden {
	if (DYYYGetBool(@"DYYYisHideStatusbar")) {
		return YES;
	} else {
		if (class_getInstanceMethod([self class], @selector(prefersStatusBarHidden)) !=
		    class_getInstanceMethod([%c(AWEFeedRootViewController) class], @selector(prefersStatusBarHidden))) {
			return %orig;
		}
		return NO;
	}
}
%end

// 直播状态栏
%hook IESLiveAudienceViewController
- (BOOL)prefersStatusBarHidden {
	if (DYYYGetBool(@"DYYYisHideStatusbar")) {
		return YES;
	} else {
		if (class_getInstanceMethod([self class], @selector(prefersStatusBarHidden)) !=
		    class_getInstanceMethod([%c(IESLiveAudienceViewController) class], @selector(prefersStatusBarHidden))) {
			return %orig;
		}
		return NO;
	}
}
%end

// 主页状态栏
%hook AWEAwemeDetailTableViewController
- (BOOL)prefersStatusBarHidden {
	if (DYYYGetBool(@"DYYYisHideStatusbar")) {
		return YES;
	} else {
		if (class_getInstanceMethod([self class], @selector(prefersStatusBarHidden)) !=
		    class_getInstanceMethod([%c(AWEAwemeDetailTableViewController) class], @selector(prefersStatusBarHidden))) {
			return %orig;
		}
		return NO;
	}
}
%end

// 热点状态栏
%hook AWEAwemeHotSpotTableViewController
- (BOOL)prefersStatusBarHidden {
	if (DYYYGetBool(@"DYYYisHideStatusbar")) {
		return YES;
	} else {
		if (class_getInstanceMethod([self class], @selector(prefersStatusBarHidden)) !=
		    class_getInstanceMethod([%c(AWEAwemeHotSpotTableViewController) class], @selector(prefersStatusBarHidden))) {
			return %orig;
		}
		return NO;
	}
}
%end

// 图文状态栏
%hook AWEFullPageFeedNewContainerViewController
- (BOOL)prefersStatusBarHidden {
	if (DYYYGetBool(@"DYYYisHideStatusbar")) {
		return YES;
	} else {
		if (class_getInstanceMethod([self class], @selector(prefersStatusBarHidden)) !=
		    class_getInstanceMethod([%c(AWEFullPageFeedNewContainerViewController) class], @selector(prefersStatusBarHidden))) {
			return %orig;
		}
		return NO;
	}
}
%end

// 隐藏昵称上方元素
%hook AWEFeedTemplateAnchorView

- (void)layoutSubviews {
	%orig;

	BOOL hideFeedAnchor = DYYYGetBool(@"DYYYHideFeedAnchorContainer");
	BOOL hideLocation = DYYYGetBool(@"DYYYHideLocation");

	if (!hideFeedAnchor && !hideLocation)
		return;

	AWECodeGenCommonAnchorBasicInfoModel *anchorInfo = [self valueForKey:@"templateAnchorInfo"];
	if (!anchorInfo || ![anchorInfo respondsToSelector:@selector(name)])
		return;

	NSString *name = [anchorInfo valueForKey:@"name"];
	BOOL isPoi = [name isEqualToString:@"poi_poi"];

	if ((hideFeedAnchor && !isPoi) || (hideLocation && isPoi)) {
		UIView *parentView = self.superview;
		if (parentView) {
			UIView *grandparentView = parentView.superview;
			if (grandparentView && [grandparentView isKindOfClass:%c(AWEBaseElementView)]) {
				[grandparentView removeFromSuperview];
			}
		}
	}
}

%end

%hook AWEPlayInteractionSearchAnchorView

- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideInteractionSearch")) {
		[self removeFromSuperview];
		return;
	}
}

%end

%hook AWEAwemeMusicInfoView

- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideQuqishuiting")) {
		UIView *parentView = self.superview;
		if (parentView) {
			parentView.hidden = YES;
		} else {
			self.hidden = YES;
		}
	}
}

%end

// 隐藏暂停关键词
%hook AWEFeedPauseRelatedWordComponent

- (id)updateViewWithModel:(id)arg0 {
	if (DYYYGetBool(@"DYYYHidePauseVideoRelatedWord")) {
		return nil;
	}
	return %orig;
}

- (id)pauseContentWithModel:(id)arg0 {
	if (DYYYGetBool(@"DYYYHidePauseVideoRelatedWord")) {
		return nil;
	}
	return %orig;
}

- (id)recommendsWords {
	if (DYYYGetBool(@"DYYYHidePauseVideoRelatedWord")) {
		return nil;
	}
	return %orig;
}

- (void)showRelatedRecommendPanelControllerWithSelectedText:(id)arg0 {
	if (DYYYGetBool(@"DYYYHidePauseVideoRelatedWord")) {
		return;
	}
	%orig;
}

- (void)setupUI {
	%orig;
	if (DYYYGetBool(@"DYYYHidePauseVideoRelatedWord")) {
		if (self.relatedView) {
			self.relatedView.hidden = YES;
		}
	}
}

%end

// 隐藏短剧合集
%hook AWETemplatePlayletView

- (void)layoutSubviews {

	if (DYYYGetBool(@"DYYYHideTemplatePlaylet")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

// 隐藏视频顶部搜索框、隐藏搜索框背景、应用全局透明
%hook AWESearchEntranceView

- (void)layoutSubviews {

	if (DYYYGetBool(@"DYYYHideSearchEntrance")) {
		self.hidden = YES;
		return;
	}
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideSearchEntranceIndicator"]) {
		static char kDYSearchIndicatorKey;
		NSArray *indicatorViews = objc_getAssociatedObject(self, &kDYSearchIndicatorKey);
		if (!indicatorViews) {
			NSMutableArray *tmp = [NSMutableArray array];
			for (UIView *subviews in self.subviews) {
				if ([subviews isKindOfClass:%c(UIImageView)] && [NSStringFromClass([((UIImageView *)subviews).image class]) isEqualToString:@"_UIResizableImage"]) {
					[tmp addObject:subviews];
				}
			}
			indicatorViews = [tmp copy];
			objc_setAssociatedObject(self, &kDYSearchIndicatorKey, indicatorViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}

		for (UIImageView *imgView in indicatorViews) {
			imgView.hidden = YES;
		}
	}

	// NSString *transparentValue = DYYYGetString(@"DYYYGlobalTransparency");
	// if (transparentValue.length > 0) {
	//     CGFloat alphaValue = transparentValue.floatValue;
	//     if (alphaValue >= 0.0 && alphaValue <= 1.0) {
	//         self.alpha = alphaValue;
	//     }
	// }

	%orig;
}

%end

// 隐藏视频滑条
%hook AWEStoryProgressSlideView

- (void)layoutSubviews {
	%orig;

	BOOL shouldHide = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideStoryProgressSlide"];
	if (!shouldHide)
		return;

	static char kDYStoryProgressCacheKey;
	UIView *targetView = objc_getAssociatedObject(self, &kDYStoryProgressCacheKey);
	if (!targetView) {
		for (UIView *obj in self.subviews) {
			if ([obj isKindOfClass:NSClassFromString(@"UISlider")] || obj.frame.size.height < 5) {
				targetView = obj.superview;
				break;
			}
		}
		if (targetView) {
			objc_setAssociatedObject(self, &kDYStoryProgressCacheKey, targetView, OBJC_ASSOCIATION_ASSIGN);
		}
	}

	if (targetView) {
		targetView.hidden = YES;
	}
}

%end

// 隐藏好友分享私信
%hook AFDNewFastReplyView

- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHidePrivateMessages")) {
		UIView *parentView = self.superview;
		if (parentView) {
			parentView.hidden = YES;
		} else {
			self.hidden = YES;
		}
	}
}

%end

// 隐藏下面底部热点框
%hook AWENewHotSpotBottomBarView
- (void)layoutSubviews {
	if (DYYYGetBool(@"DYYYHideHotspot")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

%hook AWETemplateHotspotView

- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideHotspot")) {
		[self removeFromSuperview];
		return;
	}
}

%end

// 隐藏关注直播
%hook AWEConcernSkylightCapsuleView
- (void)setHidden:(BOOL)hidden {
	if (DYYYGetBool(@"DYYYHideConcernCapsuleView")) {
		[self removeFromSuperview];
		return;
	}

	%orig(hidden);
}
%end

%hook AWEHomePageBubbleLiveHeadLabelContentView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideConcernCapsuleView")) {
		UIView *parentView = self.superview;
		UIView *grandparentView = parentView.superview;

		if (grandparentView) {
			[grandparentView removeFromSuperview];
		} else if (parentView) {
			[parentView removeFromSuperview];
		} else {
			[self removeFromSuperview];
		}
	}
}
%end

// 隐藏直播发现
%hook AWEFeedLiveTabRevisitControlView

- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideLiveDiscovery")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
}
%end

%hook IESLiveDynamicRankListEntranceView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideLiveDetail")) {
		[self removeFromSuperview];
	}
}
%end

%hook IESLiveMatrixEntranceView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideLiveDetail")) {
		[self removeFromSuperview];
	}
}
%end

%hook IESLiveShortTouchActionView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideTouchView")) {
		[self removeFromSuperview];
	}
}
%end

%hook IESLiveLotteryAnimationViewNew
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideTouchView")) {
		[self removeFromSuperview];
	}
}
%end

%hook IESLiveConfigurableShortTouchEntranceView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideTouchView")) {
		[self removeFromSuperview];
	}
}
%end

%hook IESLiveRedEnvelopeAniLynxView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideTouchView")) {
		[self removeFromSuperview];
	}
}
%end

// 隐藏直播点歌
%hook IESLiveKTVSongIndicatorView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideKTVSongIndicator")) {
		self.hidden = YES;
		[self removeFromSuperview];
	}
}
%end

// 隐藏图片滑条
%hook AWEStoryProgressContainerView
- (BOOL)isHidden {
	BOOL originalValue = %orig;
	BOOL customHide = DYYYGetBool(@"DYYYHideDotsIndicator");
	return originalValue || customHide;
}

- (void)setHidden:(BOOL)hidden {
	BOOL forceHide = DYYYGetBool(@"DYYYHideDotsIndicator");
	%orig(forceHide ? YES : hidden);
}
%end

// 隐藏昵称右侧
%hook UILabel
- (void)layoutSubviews {
	%orig;

	BOOL hideRightLabel = DYYYGetBool(@"DYYYHideRightLable");
	if (!hideRightLabel)
		return;

	NSString *accessibilityLabel = self.accessibilityLabel;
	if (!accessibilityLabel || accessibilityLabel.length == 0)
		return;

	NSString *trimmedLabel = [accessibilityLabel stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	BOOL shouldHide = NO;

	if ([trimmedLabel hasSuffix:@"人共创"]) {
		NSString *prefix = [trimmedLabel substringToIndex:trimmedLabel.length - 3];
		NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
		shouldHide = ([prefix rangeOfCharacterFromSet:nonDigits].location == NSNotFound);
	}

	if (!shouldHide) {
		shouldHide = [trimmedLabel isEqualToString:@"章节要点"] || [trimmedLabel isEqualToString:@"图集"];
	}

	if (shouldHide) {
		self.hidden = YES;

		// 找到父视图是否为 UIStackView
		UIView *superview = self.superview;
		if ([superview isKindOfClass:[UIStackView class]]) {
			UIStackView *stackView = (UIStackView *)superview;
			// 刷新 UIStackView 的布局
			[stackView layoutIfNeeded];
		}
	}
}
%end

// 隐藏顶栏关注下的提示线
%hook AWEFeedMultiTabSelectedContainerView

- (void)setHidden:(BOOL)hidden {
	BOOL forceHide = DYYYGetBool(@"DYYYHidentopbarprompt");

	if (forceHide) {
		%orig(YES);
	} else {
		%orig(hidden);
	}
}

%end

%hook AFDRecommendToFriendEntranceLabel
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideRecommendTips")) {
		if (self.accessibilityLabel) {
			[self removeFromSuperview];
		}
	}
}

%end

// 隐藏自己无公开作品的视图
%hook AWEProfileMixItemCollectionViewCell
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHidePostView")) {
		if ([self.accessibilityLabel isEqualToString:@"私密作品"]) {
			[self removeFromSuperview];
		}
	}
}
%end

%hook AWEProfileTaskCardStyleListCollectionViewCell
- (BOOL)shouldShowPublishGuide {
	if (DYYYGetBool(@"DYYYHidePostView")) {
		return NO;
	}
	return %orig;
}
%end

%hook AWEProfileRichEmptyView

- (void)setTitle:(id)title {
	if (DYYYGetBool(@"DYYYHidePostView")) {
		return;
	}
	%orig(title);
}

- (void)setDetail:(id)detail {
	if (DYYYGetBool(@"DYYYHidePostView")) {
		return;
	}
	%orig(detail);
}
%end

// 隐藏关注直播顶端
%hook AWENewLiveSkylightViewController

// 隐藏顶部直播视图 - 添加条件判断
- (void)showSkylight:(BOOL)arg0 animated:(BOOL)arg1 actionMethod:(unsigned long long)arg2 {
	if (DYYYGetBool(@"DYYYHidenLiveView")) {
		return;
	}
	%orig(arg0, arg1, arg2);
}

- (void)updateIsSkylightShowing:(BOOL)arg0 {
	if (DYYYGetBool(@"DYYYHidenLiveView")) {
		%orig(NO);
	} else {
		%orig(arg0);
	}
}

%end

%hook AWELiveAutoEnterStyleAView

- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHidenLiveView")) {
		[self removeFromSuperview];
		return;
	}
}

%end

// 隐藏同城顶端
%hook AWENearbyFullScreenViewModel

- (void)setShowSkyLight:(id)arg1 {
	if (DYYYGetBool(@"DYYYHideMenuView")) {
		arg1 = nil;
	}
	%orig(arg1);
}

- (void)setHaveSkyLight:(id)arg1 {
	if (DYYYGetBool(@"DYYYHideMenuView")) {
		arg1 = nil;
	}
	%orig(arg1);
}

%end

// 隐藏笔记
%hook AWECorrelationItemTag

- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideItemTag")) {
		self.hidden = YES;
		return;
	}
}

%end

// 隐藏话题
%hook AWEPlayInteractionTemplateButtonGroup
- (void)layoutSubviews {
	if (DYYYGetBool(@"DYYYHideTemplateGroup")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

%hook AWEPlayInteractionViewController

- (void)onVideoPlayerViewDoubleClicked:(id)arg1 {
	BOOL isSwitchOn = DYYYGetBool(@"DYYYDouble");
	if (!isSwitchOn) {
		%orig;
	}
}
%end

// 隐藏右上搜索，但可点击
%hook AWEHPDiscoverFeedEntranceView

- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideDiscover")) {
		UIView *firstSubview = self.subviews.firstObject;
		if ([firstSubview isKindOfClass:[UIImageView class]]) {
			((UIImageView *)firstSubview).image = nil;
		}
	}
}

%end

// 隐藏点击进入直播间
%hook AWELiveFeedStatusLabel
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideEnterLive")) {
		UIView *parentView = self.superview;
		UIView *grandparentView = parentView.superview;

		if (grandparentView) {
			grandparentView.hidden = YES;
		} else if (parentView) {
			parentView.hidden = YES;
		} else {
			self.hidden = YES;
		}
	}
}
%end

// 去除消息群直播提示
%hook AWEIMCellLiveStatusContainerView

- (void)p_initUI {
	if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYGroupLiving"])
		%orig;
}
%end

%hook AWELiveStatusIndicatorView

- (void)layoutSubviews {
	if (DYYYGetBool(@"DYYYGroupLiving")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

%hook AWELiveSkylightCatchView
- (void)layoutSubviews {

	if (DYYYGetBool(@"DYYYHidenLiveCapsuleView")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}

%end

// 隐藏首页直播胶囊
%hook AWEHPTopTabItemBadgeContentView

- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideLiveCapsuleView")) {
		self.hidden = YES;
		return;
	}
}

%end

// 隐藏群商店
%hook AWEIMFansGroupTopDynamicDomainTemplateView
- (void)layoutSubviews {
	if (DYYYGetBool(@"DYYYHideGroupShop")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

// 去除群聊天输入框上方快捷方式
%hook AWEIMInputActionBarInteractor

- (void)p_setupUI {
	if (DYYYGetBool(@"DYYYHideGroupInputActionBar")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

// 隐藏相机定位
%hook AWETemplateCommonView
- (void)layoutSubviews {
	if (DYYYGetBool(@"DYYYHideCameraLocation")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

// 隐藏侧栏红点
%hook AWEHPTopBarCTAItemView

- (void)showRedDot {
	if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYisHiddenSidebarDot"])
		%orig;
}

- (void)hideCountRedDot {
	if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYisHiddenSidebarDot"])
		%orig;
}

- (void)layoutSubviews {
	%orig;

	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisHiddenSidebarDot"]) {
		return;
	}

	static char kDYSidebarBadgeCacheKey;
	NSArray *cachedBadges = objc_getAssociatedObject(self, &kDYSidebarBadgeCacheKey);
	if (!cachedBadges) {
		NSMutableArray *badges = [NSMutableArray array];
		for (UIView *subview in self.subviews) {
			if ([subview isKindOfClass:%c(DUXBadge)]) {
				[badges addObject:subview];
			}
		}
		cachedBadges = [badges copy];
		objc_setAssociatedObject(self, &kDYSidebarBadgeCacheKey, cachedBadges, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	for (UIView *badge in cachedBadges) {
		badge.hidden = YES;
	}
}
%end

%hook AWELeftSideBarEntranceView

- (void)setRedDot:(id)redDot {
	%orig(nil);
}

- (void)setNumericalRedDot:(id)numericalRedDot {
	%orig(nil);
}

%end

// 隐藏搜同款
%hook ACCStickerContainerView
- (void)layoutSubviews {
	if (DYYYGetBool(@"DYYYHideSearchSame")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES; // 隐藏更彻底
		return;
	}
	%orig;
}
%end

// 隐藏礼物展馆
%hook BDXWebView
- (void)layoutSubviews {
	%orig;

	BOOL enabled = DYYYGetBool(@"DYYYHideGiftPavilion");
	if (!enabled)
		return;

	NSString *title = [self valueForKey:@"title"];

	if ([title containsString:@"任务Banner"] || [title containsString:@"活动Banner"]) {
		[self removeFromSuperview];
	}
}
%end

%hook AWEVideoTypeTagView

- (void)setupUI {
	if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYHideLiveGIF"])
		%orig;
}
%end

// 隐藏直播广场
%hook IESLiveFeedDrawerEntranceView
- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideLivePlayground")) {
		self.hidden = YES;
	}
}

%end

// 隐藏顶栏红点
%hook AWEHPTopTabItemBadgeContentView
- (id)showBadgeWithBadgeStyle:(NSUInteger)style badgeConfig:(id)config count:(NSInteger)count text:(id)text {
	BOOL hideEnabled = DYYYGetBool(@"DYYYHideTopBarBadge");

	if (hideEnabled) {
		return nil;
	} else {
		return %orig(style, config, count, text);
	}
}
%end

// 隐藏直播退出清屏、投屏按钮
%hook IESLiveButton

- (void)layoutSubviews {
	%orig;
	BOOL hideClear = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideLiveRoomClear"];
	BOOL hideMirror = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideLiveRoomMirroring"];
	BOOL hideFull = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideLiveRoomFullscreen"];

	if (!(hideClear || hideMirror || hideFull)) {
		return;
	}

	NSString *label = self.accessibilityLabel;
	if (hideClear && [label isEqualToString:@"退出清屏"] && self.superview) {
		[self.superview removeFromSuperview];
	} else if (hideMirror && [label isEqualToString:@"投屏"] && self.superview) {
		[self.superview removeFromSuperview];
	} else if (hideFull && [label isEqualToString:@"横屏"] && self.superview) {
		static char kDYLiveButtonCacheKey;
		NSArray *cached = objc_getAssociatedObject(self, &kDYLiveButtonCacheKey);
		if (!cached) {
			cached = [self.subviews copy];
			objc_setAssociatedObject(self, &kDYLiveButtonCacheKey, cached, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
		for (UIView *subview in cached) {
			subview.hidden = YES;
		}
	}
}

%end

// 隐藏直播间右上方关闭直播按钮
%hook IESLiveLayoutPlaceholderView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideLiveRoomClose")) {
		self.hidden = YES;
	}
}
%end

// 隐藏直播间流量弹窗
%hook AWELiveFlowAlertView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideCellularAlert")) {
		self.hidden = YES;
	}
}
%end

// 隐藏直播间商品信息
%hook IESECLivePluginLayoutView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideLiveGoodsMsg")) {
		[self removeFromSuperview];
	}
}
%end

%hook IESLiveBottomRightCardView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideLiveGoodsMsg")) {
		[self removeFromSuperview];
	}
}
%end

%hook IESLiveGameCPExplainCardContainerImpl
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideLiveGoodsMsg")) {
		[self removeFromSuperview];
	}
}
%end

%hook AWEPOILivePurchaseAtmosphereView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideLiveGoodsMsg") && self.superview) {
		[self.superview removeFromSuperview];
	}
}
%end

%hook IESLiveActivityBannnerView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideLiveGoodsMsg")) {
		[self removeFromSuperview];
	}
}
%end

// 隐藏直播间点赞动画
%hook HTSLiveDiggView
- (void)setIconImageView:(UIImageView *)arg1 {
	if (DYYYGetBool(@"DYYYHideLiveLikeAnimation")) {
		%orig(nil);
	} else {
		%orig(arg1);
	}
}
%end

// 隐藏直播间文字贴纸
%hook IESLiveStickerView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideStickerView")) {
		[self removeFromSuperview];
	}
}
%end

// 预约直播
%hook IESLivePreAnnouncementPanelViewNew
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideStickerView")) {
		[self removeFromSuperview];
	}
}
%end

// 隐藏会员进场特效
%hook IESLiveDynamicUserEnterView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideLivePopup")) {
		[self removeFromSuperview];
	}
}
%end

// 隐藏特殊进场特效
%hook PlatformCanvasView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideLivePopup")) {
		UIView *pview = self.superview;
		UIView *gpview = pview.superview;
		// 基于accessibilitylabel的判断
		BOOL isLynxView = [pview isKindOfClass:%c(UILynxView)] && [gpview isKindOfClass:%c(LynxView)] && [gpview.accessibilityLabel isEqualToString:@"lynxview"];
		// 基于最近的视图控制器IESLiveAudienceViewController的判断
		UIViewController *vc = [DYYYUtils firstAvailableViewControllerFromView:self];
		BOOL isLiveAudienceVC = [vc isKindOfClass:%c(IESLiveAudienceViewController)];
		if (isLynxView && isLiveAudienceVC) {
			[self removeFromSuperview];
		}
	}
}
%end

%hook IESLiveDanmakuVariousView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideLiveDanmaku")) {
		[self removeFromSuperview];
	}
}

%end

%hook IESLiveHotMessageView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideLiveHotMessage")) {
		[self removeFromSuperview];
	}
}
%end

// 屏蔽青少年模式弹窗
%hook AWETeenModeAlertView
- (BOOL)show {
	if (DYYYGetBool(@"DYYYHideteenmode")) {
		return NO;
	}
	return %orig;
}
%end

// 屏蔽青少年模式弹窗
%hook AWETeenModeSimpleAlertView
- (BOOL)show {
	if (DYYYGetBool(@"DYYYHideteenmode")) {
		return NO;
	}
	return %orig;
}
%end

%hook AWEAwemeModel

- (id)initWithDictionary:(id)arg1 error:(id *)arg2 {
	id orig = %orig;
	if (orig && [self contentFilter])
		return nil;
	return orig;
}

- (id)init {
	id orig = %orig;
	if (orig && [self contentFilter])
		return nil;
	return orig;
}

%new
- (BOOL)contentFilter {
	BOOL noAds = DYYYGetBool(@"DYYYNoAds");
	BOOL skipLive = DYYYGetBool(@"DYYYisSkipLive");
	BOOL skipHotSpot = DYYYGetBool(@"DYYYisSkipHotSpot");
	BOOL filterHDR = DYYYGetBool(@"DYYYfilterFeedHDR");

	BOOL shouldFilterAds = noAds && (self.hotSpotLynxCardModel || self.isAds);
	BOOL shouldFilterHotSpot = skipHotSpot && self.hotSpotLynxCardModel;
	BOOL shouldFilterRecLive = skipLive && (self.cellRoom != nil);
	BOOL shouldFilterHDR = NO;
	BOOL shouldFilterLowLikes = NO;
	BOOL shouldFilterKeywords = NO;
	BOOL shouldFilterProp = NO;
	BOOL shouldFilterTime = NO;
	BOOL shouldFilterUser = NO;

	// 获取用户设置的需要过滤的关键词
	NSString *filterKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterKeywords"];
	NSArray *keywordsList = nil;

	if (filterKeywords.length > 0) {
		keywordsList = [filterKeywords componentsSeparatedByString:@","];
	}

	// 过滤包含指定拍同款的视频
	NSString *filterProp = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterProp"];
	NSArray *propKeywordsList = nil;

	if (filterProp.length > 0) {
		propKeywordsList = [filterProp componentsSeparatedByString:@","];
	}

	// 获取需要过滤的用户列表
	NSString *filterUsers = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterUsers"];

	// 检查是否需要过滤特定用户
	if (self.shareRecExtra && ![self.shareRecExtra isEqual:@""] && filterUsers.length > 0 && self.author) {
		NSArray *usersList = [filterUsers componentsSeparatedByString:@","];
		NSString *currentShortID = self.author.shortID;
		NSString *currentNickname = self.author.nickname;

		if (currentShortID.length > 0) {
			for (NSString *userInfo in usersList) {
				// 解析"昵称-id"格式
				NSArray *components = [userInfo componentsSeparatedByString:@"-"];
				if (components.count >= 2) {
					NSString *userId = [components lastObject];
					NSString *userNickname = [[components subarrayWithRange:NSMakeRange(0, components.count - 1)] componentsJoinedByString:@"-"];

					if ([userId isEqualToString:currentShortID]) {
						shouldFilterUser = YES;
						break;
					}
				}
			}
		}
	}

	// 只有当shareRecExtra不为空时才过滤点赞量低的视频和关键词
	if (self.shareRecExtra && ![self.shareRecExtra isEqual:@""]) {
		NSInteger filterLowLikesThreshold = DYYYGetInteger(@"DYYYfilterLowLikes");
		// 过滤低点赞量视频
		if (filterLowLikesThreshold > 0) {
			AWESearchAwemeExtraModel *searchExtraModel = [self searchExtraModel];
			if (!searchExtraModel) {
				AWEAwemeStatisticsModel *statistics = self.statistics;
				if (statistics && statistics.diggCount) {
					shouldFilterLowLikes = statistics.diggCount.integerValue < filterLowLikesThreshold;
				}
			}
		}

		// 过滤包含特定关键词的视频
		if (keywordsList.count > 0) {
			// 检查视频标题
			if (self.descriptionString.length > 0) {
				for (NSString *keyword in keywordsList) {
					NSString *trimmedKeyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
					if (trimmedKeyword.length > 0 && [self.descriptionString containsString:trimmedKeyword]) {
						shouldFilterKeywords = YES;
						break;
					}
				}
			}
		}

		// 过滤包含特定道具的视频
		if (propKeywordsList.count > 0 && self.propGuideV2) {
			NSString *propName = self.propGuideV2.propName;
			if (propName.length > 0) {
				for (NSString *propKeyword in propKeywordsList) {
					NSString *trimmedKeyword = [propKeyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
					if (trimmedKeyword.length > 0 && [propName containsString:trimmedKeyword]) {
						shouldFilterProp = YES;
						break;
					}
				}
			}
		}

		// 过滤视频发布时间
		long long currentTimestamp = (long long)[[NSDate date] timeIntervalSince1970];
		NSInteger daysThreshold = DYYYGetInteger(@"DYYYfiltertimelimit");
		if (daysThreshold > 0) {
			NSTimeInterval videoTimestamp = [self.createTime doubleValue];
			if (videoTimestamp > 0) {
				NSTimeInterval threshold = daysThreshold * 86400.0;
				NSTimeInterval current = (NSTimeInterval)currentTimestamp;
				NSTimeInterval timeDifference = current - videoTimestamp;
				shouldFilterTime = (timeDifference > threshold);
			}
		}
	}

	// 检查是否为HDR视频
	if (filterHDR && self.video && self.video.bitrateModels) {
		for (id bitrateModel in self.video.bitrateModels) {
			NSNumber *hdrType = [bitrateModel valueForKey:@"hdrType"];
			NSNumber *hdrBit = [bitrateModel valueForKey:@"hdrBit"];

			// 如果hdrType=1且hdrBit=10，则视为HDR视频
			if (hdrType && [hdrType integerValue] == 1 && hdrBit && [hdrBit integerValue] == 10) {
				shouldFilterHDR = YES;
				break;
			}
		}
	}
	return shouldFilterAds || shouldFilterRecLive || shouldFilterHotSpot || shouldFilterHDR || shouldFilterLowLikes || shouldFilterKeywords || shouldFilterProp || shouldFilterTime ||
	       shouldFilterUser;
}

- (AWEECommerceLabel *)ecommerceBelowLabel {
	if (DYYYGetBool(@"DYYYHideHisShop")) {
		return nil;
	}
	return %orig;
}

- (bool)preventDownload {
	if (DYYYGetBool(@"DYYYNoAds")) {
		return NO;
	} else {
		return %orig;
	}
}

- (void)setAdLinkType:(long long)arg1 {
	if (DYYYGetBool(@"DYYYNoAds")) {
		arg1 = 0;
	} else {
	}

	%orig;
}

// 固定设置为 1，启用自定义背景色
- (NSUInteger)awe_playerBackgroundViewShowType {
	if ([[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYVideoBGColor"]) {
		return 1;
	}
	return %orig;
}

- (UIColor *)awe_smartBackgroundColor {
	NSString *colorHex = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYVideoBGColor"];
	if (colorHex && colorHex.length > 0) {
		CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
		UIColor *customColor = [DYYYUtils colorFromSchemeHexString:colorHex targetWidth:screenWidth];
		if (customColor)
			return customColor;
	}
	return %orig;
}

%end

%hook MTKView

- (void)layoutSubviews {
	%orig;
	UIViewController *vc = [DYYYUtils firstAvailableViewControllerFromView:self];
	Class playVCClass = NSClassFromString(@"AWEPlayVideoViewController");
	if (vc && playVCClass && [vc isKindOfClass:playVCClass]) {
		NSString *colorHex = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYVideoBGColor"];
		if (colorHex && colorHex.length > 0) {
			CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
			UIColor *customColor = [DYYYUtils colorFromSchemeHexString:colorHex targetWidth:screenWidth];
			if (customColor)
				self.backgroundColor = customColor;
		}
	}
}

%end

// 拦截开屏广告
%hook BDASplashControllerView
+ (id)alloc {
	BOOL noAds = DYYYGetBool(@"DYYYNoAds");
	if (noAds) {
		return nil;
	}
	return %orig;
}
%end

// 去除启动视频广告
%hook AWEAwesomeSplashFeedCellOldAccessoryView

- (id)ddExtraView {
	if (DYYYGetBool(@"DYYYNoAds")) {
		return NULL;
	}

	return %orig;
}

%end

// 去广告功能
%hook AwemeAdManager
- (void)showAd {
	if (DYYYGetBool(@"DYYYNoAds"))
		return;
	%orig;
}
%end

%hook AWEPlayInteractionUserAvatarView
- (void)layoutSubviews {
	%orig;

	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideFollowPromptView"]) {
		return;
	}

	static char kDYAvatarCacheKey;
	NSArray *viewCache = objc_getAssociatedObject(self, &kDYAvatarCacheKey);
	if (!viewCache) {
		NSMutableArray *tmp = [NSMutableArray array];
		for (UIView *subview in self.subviews) {
			if ([subview isMemberOfClass:[UIView class]]) {
				[tmp addObject:subview];
			}
		}
		viewCache = [tmp copy];
		objc_setAssociatedObject(self, &kDYAvatarCacheKey, viewCache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	for (UIView *container in viewCache) {
		for (UIView *child in container.subviews) {
			child.alpha = 0.0;
		}
	}
}
%end

%hook AWEPlayInteractionViewController

- (void)onPlayer:(id)arg0 didDoubleClick:(id)arg1 {
	BOOL isPopupEnabled = DYYYGetBool(@"DYYYEnableDoubleOpenAlertController");
	BOOL isDirectCommentEnabled = DYYYGetBool(@"DYYYEnableDoubleOpenComment");

	// 直接打开评论区的情况
	if (isDirectCommentEnabled) {
		[self performCommentAction];
		return;
	}

	if (isPopupEnabled) {
		AWEAwemeModel *awemeModel = nil;

		awemeModel = [self performSelector:@selector(awemeModel)];

		AWEVideoModel *videoModel = awemeModel.video;
		AWEMusicModel *musicModel = awemeModel.music;
		NSURL *audioURL = nil;
		if (musicModel && musicModel.playURL && musicModel.playURL.originURLList.count > 0) {
			audioURL = [NSURL URLWithString:musicModel.playURL.originURLList.firstObject];
		}

		// 确定内容类型（视频或图片）
		BOOL isImageContent = (awemeModel.awemeType == 68);
		// 判断是否为新版实况照片
		BOOL isNewLivePhoto = (awemeModel.video && awemeModel.animatedImageVideoInfo != nil);
		NSString *downloadTitle;

		if (isImageContent) {
			AWEImageAlbumImageModel *currentImageModel = nil;
			if (awemeModel.currentImageIndex > 0 && awemeModel.currentImageIndex <= awemeModel.albumImages.count) {
				currentImageModel = awemeModel.albumImages[awemeModel.currentImageIndex - 1];
			} else {
				currentImageModel = awemeModel.albumImages.firstObject;
			}

			if (awemeModel.albumImages.count > 1) {
				downloadTitle = (currentImageModel.clipVideo != nil || awemeModel.isLivePhoto) ? @"保存当前实况" : @"保存当前图片";
			} else {
				downloadTitle = (currentImageModel.clipVideo != nil || awemeModel.isLivePhoto) ? @"保存实况" : @"保存图片";
			}
		} else if (isNewLivePhoto) {
			downloadTitle = @"保存实况";
		} else {
			downloadTitle = @"保存视频";
		}

		AWEUserActionSheetView *actionSheet = [[NSClassFromString(@"AWEUserActionSheetView") alloc] init];
		NSMutableArray *actions = [NSMutableArray array];

		// 添加下载选项
		if (DYYYGetBool(@"DYYYDoubleTapDownload") || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapDownload"]) {

			AWEUserSheetAction *downloadAction = [NSClassFromString(@"AWEUserSheetAction")
			    actionWithTitle:downloadTitle
				    imgName:nil
				    handler:^{
				      if (isImageContent) {
					      // 图片内容
					      AWEImageAlbumImageModel *currentImageModel = nil;
					      if (awemeModel.currentImageIndex > 0 && awemeModel.currentImageIndex <= awemeModel.albumImages.count) {
						      currentImageModel = awemeModel.albumImages[awemeModel.currentImageIndex - 1];
					      } else {
						      currentImageModel = awemeModel.albumImages.firstObject;
					      }

					      // 查找非.image后缀的URL
					      NSURL *downloadURL = nil;
					      for (NSString *urlString in currentImageModel.urlList) {
						      NSURL *url = [NSURL URLWithString:urlString];
						      NSString *pathExtension = [url.path.lowercaseString pathExtension];
						      if (![pathExtension isEqualToString:@"image"]) {
							      downloadURL = url;
							      break;
						      }
					      }

					      if (currentImageModel.clipVideo != nil) {
						      NSURL *videoURL = [currentImageModel.clipVideo.playURL getDYYYSrcURLDownload];
						      [DYYYManager downloadLivePhoto:downloadURL
									    videoURL:videoURL
									  completion:^{
									  }];
					      } else if (currentImageModel && currentImageModel.urlList.count > 0) {
						      if (downloadURL) {
							      [DYYYManager downloadMedia:downloadURL
									       mediaType:MediaTypeImage
										   audio:nil
									      completion:^(BOOL success) {
										if (success) {
										} else {
											[DYYYUtils showToast:@"图片保存已取消"];
										}
									      }];
						      } else {
							      [DYYYUtils showToast:@"没有找到合适格式的图片"];
						      }
					      }
				      } else if (isNewLivePhoto) {
					      // 新版实况照片
					      // 使用封面URL作为图片URL
					      NSURL *imageURL = nil;
					      if (videoModel.coverURL && videoModel.coverURL.originURLList.count > 0) {
						      imageURL = [NSURL URLWithString:videoModel.coverURL.originURLList.firstObject];
					      }

					      // 视频URL从视频模型获取
					      NSURL *videoURL = nil;
					      if (videoModel && videoModel.playURL && videoModel.playURL.originURLList.count > 0) {
						      videoURL = [NSURL URLWithString:videoModel.playURL.originURLList.firstObject];
					      } else if (videoModel && videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
						      videoURL = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
					      }

					      // 下载实况照片
					      if (imageURL && videoURL) {
						      [DYYYManager downloadLivePhoto:imageURL
									    videoURL:videoURL
									  completion:^{
									  }];
					      }
				      } else {
					      // 视频内容
					      if (videoModel && videoModel.bitrateModels && videoModel.bitrateModels.count > 0) {
						      // 优先使用bitrateModels中的最高质量版本
						      id highestQualityModel = videoModel.bitrateModels.firstObject;
						      NSArray *urlList = nil;
						      id playAddrObj = [highestQualityModel valueForKey:@"playAddr"];

						      if ([playAddrObj isKindOfClass:%c(AWEURLModel)]) {
							      AWEURLModel *playAddrModel = (AWEURLModel *)playAddrObj;
							      urlList = playAddrModel.originURLList;
						      }

						      if (urlList && urlList.count > 0) {
							      NSURL *url = [NSURL URLWithString:urlList.firstObject];
							      [DYYYManager downloadMedia:url
									       mediaType:MediaTypeVideo
										   audio:audioURL
									      completion:^(BOOL success){
									      }];
						      } else {
							      // 备用方法：直接使用h264URL
							      if (videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
								      NSURL *url = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
								      [DYYYManager downloadMedia:url
										       mediaType:MediaTypeVideo
											   audio:audioURL
										      completion:^(BOOL success){
										      }];
							      }
						      }
					      }
				      }
				    }];
			[actions addObject:downloadAction];

			// 如果是图集，添加下载所有图片选项
			if (isImageContent && awemeModel.albumImages.count > 1) {
				// 检查是否有实况照片
				BOOL hasLivePhoto = NO;
				for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
					if (imageModel.clipVideo != nil) {
						hasLivePhoto = YES;
						break;
					}
				}

				NSString *actionTitle = hasLivePhoto ? @"保存所有实况" : @"保存所有图片";

				AWEUserSheetAction *downloadAllAction = [NSClassFromString(@"AWEUserSheetAction")
				    actionWithTitle:actionTitle
					    imgName:nil
					    handler:^{
					      NSMutableArray *imageURLs = [NSMutableArray array];
					      NSMutableArray *livePhotos = [NSMutableArray array];

					      for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
						      if (imageModel.urlList.count > 0) {
							      // 查找非.image后缀的URL
							      NSURL *downloadURL = nil;
							      for (NSString *urlString in imageModel.urlList) {
								      NSURL *url = [NSURL URLWithString:urlString];
								      NSString *pathExtension = [url.path.lowercaseString pathExtension];
								      if (![pathExtension isEqualToString:@"image"]) {
									      downloadURL = url;
									      break;
								      }
							      }

							      if (!downloadURL && imageModel.urlList.count > 0) {
								      downloadURL = [NSURL URLWithString:imageModel.urlList.firstObject];
							      }

							      // 检查是否是实况照片
							      if (imageModel.clipVideo != nil) {
								      NSURL *videoURL = [imageModel.clipVideo.playURL getDYYYSrcURLDownload];
								      [livePhotos addObject:@{@"imageURL" : downloadURL.absoluteString, @"videoURL" : videoURL.absoluteString}];
							      } else {
								      [imageURLs addObject:downloadURL.absoluteString];
							      }
						      }
					      }

					      // 分别处理普通图片和实况照片
					      if (livePhotos.count > 0) {
						      [DYYYManager downloadAllLivePhotos:livePhotos];
					      }

					      if (imageURLs.count > 0) {
						      [DYYYManager downloadAllImages:imageURLs];
					      }

					      if (livePhotos.count == 0 && imageURLs.count == 0) {
						      [DYYYUtils showToast:@"没有找到合适格式的图片"];
					      }
					    }];
				[actions addObject:downloadAllAction];
			}
		}

		// 添加下载音频选项
		if (DYYYGetBool(@"DYYYDoubleTapDownloadAudio") || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapDownloadAudio"]) {

			AWEUserSheetAction *downloadAudioAction = [NSClassFromString(@"AWEUserSheetAction")
			    actionWithTitle:@"保存音频"
				    imgName:nil
				    handler:^{
				      if (musicModel && musicModel.playURL && musicModel.playURL.originURLList.count > 0) {
					      NSURL *url = [NSURL URLWithString:musicModel.playURL.originURLList.firstObject];
					      [DYYYManager downloadMedia:url mediaType:MediaTypeAudio audio:nil completion:nil];
				      }
				    }];
			[actions addObject:downloadAudioAction];
		}

		// 添加接口保存选项
		if (DYYYGetBool(@"DYYYDoubleInterfaceDownload")) {
			NSString *apiKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYInterfaceDownload"];
			if (apiKey.length > 0) {
				AWEUserSheetAction *apiDownloadAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"接口保存"
															  imgName:nil
															  handler:^{
															    NSString *shareLink = [awemeModel valueForKey:@"shareURL"];
															    if (shareLink.length == 0) {
																    [DYYYUtils showToast:@"无法获取分享链接"];
																    return;
															    }

															    // 使用封装的方法进行解析下载
															    [DYYYManager parseAndDownloadVideoWithShareLink:shareLink apiKey:apiKey];
															  }];
				[actions addObject:apiDownloadAction];
			}
		}

		// 添加制作视频功能
		if (DYYYGetBool(@"DYYYDoubleCreateVideo") || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleCreateVideo"]) {
			if (isImageContent) {
				AWEUserSheetAction *createVideoAction = [NSClassFromString(@"AWEUserSheetAction")
				    actionWithTitle:@"制作视频"
					    imgName:nil
					    handler:^{
					      // 收集普通图片URL
					      NSMutableArray *imageURLs = [NSMutableArray array];
					      // 收集实况照片信息（图片URL+视频URL）
					      NSMutableArray *livePhotos = [NSMutableArray array];

					      // 获取背景音乐URL
					      NSString *bgmURL = nil;
					      if (musicModel && musicModel.playURL && musicModel.playURL.originURLList.count > 0) {
						      bgmURL = musicModel.playURL.originURLList.firstObject;
					      }

					      // 处理所有图片和实况
					      for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
						      if (imageModel.urlList.count > 0) {
							      // 查找非.image后缀的URL
							      NSString *bestURL = nil;
							      for (NSString *urlString in imageModel.urlList) {
								      NSURL *url = [NSURL URLWithString:urlString];
								      NSString *pathExtension = [url.path.lowercaseString pathExtension];
								      if (![pathExtension isEqualToString:@"image"]) {
									      bestURL = urlString;
									      break;
								      }
							      }

							      if (!bestURL && imageModel.urlList.count > 0) {
								      bestURL = imageModel.urlList.firstObject;
							      }

							      // 如果是实况照片，需要收集图片和视频URL
							      if (imageModel.clipVideo != nil) {
								      NSURL *videoURL = [imageModel.clipVideo.playURL getDYYYSrcURLDownload];
								      if (videoURL) {
									      [livePhotos addObject:@{@"imageURL" : bestURL, @"videoURL" : videoURL.absoluteString}];
								      }
							      } else {
								      // 普通图片
								      [imageURLs addObject:bestURL];
							      }
						      }
					      }

					      // 调用视频创建API
					      [DYYYManager createVideoFromMedia:imageURLs
						  livePhotos:livePhotos
						  bgmURL:bgmURL
						  progress:^(NSInteger current, NSInteger total, NSString *status) {
						  }
						  completion:^(BOOL success, NSString *message) {
						    if (success) {
						    } else {
							    [DYYYUtils showToast:[NSString stringWithFormat:@"视频制作失败: %@", message]];
						    }
						  }];
					    }];
				[actions addObject:createVideoAction];
			}
		}

		// 添加复制文案选项
		if (DYYYGetBool(@"DYYYDoubleTapCopyDesc") || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapCopyDesc"]) {

			AWEUserSheetAction *copyTextAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"复制文案"
													       imgName:nil
													       handler:^{
														 NSString *descText = [awemeModel valueForKey:@"descriptionString"];
														 [[UIPasteboard generalPasteboard] setString:descText];
														 [DYYYToast showSuccessToastWithMessage:@"文案已复制"];
													       }];
			[actions addObject:copyTextAction];
		}

		// 添加打开评论区选项
		if (DYYYGetBool(@"DYYYDoubleTapComment") || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapComment"]) {

			AWEUserSheetAction *openCommentAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"打开评论"
														  imgName:nil
														  handler:^{
														    [self performCommentAction];
														  }];
			[actions addObject:openCommentAction];
		}

		// 添加分享选项
		if (DYYYGetBool(@"DYYYDoubleTapshowSharePanel") || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapshowSharePanel"]) {

			AWEUserSheetAction *showSharePanel = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"分享视频"
													       imgName:nil
													       handler:^{
														 [self showSharePanel];
													       }];
			[actions addObject:showSharePanel];
		}

		// 添加点赞视频选项
		if (DYYYGetBool(@"DYYYDoubleTapLike") || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapLike"]) {

			AWEUserSheetAction *likeAction = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"点赞视频"
													   imgName:nil
													   handler:^{
													     [self performLikeAction];
													   }];
			[actions addObject:likeAction];
		}

		// 添加长按面板
		if (DYYYGetBool(@"DYYYDoubleTapshowDislikeOnVideo") || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapshowDislikeOnVideo"]) {

			AWEUserSheetAction *showDislikeOnVideo = [NSClassFromString(@"AWEUserSheetAction") actionWithTitle:@"长按面板"
														   imgName:nil
														   handler:^{
														     [self showDislikeOnVideo];
														   }];
			[actions addObject:showDislikeOnVideo];
		}

		// 显示操作表
		[actionSheet setActions:actions];
		[actionSheet show];

		return;
	}

	// 默认行为
	%orig;
}

%end

%hook AFDPrivacyHalfScreenViewController

%new
- (void)updateDarkModeAppearance {
	BOOL isDarkMode = [DYYYUtils isDarkMode];

	UIView *contentView = self.view.subviews.count > 1 ? self.view.subviews[1] : nil;
	if (contentView) {
		if (isDarkMode) {
			contentView.backgroundColor = [UIColor colorWithRed:0.13 green:0.13 blue:0.13 alpha:1.0];
		} else {
			contentView.backgroundColor = [UIColor whiteColor];
		}
	}

	// 修改标题文本颜色
	if (self.titleLabel) {
		if (isDarkMode) {
			self.titleLabel.textColor = [UIColor whiteColor];
		} else {
			self.titleLabel.textColor = [UIColor blackColor];
		}
	}

	// 修改内容文本颜色
	if (self.contentLabel) {
		if (isDarkMode) {
			self.contentLabel.textColor = [UIColor lightGrayColor];
		} else {
			self.contentLabel.textColor = [UIColor darkGrayColor];
		}
	}

	// 修改左侧按钮颜色和文字颜色
	if (self.leftCancelButton) {
		if (isDarkMode) {
			[self.leftCancelButton setBackgroundColor:[UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1.0]]; // 暗色模式按钮背景色
			[self.leftCancelButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];	       // 暗色模式文字颜色
		} else {
			[self.leftCancelButton setBackgroundColor:[UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0]]; // 默认按钮背景色
			[self.leftCancelButton setTitleColor:[UIColor darkTextColor] forState:UIControlStateNormal];	    // 默认文字颜色
		}
	}
}

- (void)viewDidLoad {
	%orig;
	[self updateDarkModeAppearance];
}

- (void)viewWillAppear:(BOOL)animated {
	%orig;
	[self updateDarkModeAppearance];
}

- (void)configWithImageView:(UIImageView *)imageView
		  lockImage:(UIImage *)lockImage
	   defaultLockState:(BOOL)defaultLockState
	     titleLabelText:(NSString *)titleText
	   contentLabelText:(NSString *)contentText
       leftCancelButtonText:(NSString *)leftButtonText
     rightConfirmButtonText:(NSString *)rightButtonText
       rightBtnClickedBlock:(void (^)(void))rightBtnBlock
     leftButtonClickedBlock:(void (^)(void))leftBtnBlock {

	%orig;
	[self updateDarkModeAppearance];
}

%end

%hook UITextField

- (void)willMoveToWindow:(UIWindow *)newWindow {
	%orig;

	if (newWindow) {
		BOOL isDarkMode = [DYYYUtils isDarkMode];
		self.keyboardAppearance = isDarkMode ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
	}
}

- (BOOL)becomeFirstResponder {
	BOOL isDarkMode = [DYYYUtils isDarkMode];
	self.keyboardAppearance = isDarkMode ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
	return %orig;
}

%end

%hook UITextView

- (void)willMoveToWindow:(UIWindow *)newWindow {
	%orig;

	if (newWindow) {
		BOOL isDarkMode = [DYYYUtils isDarkMode];
		self.keyboardAppearance = isDarkMode ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
	}
}

- (BOOL)becomeFirstResponder {
	BOOL isDarkMode = [DYYYUtils isDarkMode];
	self.keyboardAppearance = isDarkMode ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
	return %orig;
}

%end

// 底栏高度
static CGFloat tabHeight = 0;

static CGFloat customTabBarHeight() {
	NSString *value = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTabBarHeight"];
	if (value.length > 0) {
		CGFloat h = [value floatValue];
		return h > 0 ? h : 0;
	}
	return 0;
}

%hook AWECommentContainerViewController

- (void)viewDidLayoutSubviews {
	%orig;

	BOOL enableCommentBlur = DYYYGetBool(@"DYYYisEnableCommentBlur");
	if (!enableCommentBlur)
		return;

	Class containerViewClass = NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputContainerView");
	UIView *containerView = [DYYYUtils findSubviewOfClass:containerViewClass inView:self.view];
	if (containerView) {
		for (UIView *subview in containerView.subviews) {
			if ([subview isKindOfClass:[UIView class]] && subview.alpha > 0.1f && subview.backgroundColor && CGColorGetAlpha(subview.backgroundColor.CGColor) > 0.1f) {
				float userTransparency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCommentBlurTransparent"] floatValue];
				if (userTransparency <= 0 || userTransparency > 1) {
					userTransparency = 0.8;
				}
				[DYYYUtils applyBlurEffectToView:subview transparency:userTransparency blurViewTag:999];
				[DYYYUtils clearBackgroundRecursivelyInView:subview];
			}
		}
	}

	Class middleContainerClass = NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputViewMiddleContainer");
	NSArray<UIView *> *middleContainers = [DYYYUtils findAllSubviewsOfClass:middleContainerClass inView:self.view];
	for (UIView *middleContainer in middleContainers) {
		BOOL containsDanmu = NO;
		for (UIView *innerSubviewCheck in middleContainer.subviews) {
			if ([innerSubviewCheck isKindOfClass:[UILabel class]] && [((UILabel *)innerSubviewCheck).text containsString:@"弹幕"]) {
				containsDanmu = YES;
				break;
			}
		}

		if (containsDanmu) {
			UIView *parentView = middleContainer.superview;
			for (UIView *innerSubview in parentView.subviews) {
				if ([innerSubview isKindOfClass:[UIView class]]) {
					// NSLog(@"[innerSubview] %@", innerSubview);
					if (innerSubview.subviews.count > 0) {
						[innerSubview.subviews[0] removeFromSuperview];
					}

					UIView *whiteBackgroundView = [[UIView alloc] initWithFrame:innerSubview.bounds];
					whiteBackgroundView.backgroundColor = [UIColor whiteColor];
					whiteBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
					[innerSubview addSubview:whiteBackgroundView];
					break;
				}
			}
		} else {
			for (UIView *innerSubview in middleContainer.subviews) {
				if ([innerSubview isKindOfClass:[UIView class]] && innerSubview.alpha > 0.1f && innerSubview.backgroundColor &&
				    CGColorGetAlpha(innerSubview.backgroundColor.CGColor) > 0.1f) {
					[DYYYUtils applyBlurEffectToView:innerSubview transparency:0.2f blurViewTag:999];
					[DYYYUtils clearBackgroundRecursivelyInView:innerSubview];
					break;
				}
			}
		}
	}
}

%end

%hook UIView
- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYisEnableFullScreen")) {
		if (self.frame.size.height == tabHeight && tabHeight > 0) {
			UIViewController *vc = [DYYYUtils firstAvailableViewControllerFromView:self];
			if ([vc isKindOfClass:NSClassFromString(@"AWEMixVideoPanelDetailTableViewController")] || [vc isKindOfClass:NSClassFromString(@"AWECommentInputViewController")] ||
			    [vc isKindOfClass:NSClassFromString(@"AWEAwemeDetailTableViewController")]) {
				self.backgroundColor = [UIColor clearColor];
			}
		}
	}

	if (DYYYGetBool(@"DYYYisEnableFullScreen") || DYYYGetBool(@"DYYYisEnableCommentBlur")) {
		UIViewController *vc = [DYYYUtils firstAvailableViewControllerFromView:self];
		if ([vc isKindOfClass:%c(AWEPlayInteractionViewController)]) {
			for (UIView *subview in self.subviews) {
				if ([subview isKindOfClass:[UIView class]] && subview.backgroundColor && CGColorEqualToColor(subview.backgroundColor.CGColor, [UIColor blackColor].CGColor)) {
					subview.hidden = YES;
				}
			}
		}
	}
}

- (void)setFrame:(CGRect)frame {
	if (![NSThread isMainThread]) {
		dispatch_async(dispatch_get_main_queue(), ^{
		  [self setFrame:frame];
		});
		return;
	}

	BOOL enableBlur = DYYYGetBool(@"DYYYisEnableCommentBlur");
	BOOL enableFS = DYYYGetBool(@"DYYYisEnableFullScreen");
	BOOL hideAvatar = DYYYGetBool(@"DYYYisHiddenAvatarList");

	Class SkylightListViewClass = NSClassFromString(@"AWEIMSkylightListView");
	if (hideAvatar && SkylightListViewClass && [self isKindOfClass:SkylightListViewClass]) {
		frame = CGRectZero;
		%orig(frame);
		return;
	}

	UIViewController *vc = [DYYYUtils firstAvailableViewControllerFromView:self];
	Class DetailVCClass = NSClassFromString(@"AWEMixVideoPanelDetailTableViewController");
	Class PlayVCClass1 = NSClassFromString(@"AWEAwemePlayVideoViewController");
	Class PlayVCClass2 = NSClassFromString(@"AWEDPlayerFeedPlayerViewController");

	BOOL isDetailVC = (DetailVCClass && [vc isKindOfClass:DetailVCClass]);
	BOOL isPlayVC = ((PlayVCClass1 && [vc isKindOfClass:PlayVCClass1]) || (PlayVCClass2 && [vc isKindOfClass:PlayVCClass2]));

	if (isPlayVC && enableBlur) {
		if (frame.origin.x != 0) {
			return;
		}
	}

	if (isPlayVC && enableFS) {
		if (frame.origin.x != 0 && frame.origin.y != 0) {
			%orig(frame);
			return;
		}
		CGRect superF = self.superview.frame;
		if (CGRectGetHeight(superF) > 0 && CGRectGetHeight(frame) > 0 && CGRectGetHeight(frame) < CGRectGetHeight(superF)) {
			CGFloat diff = CGRectGetHeight(superF) - CGRectGetHeight(frame);
			if (fabs(diff - tabHeight) < 1.0) {
				frame.size.height = CGRectGetHeight(superF);
			}
		}
		%orig(frame);
		return;
	}

	%orig(frame);
}

%end

%hook AWEPlayInteractionViewController
- (void)viewDidLayoutSubviews {
	%orig;

	UIViewController *parentVC = self.parentViewController;
	while (parentVC) {
		if ([parentVC isKindOfClass:%c(AFDPlayRemoteFeedTableViewController)]) {
			return;
		}
		parentVC = parentVC.parentViewController;
	}

	if (DYYYGetBool(@"DYYYisEnableFullScreen")) {
		NSString *currentReferString = self.referString;
		CGRect frame = self.view.frame;

		// 根据referString来决定是否减去高度差值
		if ([currentReferString isEqualToString:@"general_search"]) {
			frame.size.height = self.view.superview.frame.size.height;
		} else if ([currentReferString isEqualToString:@"chat"] || currentReferString == nil) {
			frame.size.height = self.view.superview.frame.size.height;
		} else if ([currentReferString isEqualToString:@"search_result"] || currentReferString == nil) {
			frame.size.height = self.view.superview.frame.size.height;
		} else if ([currentReferString isEqualToString:@"close_friends_moment"] || currentReferString == nil) {
			frame.size.height = self.view.superview.frame.size.height;
		} else if ([currentReferString isEqualToString:@"offline_mode"] || currentReferString == nil) {
			frame.size.height = self.view.superview.frame.size.height;
		} else if ([currentReferString isEqualToString:@"challenge"] || currentReferString == nil) {
			frame.size.height = self.view.superview.frame.size.height;
		} else if ([currentReferString isEqualToString:@"others_homepage"] || currentReferString == nil) {
			frame.size.height = self.view.superview.frame.size.height - tabHeight;
		} else {
			frame.size.height = self.view.superview.frame.size.height - tabHeight;
		}

		self.view.frame = frame;
	}
}

%end

%hook AWEDPlayerFeedPlayerViewController

- (void)viewDidLayoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYisEnableFullScreen")) {
		UIView *contentView = self.contentView;
		if (contentView && contentView.superview) {
			CGRect frame = contentView.frame;
			CGFloat parentHeight = contentView.superview.frame.size.height;

			if (frame.size.height == parentHeight - tabHeight) {
				frame.size.height = parentHeight;
				contentView.frame = frame;
			} else if (frame.size.height == parentHeight - (tabHeight * 2)) {
				frame.size.height = parentHeight - tabHeight;
				contentView.frame = frame;
			}
		}
	}
}

%end

%hook AWEFeedTableView
- (void)layoutSubviews {
	%orig;
	CGFloat customHeight = customTabBarHeight();
	BOOL enableFS = DYYYGetBool(@"DYYYisEnableFullScreen");

	if (enableFS || customHeight > 0) {
		if (self.superview) {
			CGFloat diff = self.superview.frame.size.height - self.frame.size.height;
			if (diff > 0 && diff != tabHeight) {
				tabHeight = diff;
			}
		}

		CGRect frame = self.frame;
		if (enableFS) {
			frame.size.height = self.superview.frame.size.height;
		} else if (customHeight > 0) {
			frame.size.height = self.superview.frame.size.height - customHeight;
		}
		self.frame = frame;
	}
}
%end

%hook AWEElementStackView
static CGFloat currentScale = 1.0;
- (void)layoutSubviews {
	%orig;
	UIViewController *vc = [DYYYUtils firstAvailableViewControllerFromView:self];
	if ([vc isKindOfClass:%c(AWECommentInputViewController)]) {
		NSString *transparentValue = DYYYGetString(@"DYYYGlobalTransparency");
		if (transparentValue.length > 0) {
			CGFloat alphaValue = transparentValue.floatValue;
			if (alphaValue >= 0.0 && alphaValue <= 1.0) {
				self.alpha = alphaValue;
			}
		}
	}
	if ([vc isKindOfClass:%c(AWELiveNewPreStreamViewController)]) {
		NSString *transparentValue = DYYYGetString(@"DYYYGlobalTransparency");
		if (transparentValue.length > 0) {
			CGFloat alphaValue = transparentValue.floatValue;
			if (alphaValue >= 0.0 && alphaValue <= 1.0) {
				self.alpha = alphaValue;
			}
		}
	}
	// 处理视频流直播间文案缩放
	UIResponder *nextResponder = [self nextResponder];
	if ([nextResponder isKindOfClass:[UIView class]]) {
		UIView *parentView = (UIView *)nextResponder;
		UIViewController *viewController = [DYYYUtils firstAvailableViewControllerFromView:parentView];
		if ([viewController isKindOfClass:%c(AWELiveNewPreStreamViewController)]) {
			NSString *vcScaleValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYNicknameScale"];
			if (vcScaleValue.length > 0) {
				CGFloat scale = [vcScaleValue floatValue];
				self.transform = CGAffineTransformIdentity;
				if (scale > 0 && scale != 1.0) {
					NSArray *subviews = [self.subviews copy];
					CGFloat ty = 0;
					for (UIView *view in subviews) {
						CGFloat viewHeight = view.frame.size.height;
						CGFloat contribution = (viewHeight - viewHeight * scale) / 2;
						ty += contribution;
					}
					CGFloat frameWidth = self.frame.size.width;
					CGFloat tx = (frameWidth - frameWidth * scale) / 2 - frameWidth * (1 - scale);
					CGAffineTransform newTransform = CGAffineTransformMakeScale(scale, scale);
					newTransform = CGAffineTransformTranslate(newTransform, tx / scale, ty / scale);
					self.transform = newTransform;
				}
			}
		}
	}
	if (DYYYGetBool(@"DYYYisEnableFullScreen")) {
		UIResponder *nextResponder = [self nextResponder];
		if ([nextResponder isKindOfClass:[UIView class]]) {
			UIView *parentView = (UIView *)nextResponder;
			UIViewController *viewController = [DYYYUtils firstAvailableViewControllerFromView:parentView];
			if ([viewController isKindOfClass:%c(AWELiveNewPreStreamViewController)]) {
				CGRect frame = self.frame;
				frame.origin.y -= tabHeight;
				self.frame = frame;
			}
		}
	}

	UIViewController *viewController = [DYYYUtils firstAvailableViewControllerFromView:self];
	if ([viewController isKindOfClass:%c(AWEPlayInteractionViewController)]) {

		// 右侧元素的处理逻辑
		if ([self.accessibilityLabel isEqualToString:@"right"] || [DYYYUtils containsSubviewOfClass:NSClassFromString(@"AWEPlayInteractionUserAvatarView") inView:self]) {
			NSString *scaleValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYElementScale"];
			self.transform = CGAffineTransformIdentity;
			if (scaleValue.length > 0) {
				CGFloat scale = [scaleValue floatValue];
				if (currentScale != scale)
					currentScale = scale;
				if (scale > 0 && scale != 1.0) {
					NSArray *subviews = [self.subviews copy];
					CGFloat ty = 0;
					for (UIView *view in subviews) {
						CGFloat viewHeight = view.frame.size.height;
						ty += (viewHeight - viewHeight * scale) / 2;
					}
					CGFloat frameWidth = self.frame.size.width;
					CGFloat right_tx = (frameWidth - frameWidth * scale) / 2;
					self.transform = CGAffineTransformMake(scale, 0, 0, scale, right_tx, ty);
				} else {
					self.transform = CGAffineTransformIdentity;
				}
			}
		}
		// 左侧元素的处理逻辑
		else if ([self.accessibilityLabel isEqualToString:@"left"] || [DYYYUtils containsSubviewOfClass:NSClassFromString(@"AWEFeedAnchorContainerView") inView:self]) {
			NSString *scaleValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYNicknameScale"];
			if (scaleValue.length > 0) {
				CGFloat scale = [scaleValue floatValue];
				self.transform = CGAffineTransformIdentity;
				if (scale > 0 && scale != 1.0) {
					NSArray *subviews = [self.subviews copy];
					CGFloat ty = 0;
					for (UIView *view in subviews) {
						CGFloat viewHeight = view.frame.size.height;
						ty += (viewHeight - viewHeight * scale) / 2;
					}
					CGFloat frameWidth = self.frame.size.width;
					CGFloat left_tx = (frameWidth - frameWidth * scale) / 2 - frameWidth * (1 - scale);
					CGAffineTransform newTransform = CGAffineTransformMakeScale(scale, scale);
					newTransform = CGAffineTransformTranslate(newTransform, left_tx / scale, ty / scale);
					self.transform = newTransform;
				}
			}
		}
	}
}
- (NSArray<__kindof UIView *> *)arrangedSubviews {

	UIViewController *viewController = [DYYYUtils firstAvailableViewControllerFromView:self];
	if ([viewController isKindOfClass:%c(AWEPlayInteractionViewController)]) {

		if ([self.accessibilityLabel isEqualToString:@"left"] || [DYYYUtils containsSubviewOfClass:NSClassFromString(@"AWEFeedAnchorContainerView") inView:self]) {
			NSString *scaleValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYNicknameScale"];
			if (scaleValue.length > 0) {
				CGFloat scale = [scaleValue floatValue];
				self.transform = CGAffineTransformIdentity;
				if (scale > 0 && scale != 1.0) {
					NSArray *subviews = [self.subviews copy];
					CGFloat ty = 0;
					for (UIView *view in subviews) {
						CGFloat viewHeight = view.frame.size.height;
						ty += (viewHeight - viewHeight * scale) / 2;
					}
					CGFloat frameWidth = self.frame.size.width;
					CGFloat left_tx = (frameWidth - frameWidth * scale) / 2 - frameWidth * (1 - scale);
					CGAffineTransform newTransform = CGAffineTransformMakeScale(scale, scale);
					newTransform = CGAffineTransformTranslate(newTransform, left_tx / scale, ty / scale);
					self.transform = newTransform;
				}
			}
		}
	}

	NSArray *originalSubviews = %orig;
	return originalSubviews;
}
%end

%hook HTSEventForwardingView

static const void *kDyHasTransformedKey = &kDyHasTransformedKey;

- (void)layoutSubviews {
    %orig;

	NSString *transparentValue = DYYYGetString(@"DYYYGlobalTransparency");
	if (transparentValue.length > 0) {
		CGFloat alphaValue = transparentValue.floatValue;
		if (alphaValue >= 0.0 && alphaValue <= 1.0) {
			self.alpha = alphaValue;
		}
	}

    UIResponder *nextResponder = [self nextResponder];
    if (![nextResponder isKindOfClass:[UIView class]]) return;

    UIView *parentView = (UIView *)nextResponder;
    UIViewController *viewController = [parentView firstAvailableUIViewController];

    if ([viewController isKindOfClass:%c(AWELiveNewPreStreamViewController)] &&
        [[self levelName] isEqualToString:@"content"]) {

        if ([objc_getAssociatedObject(self, kDyHasTransformedKey) boolValue]) {
            return;
        }

        NSString *vcScaleValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYNicknameScale"];
        CGFloat scale = 1.0;
        if (vcScaleValue.length > 0) {
            scale = [vcScaleValue floatValue];
            if (scale <= 0) scale = 1.0; 
        }

        BOOL shouldShiftUp = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"];

        if (scale != 1.0 || shouldShiftUp) {
            
            CGAffineTransform finalTransform = self.transform;

            if (scale != 1.0) {
                NSArray *subviews = [self.subviews copy];
                CGFloat ty = 0;
                for (UIView *view in subviews) {
                    CGFloat viewHeight = view.frame.size.height;
                    CGFloat contribution = (viewHeight - viewHeight * scale) / 2;
                    ty += contribution;
                }
                CGFloat frameWidth = self.frame.size.width;
                CGFloat tx = (frameWidth - frameWidth * scale) / 2 - frameWidth * (1 - scale);

                CGAffineTransform scaleTransform = CGAffineTransformMakeScale(scale, scale);
                finalTransform = CGAffineTransformTranslate(scaleTransform, tx / scale, ty / scale);
            }

            if (shouldShiftUp) {
                finalTransform = CGAffineTransformTranslate(finalTransform, 0, -83 / (scale > 0 ? scale : 1.0));
            }

            self.transform = finalTransform;

            objc_setAssociatedObject(self, kDyHasTransformedKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}
%end
%hook AWEStoryContainerCollectionView
- (void)layoutSubviews {
	%orig;
	if ([self.subviews count] == 2)
		return;

	// 获取 enableEnterProfile 属性来判断是否是主页
	id enableEnterProfile = [self valueForKey:@"enableEnterProfile"];
	BOOL isHome = (enableEnterProfile != nil && [enableEnterProfile boolValue]);

	// 检查是否在作者主页
	BOOL isAuthorProfile = NO;
	UIResponder *responder = self;
	while ((responder = [responder nextResponder])) {
		if ([NSStringFromClass([responder class]) containsString:@"UserHomeViewController"] || [NSStringFromClass([responder class]) containsString:@"ProfileViewController"]) {
			isAuthorProfile = YES;
			break;
		}
	}

	// 如果不是主页也不是作者主页，直接返回
	if (!isHome && !isAuthorProfile)
		return;

	for (UIView *subview in self.subviews) {
		if ([subview isKindOfClass:[UIView class]]) {
			UIView *nextResponder = (UIView *)subview.nextResponder;

			// 处理主页的情况
			if (isHome && [nextResponder isKindOfClass:%c(AWEPlayInteractionViewController)]) {
				UIViewController *awemeBaseViewController = [nextResponder valueForKey:@"awemeBaseViewController"];
				if (![awemeBaseViewController isKindOfClass:%c(AWEFeedCellViewController)]) {
					continue;
				}

				CGRect frame = subview.frame;
				if (DYYYGetBool(@"DYYYisEnableFullScreen")) {
					frame.size.height = subview.superview.frame.size.height - tabHeight;
					subview.frame = frame;
				}
			}
			// 处理作者主页的情况
			else if (isAuthorProfile) {
				// 检查是否是作品图片
				BOOL isWorkImage = NO;

				// 可以通过检查子视图、标签或其他特性来确定是否是作品图片
				for (UIView *childView in subview.subviews) {
					if ([NSStringFromClass([childView class]) containsString:@"ImageView"] || [NSStringFromClass([childView class]) containsString:@"ThumbnailView"]) {
						isWorkImage = YES;
						break;
					}
				}

				if (isWorkImage) {
					// 修复作者主页作品图片上移问题
					CGRect frame = subview.frame;
					frame.origin.y += tabHeight;
					subview.frame = frame;
				}
			}
		}
	}
}
%end

%hook AFDFastSpeedView
- (void)layoutSubviews {
	%orig;

	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"]) {
		return;
	}

	static char kDYFastSpeedBgKey;
	NSArray *bgViews = objc_getAssociatedObject(self, &kDYFastSpeedBgKey);
	if (!bgViews) {
		NSMutableArray *tmp = [NSMutableArray array];
		for (UIView *subview in self.subviews) {
			if ([subview class] == [UIView class]) {
				[tmp addObject:subview];
			}
		}
		bgViews = [tmp copy];
		objc_setAssociatedObject(self, &kDYFastSpeedBgKey, bgViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	for (UIView *view in bgViews) {
		view.backgroundColor = [UIColor clearColor];
	}
}
%end

%hook AWELandscapeFeedEntryView
- (void)setCenter:(CGPoint)center {
	if (DYYYGetBool(@"DYYYisEnableFullScreen")) {
		center.y += 50;
	}

	%orig(center);
}

- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYisHiddenEntry")) {
		[self removeFromSuperview];
	}
}

%end

%hook AWENormalModeTabBar

- (void)layoutSubviews {
	%orig;

	CGFloat h = customTabBarHeight();
	if (h > 0) {
		if ([self respondsToSelector:@selector(setDesiredHeight:)]) {
			((void (*)(id, SEL, double))objc_msgSend)(self, @selector(setDesiredHeight:), h);
		}
		CGRect frame = self.frame;
		if (fabs(frame.size.height - h) > 0.5) {
			frame.size.height = h;
			if (self.superview) {
				frame.origin.y = self.superview.bounds.size.height - h;
			}
			self.frame = frame;
		}
	}

	BOOL hideShop = DYYYGetBool(@"DYYYHideShopButton");
	BOOL hideMsg = DYYYGetBool(@"DYYYHideMessageButton");
	BOOL hideFri = DYYYGetBool(@"DYYYHideFriendsButton");
	BOOL hideMe = DYYYGetBool(@"DYYYHideMyButton");

	NSMutableArray *visibleButtons = [NSMutableArray array];
	Class generalButtonClass = %c(AWENormalModeTabBarGeneralButton);
	Class plusButtonClass = %c(AWENormalModeTabBarGeneralPlusButton);
	Class tabBarButtonClass = %c(UITabBarButton);

	for (UIView *subview in self.subviews) {
		if (![subview isKindOfClass:generalButtonClass] && ![subview isKindOfClass:plusButtonClass])
			continue;

		NSString *label = subview.accessibilityLabel;
		BOOL shouldHide = NO;

		if ([label isEqualToString:@"商城"]) {
			shouldHide = hideShop;
		} else if ([label containsString:@"消息"]) {
			shouldHide = hideMsg;
		} else if ([label containsString:@"朋友"]) {
			shouldHide = hideFri;
		} else if ([label containsString:@"我"]) {
			shouldHide = hideMe;
		}

		if (!shouldHide) {
			[visibleButtons addObject:subview];
		} else {
			subview.userInteractionEnabled = NO;
			[subview removeFromSuperview];
		}
	}

	for (UIView *subview in self.subviews) {
		if (![subview isKindOfClass:tabBarButtonClass])
			continue;
		subview.userInteractionEnabled = NO;
		[subview removeFromSuperview];
	}

	[visibleButtons sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
	  return [@(a.frame.origin.x) compare:@(b.frame.origin.x)];
	}];

	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		// iPad端布局逻辑
		UIView *targetView = nil;
		CGFloat containerWidth = self.bounds.size.width;
		CGFloat offsetX = 0;

		// 查找目标容器视图
		for (UIView *subview in self.subviews) {
			if ([subview class] == [UIView class] && fabs(subview.frame.size.width - self.bounds.size.width) > 0.1) {
				targetView = subview;
				containerWidth = subview.frame.size.width;
				offsetX = subview.frame.origin.x;
				break;
			}
		}

		// 在目标容器内均匀分布按钮
		CGFloat buttonWidth = containerWidth / visibleButtons.count;
		for (NSInteger i = 0; i < visibleButtons.count; i++) {
			UIView *button = visibleButtons[i];
			button.frame = CGRectMake(offsetX + (i * buttonWidth), button.frame.origin.y, buttonWidth, button.frame.size.height);
		}
	} else {
		// iPhone端布局逻辑
		CGFloat totalWidth = self.bounds.size.width;
		CGFloat buttonWidth = totalWidth / visibleButtons.count;

		for (NSInteger i = 0; i < visibleButtons.count; i++) {
			UIView *button = visibleButtons[i];
			button.frame = CGRectMake(i * buttonWidth, button.frame.origin.y, buttonWidth, button.frame.size.height);
		}
	}
}

- (void)setHidden:(BOOL)hidden {
	%orig(hidden);

	Class generalButtonClass = %c(AWENormalModeTabBarGeneralButton);
	BOOL disableHomeRefresh = DYYYGetBool(@"DYYYDisableHomeRefresh");

	for (UIView *subview in self.subviews) {
		if ([subview isKindOfClass:generalButtonClass]) {
			AWENormalModeTabBarGeneralButton *button = (AWENormalModeTabBarGeneralButton *)subview;
			if ([button.accessibilityLabel isEqualToString:@"首页"] && disableHomeRefresh) {
				button.userInteractionEnabled = (button.status != 2);
			}
		}
	}

	BOOL hideBottomBg = DYYYGetBool(@"DYYYisHiddenBottomBg");

	// 如果开启了隐藏底部背景，则直接隐藏背景视图
	if (hideBottomBg) {
		UIView *backgroundView = nil;
		for (UIView *subview in self.subviews) {
			if ([subview class] == [UIView class]) {
				BOOL hasImageView = NO;
				for (UIView *childView in subview.subviews) {
					if ([childView isKindOfClass:[UIImageView class]]) {
						hasImageView = YES;
						break;
					}
				}
				if (hasImageView) {
					backgroundView = subview;
					backgroundView.hidden = YES;
					break;
				}
			}
		}
	} else {
		// 仅对全屏模式处理背景显示逻辑
		if (DYYYGetBool(@"DYYYisEnableFullScreen")) {
			UIView *backgroundView = nil;
			BOOL hideFriendsButton = DYYYGetBool(@"DYYYHideFriendsButton");
			BOOL isHomeSelected = NO;
			BOOL isFriendsSelected = NO;

			for (UIView *subview in self.subviews) {
				if ([subview class] == [UIView class]) {
					BOOL hasImageView = NO;
					for (UIView *childView in subview.subviews) {
						if ([childView isKindOfClass:[UIImageView class]]) {
							hasImageView = YES;
							break;
						}
					}
					if (hasImageView) {
						backgroundView = subview;
						break;
					}
				}
			}

			// 查找当前选中的按钮
			for (UIView *subview in self.subviews) {
				if ([subview isKindOfClass:generalButtonClass]) {
					AWENormalModeTabBarGeneralButton *button = (AWENormalModeTabBarGeneralButton *)subview;
					// status == 2 表示按钮处于选中状态
					if (button.status == 2) {
						if ([button.accessibilityLabel isEqualToString:@"首页"]) {
							isHomeSelected = YES;
						} else if ([button.accessibilityLabel containsString:@"朋友"]) {
							isFriendsSelected = YES;
						}
					}
				}
			}

			// 根据当前选中的按钮决定是否显示背景
			if (backgroundView) {
				BOOL shouldShowBackground = isHomeSelected || (isFriendsSelected && !hideFriendsButton);
				backgroundView.hidden = shouldShowBackground;
			}
		}
	}

	// 隐藏分隔线
	if (DYYYGetBool(@"DYYYisEnableFullScreen")) {
		for (UIView *subview in self.subviews) {
			if (![subview isKindOfClass:[UIView class]])
				continue;
			if (subview.frame.size.height <= 0.5 && subview.frame.size.width > 300) {
				subview.hidden = YES;
				CGRect frame = subview.frame;
				frame.size.height = 0;
				subview.frame = frame;
				subview.alpha = 0;
			}
		}
	}
}

%end

%hook AWEAwemeDetailTableView

- (void)setFrame:(CGRect)frame {
	if (DYYYGetBool(@"DYYYisEnableFullScreen")) {
		CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;

		CGFloat remainder = fmod(frame.size.height, screenHeight);
		if (remainder != 0) {
			frame.size.height += (screenHeight - remainder);
		}
	}
	%orig(frame);
}

%end

%hook AWEMixVideoPanelMoreView

- (void)setFrame:(CGRect)frame {
	if (DYYYGetBool(@"DYYYisEnableFullScreen")) {
		CGFloat targetY = frame.origin.y - tabHeight;
		CGFloat screenHeightMinusGDiff = [UIScreen mainScreen].bounds.size.height - tabHeight;

		CGFloat tolerance = 10.0;

		if (fabs(targetY - screenHeightMinusGDiff) <= tolerance) {
			frame.origin.y = targetY;
		}
	}
	%orig(frame);
}

- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYisEnableFullScreen")) {
		self.backgroundColor = [UIColor clearColor];
	}
}

%end

%hook CommentInputContainerView

- (void)layoutSubviews {
	%orig;
	UIViewController *parentVC = nil;
	if ([self respondsToSelector:@selector(viewController)]) {
		id viewController = [self performSelector:@selector(viewController)];
		if ([viewController respondsToSelector:@selector(parentViewController)]) {
			parentVC = [viewController parentViewController];
		}
	}

	if (parentVC && ([parentVC isKindOfClass:%c(AWEAwemeDetailTableViewController)] || [parentVC isKindOfClass:%c(AWEAwemeDetailCellViewController)])) {
		static char kDYCommentHideCacheKey;
		UIView *target = objc_getAssociatedObject(self, &kDYCommentHideCacheKey);
		if (!target) {
			for (UIView *subview in [self subviews]) {
				if ([subview class] == [UIView class]) {
					target = subview;
					objc_setAssociatedObject(self, &kDYCommentHideCacheKey, target, OBJC_ASSOCIATION_ASSIGN);
					break;
				}
			}
		}
		if (target) {
			target.hidden = ([(UIView *)self frame].size.height == tabHeight);
		}
	}
}

%end

// 聊天视频底部评论框背景透明
%hook AWEIMFeedBottomQuickEmojiInputBar

- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYisEnableFullScreen")) {
		UIView *parentView = self.superview;
		while (parentView) {
			if ([NSStringFromClass([parentView class]) isEqualToString:@"UIView"]) {
				dispatch_async(dispatch_get_main_queue(), ^{
				  parentView.backgroundColor = [UIColor clearColor];
				  parentView.layer.backgroundColor = [UIColor clearColor].CGColor;
				  parentView.opaque = NO;
				});
				break;
			}
			parentView = parentView.superview;
		}
	}
}

%end

// 隐藏章节进度条
%hook AWEDemaciaChapterProgressSlider

- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYHideChapterProgress")) {
		[self removeFromSuperview];
	}
}

%end

// 隐藏上次看到
%hook DUXPopover
- (void)layoutSubviews {
	%orig;

	if (!DYYYGetBool(@"DYYYHidePopover")) {
		return;
	}

	id rawContent = nil;
	@try {
		rawContent = [self valueForKey:@"content"];
	} @catch (__unused NSException *e) {
		return;
	}

	NSString *text = [rawContent isKindOfClass:NSString.class] ? (NSString *)rawContent : [rawContent description];

	if ([text containsString:@"上次看到"]) {
		[self removeFromSuperview];
	}
}
%end

// 隐藏双栏入口
%hook AWENormalModeTabBarFeedView
- (void)layoutSubviews {
	%orig;
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDoubleColumnEntry"]) {
		return;
	}

	static char kDYDoubleColumnCacheKey;
	static char kDYDoubleColumnCountKey;
	NSArray *cachedViews = objc_getAssociatedObject(self, &kDYDoubleColumnCacheKey);
	NSNumber *cachedCount = objc_getAssociatedObject(self, &kDYDoubleColumnCountKey);
	if (!cachedViews || cachedCount.unsignedIntegerValue != self.subviews.count) {
		NSMutableArray *views = [NSMutableArray array];
		for (UIView *subview in self.subviews) {
			if (![subview isKindOfClass:[UILabel class]]) {
				[views addObject:subview];
			}
		}
		cachedViews = [views copy];
		objc_setAssociatedObject(self, &kDYDoubleColumnCacheKey, cachedViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		objc_setAssociatedObject(self, &kDYDoubleColumnCountKey, @(self.subviews.count), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	for (UIView *v in cachedViews) {
		v.hidden = YES;
	}
}
%end

%hook UIImageView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHideCommentDiscover")) {
		if (!self.accessibilityLabel) {
			UIView *parentView = self.superview;

			if (parentView && [parentView class] == [UIView class] && [parentView.accessibilityLabel isEqualToString:@"搜索"]) {
				self.hidden = YES;
			}

			else if (parentView && [NSStringFromClass([parentView class]) isEqualToString:@"AWESearchEntryHalfScreenElement"] && [parentView.accessibilityLabel isEqualToString:@"搜索"]) {
				self.hidden = YES;
			}
		}
	}
}
%end

// 移除极速版我的片面红包横幅
%hook AWELuckyCatBannerView
- (id)initWithFrame:(CGRect)frame {
	return nil;
}

- (id)init {
	return nil;
}
%end

static NSMutableDictionary *keepCellsInfo;
static NSMutableDictionary *sectionKeepInfo;

static NSString *const kAWELeftSideBarTopRightLayoutView = @"AWELeftSideBarTopRightLayoutView";
static NSString *const kAWELeftSideBarFunctionContainerView = @"AWELeftSideBarFunctionContainerView";
static NSString *const kAWELeftSideBarWeatherView = @"AWELeftSideBarWeatherView";

static NSString *const kStreamlineSidebarKey = @"DYYYStreamlinethesidebar";

%hook AWELeftSideBarViewController

- (void)viewDidLoad {
	%orig;

	if (!DYYYGetBool(kStreamlineSidebarKey)) {
		return;
	}

	if (!keepCellsInfo) {
		keepCellsInfo = [NSMutableDictionary dictionary];
	}
	if (!sectionKeepInfo) {
		sectionKeepInfo = [NSMutableDictionary dictionary];
	}
}

- (void)viewDidDisappear:(BOOL)animated {
	%orig;

	if (!DYYYGetBool(kStreamlineSidebarKey)) {
		return;
	}

	[keepCellsInfo removeAllObjects];
	[sectionKeepInfo removeAllObjects];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
	UICollectionViewCell *cell = %orig;

	if (!DYYYGetBool(kStreamlineSidebarKey)) {
		return cell;
	}

	if (!cell)
		return cell;

	@try {
		BOOL shouldKeep = [DYYYUtils containsSubviewOfClass:NSClassFromString(kAWELeftSideBarTopRightLayoutView) inView:cell.contentView] ||
				  [DYYYUtils containsSubviewOfClass:NSClassFromString(kAWELeftSideBarFunctionContainerView) inView:cell.contentView] ||
				  [DYYYUtils containsSubviewOfClass:NSClassFromString(kAWELeftSideBarWeatherView) inView:cell.contentView];

		NSString *key = [NSString stringWithFormat:@"%ld-%ld", (long)indexPath.section, (long)indexPath.row];
		keepCellsInfo[key] = @(shouldKeep);
		if (shouldKeep) {
			sectionKeepInfo[@(indexPath.section)] = @YES;
		} else if (!sectionKeepInfo[@(indexPath.section)]) {
			sectionKeepInfo[@(indexPath.section)] = @NO;
		}

		if (!shouldKeep) {
			cell.hidden = YES;
			cell.alpha = 0;
			CGRect frame = cell.frame;
			frame.size.width = 0;
			frame.size.height = 0;
			cell.frame = frame;
		} else if ([DYYYUtils containsSubviewOfClass:NSClassFromString(kAWELeftSideBarFunctionContainerView) inView:cell.contentView]) {
			[self adjustContainerViewLayout:cell];
		}
	} @catch (NSException *exception) {
		NSLog(@"Error in cellForItemAtIndexPath: %@", exception);
	}

	return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(id)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
	CGSize originalSize = %orig;

	if (!DYYYGetBool(kStreamlineSidebarKey)) {
		return originalSize;
	}

	NSString *key = [NSString stringWithFormat:@"%ld-%ld", (long)indexPath.section, (long)indexPath.row];
	NSNumber *shouldKeep = keepCellsInfo[key];

	if (shouldKeep != nil && ![shouldKeep boolValue]) {
		return CGSizeZero;
	}

	return originalSize;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(id)layout insetForSectionAtIndex:(NSInteger)section {
	UIEdgeInsets originalInsets = %orig;

	if (!DYYYGetBool(kStreamlineSidebarKey)) {
		return originalInsets;
	}

	BOOL hasKeepCells = [sectionKeepInfo[@(section)] boolValue];

	if (!hasKeepCells) {
		return UIEdgeInsetsZero;
	}

	return originalInsets;
}

%new
- (void)adjustContainerViewLayout:(UICollectionViewCell *)containerCell {
	if (!DYYYGetBool(kStreamlineSidebarKey)) {
		return;
	}

	UICollectionView *collectionView = [self collectionView];
	if (!collectionView || !containerCell)
		return;

	UIView *containerView = [DYYYUtils findSubviewOfClass:NSClassFromString(kAWELeftSideBarFunctionContainerView) inView:containerCell.contentView];
	if (!containerView)
		return;

	CGFloat windowHeight = collectionView.window.bounds.size.height;
	CGFloat currentY = [containerCell convertPoint:containerCell.bounds.origin toView:nil].y;
	CGFloat newHeight = windowHeight - currentY - 20;

	CGRect containerFrame = containerView.frame;
	containerFrame.size.height = newHeight;
	containerView.frame = containerFrame;

	CGRect cellFrame = containerCell.frame;
	cellFrame.size.height = newHeight;
	containerCell.frame = cellFrame;
}

%end

%hook AWESettingsTableViewController
- (void)viewDidLoad {
	%orig;

	if (DYYYGetBool(@"DYYYHideSettingsAbout")) {
		[self removeAboutSection];
	}
}

%new
- (void)removeAboutSection {
	// 获取 viewModel 属性
	id viewModel = [self viewModel];
	if (!viewModel) {
		return;
	}

	NSArray *sectionDataArray = [viewModel valueForKey:@"sectionDataArray"];
	if (!sectionDataArray || ![sectionDataArray isKindOfClass:[NSArray class]]) {
		return;
	}

	NSMutableArray *mutableSections = [sectionDataArray mutableCopy];

	// 遍历查找"关于"部分
	for (id sectionModel in [sectionDataArray copy]) {

		Class sectionModelClass = NSClassFromString(@"AWESettingSectionModel");
		if (!sectionModelClass || ![sectionModel isKindOfClass:sectionModelClass]) {
			continue;
		}

		// 获取 sectionHeaderTitle
		NSString *sectionHeaderTitle = [sectionModel valueForKey:@"sectionHeaderTitle"];
		if ([sectionHeaderTitle isEqualToString:@"关于"]) {

			[mutableSections removeObject:sectionModel];
			[viewModel setValue:mutableSections forKey:@"sectionDataArray"];
			break;
		}
	}
}
%end

%hook AFDViewedBottomView
- (void)layoutSubviews {
	%orig;

	if (DYYYGetBool(@"DYYYisEnableFullScreen")) {

		self.backgroundColor = [UIColor clearColor];

		self.effectView.hidden = YES;
	}
}
%end

%hook AWENormalModeTabBarGeneralPlusButton
- (void)setImage:(UIImage *)image forState:(UIControlState)state {

	if ([self.accessibilityLabel isEqualToString:@"拍摄"]) {

		NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
		NSString *dyyyFolderPath = [documentsPath stringByAppendingPathComponent:@"DYYY"];

		NSString *customImagePath = [dyyyFolderPath stringByAppendingPathComponent:@"tab_plus.png"];

		if ([[NSFileManager defaultManager] fileExistsAtPath:customImagePath]) {
			UIImage *customImage = [UIImage imageWithContentsOfFile:customImagePath];
			if (customImage) {

				%orig(customImage, state);
				return;
			}
		}
	}

	%orig;
}
%end

// 极速版红包激励挂件容器视图类组（移除逻辑）
%group IncentivePendantGroup
%hook AWEIncentiveSwiftImplDOUYINLite_IncentivePendantContainerView
- (void)layoutSubviews {
	%orig;
	if (DYYYGetBool(@"DYYYHidePendantGroup")) {
		[self removeFromSuperview];
	}
}
%end
%end

// View scaling fix when comment blur is enabled
%group BDMultiContentImageViewGroup
%hook BDMultiContentContainer_ImageContentView

- (void)setTransform:(CGAffineTransform)transform {
	if (DYYYGetBool(@"DYYYisEnableCommentBlur")) {
		return;
	}
	%orig(transform);
}

%end
%end

%hook AWEStoryContainerCollectionView

- (void)setFrame:(CGRect)frame {
	if (DYYYGetBool(@"DYYYisEnableCommentBlur")) {
		if (frame.origin.y != 0) {
			return;
		}
	}
	%orig(frame);
}

%end

// Swift 类初始化
%ctor {

	// 初始化红包激励挂件容器视图类组
	Class incentivePendantClass = objc_getClass("AWEIncentiveSwiftImplDOUYINLite.IncentivePendantContainerView");
	if (incentivePendantClass) {
		%init(IncentivePendantGroup, AWEIncentiveSwiftImplDOUYINLite_IncentivePendantContainerView = incentivePendantClass);
	}
	Class imageContentClass = objc_getClass("BDMultiContentContainer.ImageContentView");
	if (imageContentClass) {
		%init(BDMultiContentImageViewGroup, BDMultiContentContainer_ImageContentView = imageContentClass);
	}
}

%ctor {
	%init(DYYYSettingsGesture);
	if (DYYYGetBool(@"DYYYUserAgreementAccepted")) {
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
		  Class wSwiftImpl = objc_getClass("AWECommentInputViewSwiftImpl.CommentInputContainerView");
		  %init(CommentInputContainerView = wSwiftImpl);
		});
		BOOL isAutoPlayEnabled = DYYYGetBool(@"DYYYisEnableAutoPlay");
		if (isAutoPlayEnabled) {
			%init(AutoPlay);
		}
		if (DYYYGetBool(@"DYYYForceDownloadEmotion")) {
			%init(EnableStickerSaveMenu);
		}
	}
}

// 隐藏键盘 AI
static __weak UIView *cachedHideView = nil;
static void hideParentViewsSubviews(UIView *view) {
	if (!view)
		return;
	UIView *parentView = [view superview];
	if (!parentView)
		return;
	UIView *grandParentView = [parentView superview];
	if (!grandParentView)
		return;
	UIView *greatGrandParentView = [grandParentView superview];
	if (!greatGrandParentView)
		return;
	cachedHideView = greatGrandParentView;
	for (UIView *subview in greatGrandParentView.subviews) {
		subview.hidden = YES;
	}
}
// 递归查找目标视图
static void findTargetViewInView(UIView *view) {
	if (cachedHideView)
		return;
	if ([view isKindOfClass:NSClassFromString(@"AWESearchKeyboardVoiceSearchEntranceView")]) {
		hideParentViewsSubviews(view);
		return;
	}
	for (UIView *subview in view.subviews) {
		findTargetViewInView(subview);
		if (cachedHideView)
			break;
	}
}

%ctor {
	// 注册键盘通知
	if (DYYYGetBool(@"DYYYUserAgreementAccepted")) {
		[[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillShowNotification
								  object:nil
								   queue:[NSOperationQueue mainQueue]
							      usingBlock:^(NSNotification *notification) {
								if (DYYYGetBool(@"DYYYHidekeyboardai")) {
									if (cachedHideView) {
										for (UIView *subview in cachedHideView.subviews) {
											subview.hidden = YES;
										}
									} else {
										for (UIWindow *window in [UIApplication sharedApplication].windows) {
											findTargetViewInView(window);
											if (cachedHideView)
												break;
										}
									}
								}
							      }];
	}
}
