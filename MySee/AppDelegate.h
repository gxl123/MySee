//
//  AppDelegate.h
//  MySee
//
//  Created by ml  on 14/11/2.
//  Copyright (c) 2014年 ml . All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (atomic, retain) NSString *videoPath,*videoH264Path,*videoYuvPath;

@end

