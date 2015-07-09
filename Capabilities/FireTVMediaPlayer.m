//
//  FireTVMediaPlayer.m
//  ConnectSDK
//
//  Created by Eugene Nikolskyi on 2015-07-08.
//  Copyright (c) 2015 LG Electronics. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FireTVMediaPlayer.h"
#import "FireTVCapabilityMixin.h"
#import "FireTVMediaControl.h"
#import "FireTVService.h"

#import <AmazonFling/RemoteMediaPlayer.h>


// the use of a category silences unimplemented method warnings
@interface FireTVMediaPlayer (Configuration) <FireTVCapabilityMixin>

@end

@implementation FireTVMediaPlayer

#pragma mark - MediaPlayer

- (id<MediaPlayer>)mediaPlayer {
    return self;
}

- (CapabilityPriorityLevel)mediaPlayerPriority {
    return CapabilityPriorityLevelHigh;
}

- (void)displayImageWithMediaInfo:(MediaInfo *)mediaInfo
                          success:(MediaPlayerSuccessBlock)success
                          failure:(FailureBlock)failure {
    [self playMediaWithMediaInfo:mediaInfo
                      shouldLoop:NO
                         success:success
                         failure:failure];
}

- (void)playMediaWithMediaInfo:(MediaInfo *)mediaInfo
                    shouldLoop:(BOOL)shouldLoop
                       success:(MediaPlayerSuccessBlock)success
                       failure:(FailureBlock)failure {
    NSString *iconURL = ((ImageInfo *)[mediaInfo.images firstObject]).url.absoluteString;
    NSString *metadata = [self metadataStringForTitle:mediaInfo.title
                                          description:mediaInfo.description
                                             mimeType:mediaInfo.mimeType
                                     andIconURLString:iconURL];

    [self continueTask:[self.remoteMediaPlayer setMediaSourceToURL:mediaInfo.url.absoluteString
                                                          metaData:metadata
                                                          autoPlay:YES
                                               andPlayInBackground:NO]
  withSuccessCompleter:^(id __nullable result) {
      LaunchSession *session = [LaunchSession new];
      session.sessionType = LaunchSessionTypeMedia;
      session.service = self.service;

      MediaLaunchObject *object = [[MediaLaunchObject alloc]
                                   initWithLaunchSession:session
                                   andMediaControl:self.service.fireTVMediaControl];

      success(object);
  }
        ifSuccessBlock:success
       andFailureBlock:failure];
}

- (void)closeMedia:(LaunchSession *)launchSession
           success:(SuccessBlock)success
           failure:(FailureBlock)failure {
    [self continueTask:[self.remoteMediaPlayer stop]
      withSuccessBlock:success
       andFailureBlock:failure];
}

#pragma mark - MediaPlayer: deprecated methods

- (void)displayImage:(MediaInfo *)mediaInfo
             success:(MediaPlayerDisplaySuccessBlock)success
             failure:(FailureBlock)failure {
    [self playMedia:mediaInfo
         shouldLoop:NO
            success:success
            failure:failure];
}

- (void)displayImage:(NSURL *)imageURL
             iconURL:(NSURL *)iconURL
               title:(NSString *)title
         description:(NSString *)description
            mimeType:(NSString *)mimeType
             success:(MediaPlayerDisplaySuccessBlock)success
             failure:(FailureBlock)failure {
    [self playMedia:imageURL
            iconURL:iconURL
              title:title
        description:description
           mimeType:mimeType
         shouldLoop:NO
            success:success
            failure:failure];
}

- (void)playMedia:(MediaInfo *)mediaInfo
       shouldLoop:(BOOL)shouldLoop
          success:(MediaPlayerDisplaySuccessBlock)success
          failure:(FailureBlock)failure {
    [self playMediaWithMediaInfo:mediaInfo
                      shouldLoop:shouldLoop
                         success:^(MediaLaunchObject *mediaLaunchObject) {
                             if (success) {
                                 success(mediaLaunchObject.session,
                                         mediaLaunchObject.mediaControl);
                             }
                         }
                         failure:failure];
}

- (void)playMedia:(NSURL *)mediaURL
          iconURL:(NSURL *)iconURL
            title:(NSString *)title
      description:(NSString *)description
         mimeType:(NSString *)mimeType
       shouldLoop:(BOOL)shouldLoop
          success:(MediaPlayerDisplaySuccessBlock)success
          failure:(FailureBlock)failure {
    MediaInfo *mediaInfo = [[MediaInfo alloc] initWithURL:mediaURL
                                                 mimeType:mimeType];
    mediaInfo.title = title;
    mediaInfo.description = description;

    ImageInfo *imageInfo = [[ImageInfo alloc] initWithURL:iconURL
                                                     type:ImageTypeVideoPoster];
    [mediaInfo addImage:imageInfo];

    [self playMediaWithMediaInfo:mediaInfo
                      shouldLoop:shouldLoop
                         success:^(MediaLaunchObject *mediaLaunchObject) {
                             if (success) {
                                 success(mediaLaunchObject.session,
                                         mediaLaunchObject.mediaControl);
                             }
                         }
                         failure:failure];
}

#pragma mark - Helpers

/// Returns a metadata JSON string for the given media info values.
- (NSString *)metadataStringForTitle:(NSString *)title
                         description:(NSString *)description
                            mimeType:(NSString *)mimeType
                    andIconURLString:(NSString *)iconURLString {
    NSMutableDictionary *metadataDict = [NSMutableDictionary dictionary];

    void(^setValue)() = ^(NSString *__nonnull key, id __nullable value) {
        if (value) {
            metadataDict[key] = value;
        }
    };

    setValue(@"type", mimeType);
    setValue(@"title", title);
    setValue(@"description", description);
    setValue(@"poster", iconURLString);
    // "noreplay" hides the player's manual repeat dialog at EOF
    setValue(@"noreplay", @YES);
    NSData *data = [NSJSONSerialization dataWithJSONObject:metadataDict
                                                   options:0
                                                     error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

#pragma mark - Forwarding to Configuration

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return ([self.capabilityMixin respondsToSelector:aSelector] ?
            self.capabilityMixin :
            [super forwardingTargetForSelector:aSelector]);
}

@end
