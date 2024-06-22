//
//  main.m
//  loginitemutil
//
//  Created by Frank Fleschner on 4/12/12.
//  Copyright (c) 2012 Frank Fleschner. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FFLoginItemController.h"

#define VERSION "0.9"

int main(int argc, char * argv[])
{
    @autoreleasepool
    {
        NSMutableArray *requestedUsers = [NSMutableArray array];
        NSMutableArray *deniedUsers = [NSMutableArray array];
        NSString *path = nil;
        BOOL allUsers = NO;
        BOOL loginItemHidden = NO;
        BOOL printVersion = NO;
        BOOL printHelp = NO;
        BOOL shouldDelete = NO;
        BOOL shouldCheck = NO;
        BOOL shouldListAll = NO;
        BOOL verboseMode = NO;
        
        // Get some parameters:
        int c; opterr = 0;
        while ((c = getopt(argc, argv, "vVhHAlcdu:p:x:")) != -1)
        {
            switch (c)
            {
                case 'v':
                    printVersion = YES;
                    break;
                case 'V':
                    verboseMode = YES;
                    break;
                case 'h':
                    printHelp = YES;
                    break;
                case 'H':
                    loginItemHidden = YES;
                    break;
                case 'c':
                    shouldCheck = YES;
                    break;
                case 'd':
                    shouldDelete = YES;
                    break;
                case 'l':
                    shouldListAll = YES;
                    break;
                case 'u':
                    if (getuid() != 0)
                    {
                        fprintf(stderr, "You can't do that without being root!");
                        exit(1);
                    }
                    [requestedUsers addObject:@(optarg)];
                    break;
                case 'p':
                    path = @(optarg);
                    break;
                case 'x':
                    [deniedUsers addObject:@(optarg)];
                    /* Fallthrough: -x implies -A*/
                case 'A':
                    if (getuid() != 0)
                    {
                        fprintf(stderr, "You can't do that without being root!");
                        exit(1);
                    }
                    allUsers = YES;
                    break;
                default:
                    break;
            }
        }
        
        if (printHelp)
        {
            fprintf(stdout, "loginitemutil [-u <user>] [-p <path>] [-x <ignored user>] [-l -d -H -A -c]\n");
        }
        
        if (printVersion)
        {
            fprintf(stdout, "%s\n", VERSION);
        }
        
        if (shouldListAll)
        {
            FFLoginItemController *listController = [[FFLoginItemController alloc] init];
            
            NSArray *allPaths = [listController allLoginItems];
            
            fprintf(stdout, "Current login items:\n");
            
            for (NSString *path in allPaths)
            {
                fprintf(stdout, "%s\n", [path cStringUsingEncoding:NSUTF8StringEncoding]);
            }
        }
        
        if (!path)
        {
            if (!shouldListAll)
            {
                NSLog(@"ERROR: no path supplied!");
            }
            exit(1);
        }
    
        FFLoginItemController *liController = [[FFLoginItemController alloc] init];
    
        liController.theURL = [NSURL fileURLWithPath:path];
        liController.targetedUsers = requestedUsers;
        liController.ignoredUsers = deniedUsers;
        liController.shouldBeHidden = loginItemHidden;
        liController.allUsers = allUsers;
        liController.verboseLogging = verboseMode;
    
        if (shouldDelete)
        {
            return [liController removeItem];
        }
        else if (shouldCheck)
        {
            BOOL result = [liController itemExists];
            
            if (result)
            {
                fprintf(stdout, "Item exists\n");
                NSLog(@"It exists!");
            }
            else
            {
                fprintf(stdout, "Item does not exist\n");
            }
        }
        else
        {
            return [liController addItem];
        }
    
    }
    return 0;
}

