//
//  LocationDataSource.h
//  ChattAR
//
//  Created by Igor Alefirenko on 09/09/2013.
//  Copyright (c) 2013 Stefano Antonelli. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LocationDataSource : NSObject <UITableViewDataSource>

@property (strong, nonatomic) NSArray *chatRooms;

@end