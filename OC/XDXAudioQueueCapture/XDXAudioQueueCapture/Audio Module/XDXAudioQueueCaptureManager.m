//
//  XDXAudioQueueCaptureManager.m
//  XDXAudioQueueRecordAndPlayback
//
//  Created by 小东邪 on 2019/5/3.
//  Copyright © 2019 小东邪. All rights reserved.
//

#import "XDXAudioQueueCaptureManager.h"
#import "XDXAudioFileHandler.h"
#import <AVFoundation/AVFoundation.h>

#define kXDXAudioPCMFramesPerPacket 1
#define kXDXAudioPCMBitsPerChannel  16

static const int kNumberBuffers = 3;

struct XDXRecorderInfo {
    AudioStreamBasicDescription  mDataFormat;
    AudioQueueRef                mQueue;
    AudioQueueBufferRef          mBuffers[kNumberBuffers];
};
typedef struct XDXRecorderInfo *XDXRecorderInfoType;

static XDXRecorderInfoType m_audioInfo;

@interface XDXAudioQueueCaptureManager ()

@property (nonatomic, assign, readwrite) BOOL isRunning;

@end

@implementation XDXAudioQueueCaptureManager
SingletonM

#pragma mark - Callback
static void CaptureAudioDataCallback(void *                                 inUserData,
                                     AudioQueueRef                          inAQ,
                                     AudioQueueBufferRef                    inBuffer,
                                     const AudioTimeStamp *                 inStartTime,
                                     UInt32                                 inNumPackets,
                                     const AudioStreamPacketDescription*    inPacketDesc) {
    
    XDXAudioQueueCaptureManager *instance = (__bridge XDXAudioQueueCaptureManager *)inUserData;
    
    /*  Test audio fps
    static Float64 lastTime = 0;
    Float64 currentTime = CMTimeGetSeconds(CMClockMakeHostTimeFromSystemUnits(inStartTime->mHostTime))*1000;
    NSLog(@"Test duration - %f",currentTime - lastTime);
    lastTime = currentTime;
    */
    
    // NSLog(@"Test data: %d,%d,%d,%d",inBuffer->mAudioDataByteSize,inNumPackets,inPacketDesc->mDataByteSize,inPacketDesc->mVariableFramesInPacket);
    
    if (instance.isRecordVoice) {
        UInt32 bytesPerPacket = m_audioInfo->mDataFormat.mBytesPerPacket;
        if (inNumPackets == 0 && bytesPerPacket != 0) {
            inNumPackets = inBuffer->mAudioDataByteSize / bytesPerPacket;
        }
        
        [[XDXAudioFileHandler getInstance] writeFileWithInNumBytes:inBuffer->mAudioDataByteSize
                                                      ioNumPackets:inNumPackets
                                                          inBuffer:inBuffer->mAudioData
                                                      inPacketDesc:inPacketDesc];
    }
    
    if (instance.isRunning) {
        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    }
}



#pragma mark - Init
+ (void)initialize {
    m_audioInfo = malloc(sizeof(struct XDXRecorderInfo));
}

+ (instancetype)getInstance {    
    return [[self alloc] init];
}

- (AudioQueueRef)getInputQueue {
    return m_audioInfo->mQueue;
}

-(AudioStreamBasicDescription)getAudioFormatWithFormatID:(UInt32)formatID sampleRate:(Float64)sampleRate channelCount:(UInt32)channelCount {
    AudioStreamBasicDescription dataFormat = {0};
    
    UInt32 size = sizeof(dataFormat.mSampleRate);
    // Get hardware origin sample rate. (Recommended it)
    Float64 hardwareSampleRate = 0;
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate,
                            &size,
                            &hardwareSampleRate);
    // Manual set sample rate
    dataFormat.mSampleRate = sampleRate;
    
    size = sizeof(dataFormat.mChannelsPerFrame);
    // Get hardware origin channels number. (Must refer to it)
    UInt32 hardwareNumberChannels = 0;
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputNumberChannels,
                            &size,
                            &hardwareNumberChannels);
    dataFormat.mChannelsPerFrame = channelCount;
    
    // Set audio format
    dataFormat.mFormatID = formatID;
    
    // Set detail audio format params
    if (formatID == kAudioFormatLinearPCM) {
        dataFormat.mFormatFlags     = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        dataFormat.mBitsPerChannel  = kXDXAudioPCMBitsPerChannel;
        dataFormat.mBytesPerPacket  = dataFormat.mBytesPerFrame = (dataFormat.mBitsPerChannel / 8) * dataFormat.mChannelsPerFrame;
        dataFormat.mFramesPerPacket = kXDXAudioPCMFramesPerPacket;
    }else if (formatID == kAudioFormatMPEG4AAC) {
        dataFormat.mFormatFlags = kMPEG4Object_AAC_Main;
    }

    NSLog(@"Audio Recorder: starup PCM audio encoder:%f,%d",sampleRate,channelCount);
    return dataFormat;
}

