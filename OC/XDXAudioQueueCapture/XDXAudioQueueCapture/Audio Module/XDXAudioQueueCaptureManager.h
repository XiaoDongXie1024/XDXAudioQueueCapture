//
//  XDXAudioQueueCaptureManager.h
//  XDXAudioQueueRecordAndPlayback
//
//  Created by 小东邪 on 2019/5/3.
//  Copyright © 2019 小东邪. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import "XDXSingleton.h"

NS_ASSUME_NONNULL_BEGIN

@interface XDXAudioQueueCaptureManager : NSObject
SingletonH

@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, assign) BOOL isRecordVoice;

+ (instancetype)getInstance;


/**
 * Start / Stop Audio Queue
 */
- (void)startAudioCapture;
- (void)stopAudioCapture;


/**
 * Start / Pause / Stop record file
 */
- (void)startRecordFile;
- (void)pauseAudioCapture;
- (void)stopRecordFile;


/**
 * free related resources
 */
- (void)freeAudioCapture;

@end

NS_ASSUME_NONNULL_END
