//
//  Client.m
//  Sample_AVAPIs
//
//  Created by tutk on 3/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "Client.h"
#import "IOTCAPIs.h"
#import "AVAPIs.h"
#import "AVIOCTRLDEFs.h"
#import "AVFRAMEINFO.h"
#import <sys/time.h>
#import "VideoDecoder.h"
#import "AppDelegate.h"
#define AUDIO_BUF_SIZE	1024
#define VIDEO_BUF_SIZE	2000000

@implementation Client{
    int SID;
    pthread_t ThreadVideo_ID, ThreadAudio_ID;
}
@synthesize avIndex;
unsigned int _getTickCount() {
    
	struct timeval tv;
    
	if (gettimeofday(&tv, NULL) != 0)
        return 0;
    
	return (tv.tv_sec * 1000 + tv.tv_usec / 1000);
}
-(void *)thread_ReceiveAudio
//void *thread_ReceiveAudio(void *arg)
{
    NSLog(@"[thread_ReceiveAudio] Starting...");
    Client *pClient=self;//(__bridge Client*)arg;
    int tAvIndex = pClient.avIndex;//*(int *)arg;
    char buf[AUDIO_BUF_SIZE];
    unsigned int frmNo;
    int ret;
    FRAMEINFO_t frameInfo;
    
    while (pClient.isRunningRecvAudioThread)
    {
        ret = avCheckAudioBuf(tAvIndex);
        if (ret < 0) break;
        if (ret < 3) // determined by audio frame rate
        {
            usleep(120000);
            continue;
        }
            
        ret = avRecvAudioData(tAvIndex, buf, AUDIO_BUF_SIZE, (char *)&frameInfo, sizeof(FRAMEINFO_t), &frmNo);
    
        if(ret == AV_ER_SESSION_CLOSE_BY_REMOTE)
        {
            NSLog(@"[thread_ReceiveAudio] AV_ER_SESSION_CLOSE_BY_REMOTE");
            break;
        }
        else if(ret == AV_ER_REMOTE_TIMEOUT_DISCONNECT)
        {
            NSLog(@"[thread_ReceiveAudio] AV_ER_REMOTE_TIMEOUT_DISCONNECT");
            break;
        }
        else if(ret == IOTC_ER_INVALID_SID)
        {
            NSLog(@"[thread_ReceiveAudio] Session cant be used anymore");
            break;    
        }
        else if (ret == AV_ER_LOSED_THIS_FRAME)
        {
            continue;
        }
    
        // Now the data is ready in audioBuffer[0 ... ret - 1]
        // Do something here
    }

    NSLog(@"[thread_ReceiveAudio] thread exit");
    return 0;
}
-(void *)thread_ReceiveVideo
//void *thread_ReceiveVideo(void *arg)
{
    NSLog(@"[thread_ReceiveVideo] Starting...");
    Client *pClient=self;//(__bridge Client*)arg;
    int tAvIndex = pClient.avIndex;//*(int *)arg;
    char *buf = malloc(VIDEO_BUF_SIZE);
    unsigned int frmNo=0,prevFrmNo=0;
    int ret;
    FRAMEINFO_t frameInfo;
    int outBufSize = 0, outFrmSize = 0, outFrmInfoSize = 0;
    VideoDecoder *pVDecoder=[[VideoDecoder alloc]init];
    pVDecoder.delegate=self.delegate;
    while (pClient.isRunningRecvVideoThread)
    {
        //ret = avRecvFrameData(avIndex, buf, VIDEO_BUF_SIZE, (char *)&frameInfo, sizeof(FRAMEINFO_t), &frmNo);
        ret =avRecvFrameData2(tAvIndex, buf, VIDEO_BUF_SIZE, &outBufSize, &outFrmSize, (char *)&frameInfo, sizeof(FRAMEINFO_t), &outFrmInfoSize, &frmNo);
        if(ret == AV_ER_DATA_NOREADY)
		{
			usleep(30000);
			continue;
		}
		else if(ret == AV_ER_LOSED_THIS_FRAME)
		{
			NSLog(@"Lost video frame NO[%d]", frmNo);
			continue;
		}
		else if(ret == AV_ER_INCOMPLETE_FRAME)
		{
			NSLog(@"Incomplete video frame NO[%d]", frmNo);
			continue;
		}
		else if(ret == AV_ER_SESSION_CLOSE_BY_REMOTE)
		{
			NSLog(@"[thread_ReceiveVideo] AV_ER_SESSION_CLOSE_BY_REMOTE");
			break;
		}
		else if(ret == AV_ER_REMOTE_TIMEOUT_DISCONNECT)
		{
			NSLog(@"[thread_ReceiveVideo] AV_ER_REMOTE_TIMEOUT_DISCONNECT");
			break;
		}
		else if(ret == IOTC_ER_INVALID_SID)
		{
			NSLog(@"[thread_ReceiveVideo] Session cant be used anymore");
			break;
		}
		
		if(frameInfo.flags == IPC_FRAME_FLAG_IFRAME||frmNo==(prevFrmNo+1))
		{
            prevFrmNo=frmNo;
			// got an IFrame, draw it.
            NSLog(@"%d %@帧size=%d",frmNo,(frameInfo.flags == IPC_FRAME_FLAG_IFRAME?@"I":@"P"),ret);
            NSData *tPData=[NSData dataWithBytes:buf length:ret];
            
            //写文件h264
            AppDelegate *appDelegate=[[UIApplication sharedApplication] delegate];
            NSFileHandle *myHandle2 = [NSFileHandle fileHandleForWritingAtPath:appDelegate.videoPath];
            [myHandle2 seekToEndOfFile];
            [myHandle2 writeData:tPData];
            [myHandle2 closeFile];
            
            [pVDecoder push:tPData];
		}
//        else if(frameInfo.flags == IPC_FRAME_FLAG_PBFRAME)
//        {
//            NSLog(@"P(%d)size=%d",frmNo,ret);
//            NSData *tPData=[NSData dataWithBytes:buf length:ret];
//            [pVDecoder push:tPData];
//        }
    }
    [pVDecoder deInit];
    free(buf);
    NSLog(@"[thread_ReceiveVideo] thread exit");    
    return 0;
}