#pragma mark - Public
- (void)startAudioCapture {
    [self startAudioCaptureWithAudioInfo:m_audioInfo
                                 formatID:kAudioFormatMPEG4AAC // kAudioFormatLinearPCM
                               sampleRate:44100
                             channelCount:1
                              durationSec:0.05
                                isRunning:&_isRunning];
}

- (void)stopAudioCapture {
    [self stopAudioQueueRecorderWithAudioInfo:m_audioInfo
                                    isRunning:&_isRunning];
}

- (void)startRecordFile {
    BOOL isNeedMagicCookie = NO;
    // 注意: 未压缩数据不需要PCM,可根据需求自行添加
    if (m_audioInfo->mDataFormat.mFormatID == kAudioFormatLinearPCM) {
        isNeedMagicCookie = NO;
    }else {
        isNeedMagicCookie = YES;
    }
    [[XDXAudioFileHandler getInstance] startVoiceRecordByAudioQueue:m_audioInfo->mQueue
                                                  isNeedMagicCookie:isNeedMagicCookie
                                                          audioDesc:m_audioInfo->mDataFormat];
    self.isRecordVoice = YES;
    NSLog(@"Audio Recorder: Start record file.");
}

- (void)stopRecordFile {
    self.isRecordVoice = NO;
    BOOL isNeedMagicCookie = NO;
    if (m_audioInfo->mDataFormat.mFormatID == kAudioFormatLinearPCM) {
        isNeedMagicCookie = NO;
    }else {
        isNeedMagicCookie = YES;
    }
    
    [[XDXAudioFileHandler getInstance] stopVoiceRecordByAudioQueue:m_audioInfo->mQueue
                                                   needMagicCookie:isNeedMagicCookie];
    NSLog(@"Audio Recorder: Stop record file.");
}

#pragma mark - Private
#pragma start / stop
- (BOOL)startAudioCaptureWithAudioInfo:(XDXRecorderInfoType)audioInfo formatID:(UInt32)formatID sampleRate:(Float64)sampleRate channelCount:(UInt32)channelCount durationSec:(float)durationSec isRunning:(BOOL *)isRunning {
    if (*isRunning) {
        NSLog(@"Audio Recorder: Start recorder repeat");
        return NO;
    }
    
    // Get Audio format ASBD
    audioInfo->mDataFormat = [self getAudioFormatWithFormatID:formatID
                                                   sampleRate:sampleRate
                                                 channelCount:channelCount];
    
    // New queue
    OSStatus status = AudioQueueNewInput(&audioInfo->mDataFormat,
                                         CaptureAudioDataCallback,
                                         (__bridge void *)(self),
                                         NULL,
                                         kCFRunLoopCommonModes,
                                         0,
                                         &audioInfo->mQueue);
    
    if (status != noErr) {
        NSLog(@"Audio Recorder: AudioQueueNewInput Failed status:%d \n",(int)status);
        return NO;
    }
    
    // Set audio format for audio queue
    UInt32 size = sizeof(audioInfo->mDataFormat);
    status = AudioQueueGetProperty(audioInfo->mQueue,
                                   kAudioQueueProperty_StreamDescription,
                                   &audioInfo->mDataFormat,
                                   &size);
    if (status != noErr) {
        NSLog(@"Audio Recorder: get ASBD status:%d",(int)status);
        return NO;
    }
    
    // Set capture data size
    UInt32 bufferByteSize;
    if (audioInfo->mDataFormat.mFormatID == kAudioFormatLinearPCM) {
        int frames = (int)ceil(durationSec * audioInfo->mDataFormat.mSampleRate);
        bufferByteSize = frames*audioInfo->mDataFormat.mBytesPerFrame*audioInfo->mDataFormat.mChannelsPerFrame;
    }else {
        // AAC durationSec MIN: 23.219708 ms
        bufferByteSize = durationSec * audioInfo->mDataFormat.mSampleRate;
        
        if (bufferByteSize < 1024) {
            bufferByteSize = 1024;
        }
    }
    
    // Allocate and Enqueue
    for (int i = 0; i != kNumberBuffers; i++) {
        status = AudioQueueAllocateBuffer(audioInfo->mQueue,
                                              bufferByteSize,
                                          &audioInfo->mBuffers[i]);
        if (status != noErr) {
            NSLog(@"Audio Recorder: Allocate buffer status:%d",(int)status);
        }
        
        status = AudioQueueEnqueueBuffer(audioInfo->mQueue,
                                         audioInfo->mBuffers[i],
                                         0,
                                         NULL);
        if (status != noErr) {
            NSLog(@"Audio Recorder: Enqueue buffer status:%d",(int)status);
        }
    }
    
    status = AudioQueueStart(audioInfo->mQueue, NULL);
    if (status != noErr) {
        NSLog(@"Audio Recorder: Audio Queue Start failed status:%d \n",(int)status);
        return NO;
    }else {
        NSLog(@"Audio Recorder: Audio Queue Start successful");
        *isRunning = YES;
        return YES;
    }
}

