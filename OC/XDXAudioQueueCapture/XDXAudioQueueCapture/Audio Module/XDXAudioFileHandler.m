//
//  XDXAudioFileHandler.m
//  XDXAudioQueueRecordAndPlayback
//
//  Created by 小东邪 on 2019/5/3.
//  Copyright © 2019 小东邪. All rights reserved.
//

#import "XDXAudioFileHandler.h"
#import "XDXAudioQueueCaptureManager.h"

@interface XDXAudioFileHandler ()
{
    AudioFileID m_recordFile;
    SInt64      m_recordCurrentPacket;      // current packet number in record file
}

@property (nonatomic, copy) NSString *recordFilePath;

@end

@implementation XDXAudioFileHandler
SingletonM

#pragma mark - Init
+ (instancetype)getInstance {
    return [[self alloc] init];
}

#pragma mark - Public
-(void)startVoiceRecordByAudioQueue:(AudioQueueRef)audioQueue isNeedMagicCookie:(BOOL)isNeedMagicCookie audioDesc:(AudioStreamBasicDescription)audioDesc {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy_MM_dd__HH_mm_ss";
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];
    
    NSArray *searchPaths    = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                                  NSUserDomainMask,
                                                                  YES);
    
    NSString *documentPath  = [[searchPaths objectAtIndex:0] stringByAppendingPathComponent:@"Voice"];
    
    // 先创建子目录. 注意,若果直接调用AudioFileCreateWithURL创建一个不存在的目录创建文件会失败
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:documentPath]) {
        [fileManager createDirectoryAtPath:documentPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    OSStatus status;
    NSString *fullFileName  = [NSString stringWithFormat:@"%@.caf",date];
    NSString *filePath      = [documentPath stringByAppendingPathComponent:fullFileName];
    CFURLRef url            = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)filePath, NULL);
    self.recordFilePath     = filePath;
    
    NSLog(@"Audio Recorder: record file path:%@",filePath);
    
    // create the audio file
    status                  = AudioFileCreateWithURL(url, kAudioFileCAFType, &audioDesc, kAudioFileFlags_EraseFile, &m_recordFile);
    if (status != noErr) {
        NSLog(@"Audio Recorder: AudioFileCreateWithURL Failed, status:%d",(int)status);
    }
    
    CFRelease(url);
    
    if (isNeedMagicCookie) {
        // add magic cookie contain header file info for VBR data
        [self copyEncoderCookieToFileWithQueue:audioQueue inFile:m_recordFile];
    }
}

-(void)stopVoiceRecordWithNeedMagicCookie:(BOOL)isNeedMagicCookie {
    if (isNeedMagicCookie) {
        // reconfirm magic cookie at the end.
        [self copyEncoderCookieToFileWithQueue:[[XDXAudioQueueCaptureManager getInstance] getInputQueue]
                                        inFile:m_recordFile];
    }

    AudioFileClose(m_recordFile);
    m_recordCurrentPacket = 0;
}


- (void)writeFileWithInNumBytes:(UInt32)inNumBytes ioNumPackets:(UInt32 )ioNumPackets inBuffer:(const void *)inBuffer inPacketDesc:(const AudioStreamPacketDescription*)inPacketDesc {
    if (!m_recordFile) {
        return;
    }
    
//    AudioStreamPacketDescription outputPacketDescriptions;
    OSStatus status = AudioFileWritePackets(m_recordFile,
                                            false,
                                            inNumBytes,
                                            inPacketDesc,
                                            m_recordCurrentPacket,
                                            &ioNumPackets,
                                            inBuffer);
    
    if (status == noErr) {
        m_recordCurrentPacket += ioNumPackets;  // 用于记录起始位置
    }else {
        NSLog(@"Audio Recorder: write file status = %d \n",(int)status);
    }
    
}

#pragma mark - Private
- (void)copyEncoderCookieToFileWithQueue:(AudioQueueRef)inQueue inFile:(AudioFileID)inFile {
    OSStatus result = noErr;
    UInt32 cookieSize;
    
    result = AudioQueueGetPropertySize (
                                        inQueue,
                                        kAudioQueueProperty_MagicCookie,
                                        &cookieSize
                                        );
    if (result == noErr) {
        char* magicCookie = (char *) malloc (cookieSize);
        result =AudioQueueGetProperty (
                                       inQueue,
                                       kAudioQueueProperty_MagicCookie,
                                       magicCookie,
                                       &cookieSize
                                       );
        if (result == noErr) {
            result = AudioFileSetProperty (
                                           inFile,
                                           kAudioFilePropertyMagicCookieData,
                                           cookieSize,
                                           magicCookie
                                           );
            if (result == noErr) {
                NSLog(@"set Magic cookie successful.");
            }else {
                NSLog(@"set Magic cookie failed.");
            }
        }else {
            NSLog(@"get Magic cookie failed.");
        }
        free (magicCookie);
            
    }else {
        NSLog(@"Magic cookie: get size failed.");
    }

}

- (AudioFileID)test {
    return m_recordFile;
}
@end
