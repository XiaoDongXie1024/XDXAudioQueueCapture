//
//  XDXAudioFileHandler.h
//  XDXAudioQueueRecordAndPlayback
//
//  Created by 小东邪 on 2019/5/3.
//  Copyright © 2019 小东邪. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import "XDXSingleton.h"

NS_ASSUME_NONNULL_BEGIN

@interface XDXAudioFileHandler : NSObject
SingletonH

+ (instancetype)getInstance;


/**
 * Start / Stop record.
 */
-(void)startVoiceRecordByAudioQueue:(AudioQueueRef)audioQueue
                  isNeedMagicCookie:(BOOL)isNeedMagicCookie
                          audioDesc:(AudioStreamBasicDescription)audioDesc;

-(void)stopVoiceRecordWithNeedMagicCookie:(BOOL)isNeedMagicCookie;


/**
 * Write audio data to file.
 */
- (void)writeFileWithInNumBytes:(UInt32)inNumBytes
                   ioNumPackets:(UInt32 )ioNumPackets
                       inBuffer:(const void *)inBuffer
                   inPacketDesc:(const AudioStreamPacketDescription*)inPacketDesc;

- (AudioFileID)test;
@end

NS_ASSUME_NONNULL_END