-(BOOL)stopAudioQueueRecorderWithAudioInfo:(XDXRecorderInfoType)audioInfo isRunning:(BOOL *)isRunning {
    if (*isRunning == NO) {
        NSLog(@"Audio Recorder: Stop recorder repeat \n");
        return NO;
    }
    
    if (audioInfo->mQueue) {
        OSStatus stopRes = AudioQueueStop(audioInfo->mQueue, true);
        
        if (stopRes == noErr){
            for (int i = 0; i < kNumberBuffers; i++)
                AudioQueueFreeBuffer(audioInfo->mQueue, audioInfo->mBuffers[i]);
        }else{
            NSLog(@"Audio Recorder: stop AudioQueue failed.");
            return NO;
        }
        
        OSStatus status = AudioQueueDispose(audioInfo->mQueue, true);
        if (status != noErr) {
            NSLog(@"Audio Recorder: Dispose failed: %d",status);
            return NO;
        }else {
            audioInfo->mQueue = NULL;
            *isRunning = NO;
            //        AudioFileClose(mRecordFile);
            NSLog(@"Audio Recorder: stop AudioQueue successful.");
            return YES;
        }
    }
    
    return NO;
}

#pragma mark Other
-(int)computeRecordBufferSizeFrom:(const AudioStreamBasicDescription *)format audioQueue:(AudioQueueRef)audioQueue durationSec:(float)durationSec {
    int packets = 0;
    int frames  = 0;
    int bytes   = 0;
    
    frames = (int)ceil(durationSec * format->mSampleRate);
    
    if (format->mBytesPerFrame > 0)
        bytes = frames * format->mBytesPerFrame;
    else {
        UInt32 maxPacketSize;
        if (format->mBytesPerPacket > 0){   // CBR
            maxPacketSize = format->mBytesPerPacket;    // constant packet size
        }else { // VBR
            // AAC Format get kAudioQueueProperty_MaximumOutputPacketSize return -50. so the method is not effective.
            UInt32 propertySize = sizeof(maxPacketSize);
            OSStatus status     = AudioQueueGetProperty(audioQueue,
                                                        kAudioQueueProperty_MaximumOutputPacketSize,
                                                        &maxPacketSize,
                                                        &propertySize);
            if (status != noErr) {
                NSLog(@"%s: get max output packet size failed:%d",__func__,status);
            }
        }
        
        if (format->mFramesPerPacket > 0)
            packets = frames / format->mFramesPerPacket;
        else
            packets = frames;    // worst-case scenario: 1 frame in a packet
        if (packets == 0)        // sanity check
            packets = 1;
        bytes = packets * maxPacketSize;
    }
    
    return bytes;
}

- (void)printASBD:(AudioStreamBasicDescription)asbd {
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig (asbd.mFormatID);
    bcopy (&formatID, formatIDString, 4);
    formatIDString[4] = '\0';
    
    NSLog (@"  Sample Rate:         %10.0f",  asbd.mSampleRate);
    NSLog (@"  Format ID:           %10s",    formatIDString);
    NSLog (@"  Format Flags:        %10X",    asbd.mFormatFlags);
    NSLog (@"  Bytes per Packet:    %10d",    asbd.mBytesPerPacket);
    NSLog (@"  Frames per Packet:   %10d",    asbd.mFramesPerPacket);
    NSLog (@"  Bytes per Frame:     %10d",    asbd.mBytesPerFrame);
    NSLog (@"  Channels per Frame:  %10d",    asbd.mChannelsPerFrame);
    NSLog (@"  Bits per Channel:    %10d",    asbd.mBitsPerChannel);
}

- (void)dealloc {
    free(m_audioInfo);
}
@end
