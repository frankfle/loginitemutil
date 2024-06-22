//
//  FFLoginItemController.h
//  loginitemutil
//
//  Created by Frank Fleschner on 4/12/12.
//  Copyright (c) 2012 Frank Fleschner. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FFLoginItemController : NSObject
{
    NSArray *targetedUsers;
    NSArray *ignoredUsers;
    
    BOOL allUsers;
    
    NSURL *theURL;
    BOOL shouldBeHidden;
    BOOL verboseLogging;
}

// Properties that directly affect the Login Item.
@property (strong) NSArray *targetedUsers;
@property (strong) NSArray *ignoredUsers;
@property (assign) BOOL allUsers;
@property (strong) NSURL *theURL;
@property (assign) BOOL shouldBeHidden;
@property (assign) BOOL verboseLogging;


// Actions:
- (BOOL)addItem;
- (BOOL)removeItem;
- (BOOL)itemExists;
- (NSArray *)allLoginItems;

@end