- (int)start_ipcam_stream:(int)avIndex_ {
    
    int ret;
    unsigned short val = 0;
    
    if ((ret = avSendIOCtrl(avIndex_, IOTYPE_INNER_SND_DATA_DELAY, (char *)&val, sizeof(unsigned short)) < 0))
    {
        NSLog(@"start_ipcam_stream_failed[%d]", ret);
        return 0;
    }
    
    SMsgAVIoctrlAVStream ioMsg;
    memset(&ioMsg, 0, sizeof(SMsgAVIoctrlAVStream));
    if ((ret = avSendIOCtrl(avIndex_, IOTYPE_USER_IPCAM_START, (char *)&ioMsg, sizeof(SMsgAVIoctrlAVStream)) < 0))
    {
        NSLog(@"start_ipcam_stream_failed[%d]", ret);
        return 0;        
    }
    
    if ((ret = avSendIOCtrl(avIndex_, IOTYPE_USER_IPCAM_AUDIOSTART, (char *)&ioMsg, sizeof(SMsgAVIoctrlAVStream)) < 0))
    {
        NSLog(@"start_ipcam_stream_failed[%d]", ret);
        return 0;        
    }
    
    return 1;
}

- (void)start:(NSString *)UID {
    
    int ret;
    
    NSLog(@"AVStream Client Start");    
    
    // use which Master base on location, port 0 means to get a random port.
    unsigned short nUdpPort = (unsigned short)(10000 + (_getTickCount() % 10000));
    ret = IOTC_Initialize(nUdpPort, "50.19.254.134", "122.248.234.207", "m4.iotcplatform.com", "m5.iotcplatform.com");
    NSLog(@"IOTC_Initialize() ret = %d", ret);
    
    if (ret != IOTC_ER_NoERROR) {
        NSLog(@"IOTCAPIs exit...");
        return;
    }
    
    // alloc 4 sessions for video and two-way audio
    avInitialize(4);
    
	// use IOTC_Connect_ByUID or IOTC_Connect_ByName to connect with device
#if 1
    
    //NSString *aesString = @"your aes key";
    
	SID = IOTC_Connect_ByUID((char *)[UID UTF8String]);
    
	//SID = IOTC_Connect_ByName("AHUA000099DGCEX", "JSW");
    
	printf("Step 2: call IOTC_Connect_ByUID2(%s) ret(%d).......\n", [UID UTF8String], SID);
	struct st_SInfo Sinfo;	
	ret = IOTC_Session_Check(SID, &Sinfo);
    
    if (ret >= 0)
    {
        if(Sinfo.Mode == 0)
            printf("Device is from %s:%d[%s] Mode=P2P\n",Sinfo.RemoteIP, Sinfo.RemotePort, Sinfo.UID);
        else if (Sinfo.Mode == 1)
            printf("Device is from %s:%d[%s] Mode=RLY\n",Sinfo.RemoteIP, Sinfo.RemotePort, Sinfo.UID);
        else if (Sinfo.Mode == 2)
            printf("Device is from %s:%d[%s] Mode=LAN\n",Sinfo.RemoteIP, Sinfo.RemotePort, Sinfo.UID);
    }
        
#else
    
	char *DeviceName="AAAA0009", *DevicePWD="123456";
	SID = IOTC_Connect_ByName(DeviceName,DevicePWD);
	printf("Step 2: call IOTC_Connect_ByName(%s,%s).......\n", DeviceName, DevicePWD);
    
#endif
    
	unsigned int srvType;
	avIndex = avClientStart(SID, "admin", "admin123", 20000, &srvType, 0);
	printf("Step 3: call avClientStart(%d).......\n", avIndex);	
    
	if(avIndex < 0)
	{
		printf("avClientStart failed[%d]\n", avIndex);
		return;
	}
    
    if ([self start_ipcam_stream:avIndex]) 
    {
        self.isRunningRecvAudioThread=YES;
        self.isRunningRecvVideoThread=YES;
		//pthread_create(&ThreadVideo_ID, NULL, &thread_ReceiveVideo, (__bridge void *)self);
		//pthread_create(&ThreadAudio_ID, NULL, &thread_ReceiveAudio, (__bridge void *)self);
        
        NSLog(@"threadMain=%@",[NSThread currentThread]);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSLog(@"threadAudio=%@",[NSThread currentThread]);
            [self thread_ReceiveAudio];
            
        });
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSLog(@"threadVideo=%@",[NSThread currentThread]);
            [self thread_ReceiveVideo];
            
        });
        
    }
    

}
-(void)Stop{
    self.isRunningRecvAudioThread=NO;
    self.isRunningRecvVideoThread=NO;
    //pthread_join(ThreadVideo_ID, NULL);//等待一个线程的结束
    //pthread_join(ThreadAudio_ID, NULL);
    
    avClientStop(avIndex);
    NSLog(@"avClientStop OK");
    IOTC_Session_Close(SID);
    NSLog(@"IOTC_Session_Close OK");
    avDeInitialize();
    IOTC_DeInitialize();
    
    NSLog(@"StreamClient exit...");
}
@end