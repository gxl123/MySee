//
//  ViewController.h
//  MySee
//
//  Created by ml  on 14/11/2.
//  Copyright (c) 2014年 ml . All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VideoDecoder.h"
@interface ViewController : UIViewController<VideoDecoderDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *monitor;

@end

