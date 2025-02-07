//
//  AMSpringboardView.h
//  AMSpringboardView
//
//  Created by Andy Mroczkowski on 2/19/11.
//  Copyright 2011 Andy Mroczkowski. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AMSpringboardViewCell.h"
#import "NSIndexPath+AMSpringboard.h"
#import "AMSpringboardItemSpecifier.h"

@protocol AMSpringboardViewDataSource;
@protocol AMSpringboardViewDelegate;

@interface AMSpringboardView : UIView <UIScrollViewDelegate, UIGestureRecognizerDelegate>
{
    id<AMSpringboardViewDelegate>   _delegate;
	id<AMSpringboardViewDataSource> _dataSource;
    
	UIPageControl*                  _pageControl;
	UIScrollView*                   _scrollView;
    UIView*                         _contentView;
    
    NSMutableDictionary*            _cells;
    NSMutableArray*                 _unusedCells;
    NSUInteger                      _columnPadding;
    NSIndexPath*                    _selectedIndexPath;
}

@property (nonatomic, assign) IBOutlet id<AMSpringboardViewDelegate> delegate;
@property (nonatomic, assign) IBOutlet id<AMSpringboardViewDataSource> dataSource;

- (AMSpringboardViewCell*) dequeueReusableCellWithIdentifier:(NSString*)identifier;

- (void) reloadData;

@property (nonatomic, assign) NSInteger currentPage;

- (NSIndexPath*) positionForPoint:(CGPoint)point;

@end




#pragma mark -
@protocol AMSpringboardViewDataSource <NSObject>

@required
- (NSInteger) numberOfPagesInSpringboardView:(AMSpringboardView*)springboardView;
- (NSInteger) numberOfRowsInSpringboardView:(AMSpringboardView*)springboardView;
- (NSInteger) numberOfColumnsInSpringboardView:(AMSpringboardView*)springboardView;
- (AMSpringboardViewCell*) springboardView:(AMSpringboardView*)springboardView cellForPositionWithIndexPath:(NSIndexPath*)indexPath;

@end




#pragma mark -
@protocol AMSpringboardViewDelegate <NSObject>

@required
- (void) springboardView:(AMSpringboardView*)springboardView didSelectCellWithPosition:(NSIndexPath*)position;

@end

