//
//  AWSSNSManager.h
//
//  Created by Mahdi Bchetnia on 10/30/14.
//  Copyright (c) 2014 Interfirm. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AWSiOSSDKv2/SNS.h>

@interface MBAWSSNSManager : NSObject

@property (strong) NSString* awsAccessKey;
@property (strong) NSString* awsSecretKey;
@property (strong) NSString* awsApplicationArn;
@property AWSRegionType awsRegion;

@property (nonatomic, strong) NSData* deviceToken;

@property BOOL acceptsNotificationTypeAlert;
@property BOOL acceptsNotificationTypeBadge;
@property BOOL acceptsNotificationTypeSound;
@property (strong) NSSet* actionSettings;

+ (instancetype)sharedManager;
- (void)registerForNotifications;
- (void)receivedDeviceToken:(NSData*)deviceToken;
- (void)subscribeToTopics:(NSArray*)topicArns;

@end
