//
//  SKNode+TouchPriority.m
//  ButtonLab
//
//  Created by Fille Åström on 10/20/13.
//  Copyright (c) 2013 IMGNRY. All rights reserved.
//

#import "TouchPriority.h"

@implementation SKNode (TouchPriority)

- (NSString *)nodeDepthPriority {
    __block NSString *code = @"";
    SKNode *currentNode = self;
    while (currentNode.parent) {
        [currentNode.parent.children enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if (obj == currentNode) {
                code = [NSString stringWithFormat:@"%03d%@", (int)idx, code];
                *stop = YES;
            }
        }];
        currentNode = currentNode.parent;
    }
    return code;
}

@end

@implementation SKScene (TouchPriority)

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    SKNode *nodeToTouch = [self nodeWithHighestPriority:touches];
    [nodeToTouch touchesBegan:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    SKNode *nodeToTouch = [self nodeWithHighestPriority:touches];
    [nodeToTouch touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    SKNode *nodeToTouch = [self nodeWithHighestPriority:touches];
    [nodeToTouch touchesCancelled:touches withEvent:event];
}

- (SKNode *)nodeWithHighestPriority:(NSSet *)touches {
    
    // Only allow touches to be receieved by nodes with userInteractionEnabled, and only the one with the highest touch priority
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInNode:self];
    NSArray *touchedNodes = [self nodesAtPoint:touchLocation];
    SKNode *nodeToTouch = nil;
    for (SKNode *node in touchedNodes) {
        if (node.userInteractionEnabled && node.hidden == NO && node.alpha > 0) {
            if (nodeToTouch == nil) {
                nodeToTouch = node;
            }
            else if (node.parent == nodeToTouch.parent && node.zPosition > nodeToTouch.zPosition) {
                nodeToTouch = node;
            }
            else if (node.parent == nodeToTouch.parent && node.zPosition == nodeToTouch.zPosition && [[nodeToTouch nodeDepthPriority] compare:[node nodeDepthPriority]] == NSOrderedAscending) {
                nodeToTouch = node;
            }
            else if (node.parent != nodeToTouch.parent && [[nodeToTouch nodeDepthPriority] compare:[node nodeDepthPriority]] == NSOrderedAscending) {
                nodeToTouch = node;
            }
        }
    }
    return nodeToTouch;
}

@end