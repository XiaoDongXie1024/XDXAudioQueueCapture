//
//  ViewController.m
//  XDXAudioQueueRecordAndPlayback
//
//  Created by 小东邪 on 2019/5/3.
//  Copyright © 2019 小东邪. All rights reserved.
//

#import "ViewController.h"
#import "XDXAudioQueueCaptureManager.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[XDXAudioQueueCaptureManager getInstance] startAudioCapture];
}

- (void)dealloc {
    [[XDXAudioQueueCaptureManager getInstance] stopAudioCapture];
}

- (IBAction)startRecord:(id)sender {
    [[XDXAudioQueueCaptureManager getInstance] startRecordFile];
}

- (IBAction)stopRecord:(id)sender {
    [[XDXAudioQueueCaptureManager getInstance] stopRecordFile];
}

@end
