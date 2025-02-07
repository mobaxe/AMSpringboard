//
//  AMSpringboardView.m
//  AMSpringboardView
//
//  Created by Andy Mroczkowski on 2/19/11.
//  Copyright 2011 Andy Mroczkowski. All rights reserved.
//

#import "AMSpringboardView.h"

#import <AMFoundation/AMGeometry.h>
#import "NSIndexPath+AMSpringboard.h"

#define kDefaultColumnPadding (1)
#define VALID_SPRINBOARD_CELL(obj) obj != nil && obj != [NSNull null]
#define kCellHighlightDelay (0.1)

@interface AMSpringboardView ()
@property (nonatomic, retain) UIScrollView* scrollView;
@property (nonatomic, retain) UIPageControl* pageControl;
@property (nonatomic, retain) UIView* contentView;
@property (nonatomic, retain) NSMutableDictionary* cells;
@property (nonatomic, retain) NSMutableArray* unusedCells;
@property (nonatomic, assign) NSUInteger columnPadding;
@property (nonatomic, retain) NSIndexPath* selectedPosition;
- (NSInteger) pageCount;
- (NSInteger) rowCount;
- (NSInteger) columnCount;
- (CGRect) activeRect;
- (NSArray*) positionsIntersectingRect:(CGRect)rect;
- (void) addCellToView:(AMSpringboardViewCell*)cell position:(NSIndexPath*)position;
- (void) setFrameForCell:(AMSpringboardViewCell*)cell position:(NSIndexPath*)position;
@end


@interface AMSpringboardContentView : UIView
@property (nonatomic, assign) AMSpringboardView* springboardView;
@property (nonatomic, retain) NSTimer* highlightTimer;
@end


@implementation AMSpringboardView

@synthesize dataSource = _dataSource;
@synthesize delegate = _delegate;
@synthesize scrollView = _scrollView;
@synthesize pageControl = _pageControl;
@synthesize contentView = _contentView;
@synthesize cells = _cells;
@synthesize unusedCells = _unusedCells;
@synthesize columnPadding = _columnPadding;
@synthesize selectedPosition = _selectedIndexPath;


- (void) updatePageControlFrame
{
	CGRect pageControlFrame = CGRectZero;
	pageControlFrame.size = [_pageControl sizeForNumberOfPages:[self pageCount]];
	pageControlFrame.origin.x = (self.bounds.size.width - pageControlFrame.size.width) / 2.;
	pageControlFrame.origin.y = self.bounds.size.height - pageControlFrame.size.height;
	_pageControl.frame = pageControlFrame;
	_pageControl.numberOfPages = [self pageCount];
}


// call after updatePageControlFrame
- (void) updateScrollViewFrame
{
    CGRect scrollViewFrame = self.bounds;
    if( !self.pageControl.hidden )
    {
        scrollViewFrame.size.height -= self.pageControl.frame.size.height;
    }
	
	// see: http://stackoverflow.com/questions/2653785/uiscrollview-doesnt-bounce/3231675#3231675
	if( !CGRectEqualToRect(self.scrollView.frame, scrollViewFrame) )
	{
		self.scrollView.frame = scrollViewFrame;
	}
    
    [self.contentView setFrame:CGRectMake(0, 0,
                                          self.scrollView.bounds.size.width * [self pageCount],
                                          self.scrollView.bounds.size.height)];
    
    self.scrollView.contentSize = self.contentView.bounds.size;
}


- (void) _init
{
    _cells = [[NSMutableDictionary alloc] init];
    _unusedCells = [[NSMutableArray alloc] init];
    _columnPadding = kDefaultColumnPadding;
    
	_pageControl = [[UIPageControl alloc] initWithFrame:CGRectZero];
	_pageControl.hidesForSinglePage = YES;
	_pageControl.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    _pageControl.backgroundColor = [UIColor clearColor];
	[self addSubview:_pageControl];
	
    //    AMSpringboardScrollView* springboardScroll = [[AMSpringboardScrollView alloc] initWithFrame:CGRectZero];
    //    springboardScroll.springboardView = self;
    UIScrollView* springboardScroll = [[UIScrollView alloc] initWithFrame:CGRectZero];    
    
	_scrollView = springboardScroll;
	_scrollView.delegate = self;
	_scrollView.pagingEnabled = YES;
    _scrollView.bounces = YES;
    _scrollView.alwaysBounceHorizontal = YES;
    _scrollView.delaysContentTouches = NO;
    _scrollView.directionalLockEnabled = YES;
	_scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.contentOffset = CGPointZero;
    [self addSubview:_scrollView];
    
    AMSpringboardContentView* contentView = [[AMSpringboardContentView alloc] initWithFrame:CGRectZero];
    contentView.springboardView = self;
    [_scrollView addSubview:contentView];
    self.contentView = contentView;
    self.contentView.backgroundColor = [UIColor clearColor];
    [contentView release];
    
//    [self performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
}


- (id) initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self != nil)
	{
		[self _init];
	}
	return self;
}


- (id) initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self != nil)
	{
		[self _init];
	}
	return self;
}


- (void) dealloc
{
	[_pageControl release];
	[_scrollView release];
    [_contentView release];
    [_unusedCells release];
    [_cells release];
	[super dealloc];
}


- (void) addUnusedCell:(AMSpringboardViewCell*)cell
{
    // -- only save a columns worth of cells
    if( [self.unusedCells count] < [self columnCount] )
    {
        [self.unusedCells addObject:cell];
    }
}


- (NSInteger) pageCount
{
	return [self.dataSource numberOfPagesInSpringboardView:self];
}


- (NSInteger) rowCount
{
	return [self.dataSource numberOfRowsInSpringboardView:self];
}


- (NSInteger) columnCount
{
	return [self.dataSource numberOfColumnsInSpringboardView:self];
}


- (NSInteger) currentPage
{
    return lround(self.scrollView.contentOffset.x / self.scrollView.bounds.size.width);
}


- (void) setCurrentPage:(NSInteger)currentPage
{
    [self willChangeValueForKey:@"currentPage"];
    CGPoint offset = CGPointZero;
    offset.x = self.scrollView.bounds.size.width * currentPage;
    self.scrollView.contentOffset = offset;
    [self didChangeValueForKey:@"currentPage"];
}


- (CGRect) zoneRectForCellWithPosition:(NSIndexPath*)position
{
    if( !([self columnCount] > 0 && [self rowCount] > 0) )
        return CGRectZero;
    
    CGSize pageSize = self.scrollView.bounds.size;
    CGFloat zoneWidth = (((CGFloat)pageSize.width) / [self columnCount]);
    CGFloat zoneHeight = (((CGFloat)pageSize.height) / [self rowCount]);
    
    CGRect rect = CGRectZero;
    rect.origin.x = [position springboardPage] * pageSize.width;
    rect.origin.x += zoneWidth * [position springboardColumn];
    rect.origin.y =  zoneHeight * [position springboardRow];
    rect.size.width = zoneWidth;
    rect.size.height = zoneHeight;
    
    return CGRectIntegral(rect);
}


- (CGPoint) centerForCellWithPosition:(NSIndexPath*)position
{
    return AMRectCenter([self zoneRectForCellWithPosition:position]);
}


- (AMSpringboardViewCell*) getCellForPosition:(NSIndexPath*)position
{
    AMSpringboardViewCell* cell = [self.cells objectForKey:position];
    if( cell == nil )
    {
        //NSLog(@"getting: %@", position);
        cell = [self.dataSource springboardView:self cellForPositionWithIndexPath:position];
        //NSLog(@"got: %@", cell);
        if( cell != nil )
        {
            [self.cells setObject:cell forKey:position];
        }
        else
        {
            [self.cells setObject:[NSNull null] forKey:position];
        }
    }
    return cell;
}


- (void) updateCellsForPositions:(NSArray*)positions
{
    for( NSIndexPath* position in positions )
    {
        id cell = [self getCellForPosition:position];
        if( VALID_SPRINBOARD_CELL(cell) )
        {
            if( [cell superview] == nil )
            {
                [self addCellToView:cell position:position];
            }
            else
            {
                [self setFrameForCell:cell position:position];
            }
            [cell setNeedsDisplay];
        }
    }
}


- (void) layoutSubviews
{
    [self updatePageControlFrame];
    [self updateScrollViewFrame];
    
    NSArray* positions = [self positionsIntersectingRect:[self activeRect]];
    [self updateCellsForPositions:positions];
}


- (void) reloadData
{
	self.pageControl.numberOfPages = [self pageCount];
    
    for( id cell in [self.cells allValues] )
    {
        if( [cell respondsToSelector:@selector(removeFromSuperview)] )
            [cell removeFromSuperview];
    }
    
    [self.cells removeAllObjects];
    [self.unusedCells removeAllObjects];
    
    NSArray* positions = [self positionsIntersectingRect:[self activeRect]];
    [self updateCellsForPositions:positions];
    
    [self setNeedsLayout];
}


- (AMSpringboardViewCell*) dequeueReusableCellWithIdentifier:(NSString*)identifier
{
    AMSpringboardViewCell* dequeuedCell = nil;
    
    for( AMSpringboardViewCell* cell in self.unusedCells )
    {
        if( [cell.reuseIdentifier isEqualToString:identifier] )
        {
            dequeuedCell = cell;
            break;
        }
    }
    
    if( dequeuedCell != nil )
    {
        [[dequeuedCell retain] autorelease]; // make sure it doesn't get dealloc'd
        [self.unusedCells removeObject:dequeuedCell];
    }
    
    return dequeuedCell;
}

- (void) setFrameForCell:(AMSpringboardViewCell*)cell position:(NSIndexPath*)position
{
    CGPoint center = [self centerForCellWithPosition:position];
    CGRect frame = AMRectMakeWithCenterAndSize( center, cell.bounds.size );
    cell.frame = CGRectIntegral(frame);
    //NSLog(@"set for cell:%@", cell);
}


- (void) addCellToView:(AMSpringboardViewCell*)cell position:(NSIndexPath*)position
{
    //NSLog( @"adding: %@", cell );
    [self setFrameForCell:cell position:position];
    [self.contentView addSubview:cell];
    [cell setNeedsDisplay];
}


- (void) loadCellsForPage:(NSInteger)page column:(NSInteger)column
{
    if( page < 0 || page >= [self pageCount] )
        return;
    
    if( column < 0 || column >= [self columnCount] )
        return;
    
    for( NSInteger row=0; row<[self rowCount]; row++ )
    {
        NSIndexPath* position = [NSIndexPath indexPathForSpringboardPage:page column:column row:row];
        AMSpringboardViewCell* cell = [self getCellForPosition:position];
        if( cell != nil )
        {
            [self addCellToView:cell position:position];
        }
    }
}


- (CGFloat) pageWidth
{
    return self.scrollView.bounds.size.width;
}


- (NSIndexPath*) positionForPoint:(CGPoint)point
{
    if( !([self columnCount] > 0 && [self rowCount] > 0) )
        return nil;
        
    CGSize pageSize = self.scrollView.bounds.size;
    if( pageSize.width == 0 || pageSize.height == 0 )
        return nil;
    
    point = AMPointClampedToRect(point, self.contentView.bounds);
    
    NSInteger page =  floor(point.x / pageSize.width);
    
    NSInteger col =  floor((point.x - (page * pageSize.width))
                           / (pageSize.width / [self columnCount]));
    col = MIN([self columnCount]-1, col);
    
    NSInteger row = floor(point.y / (pageSize.height / [self rowCount]));
    row = MIN([self rowCount]-1, row);
    
    return [NSIndexPath indexPathForSpringboardPage:page column:col row:row];
}


- (NSArray*) positionsIntersectingRect:(CGRect)rect
{
    NSMutableArray* positions = [NSMutableArray array];
    
    NSIndexPath* topLeft = [self positionForPoint:
                            CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect))];
    NSIndexPath* botRight = [self positionForPoint:
                             CGPointMake(CGRectGetMaxX(rect)-1, CGRectGetMaxY(rect)-1)];
    
    //NSLog(@"top left: %@", topLeft );
    //NSLog(@"bot right: %@", botRight );
    
    NSIndexPath* cur = topLeft;
    while(1)
    {
        for( NSInteger row=[topLeft springboardRow]; row<=[botRight springboardRow]; row++ )
        {
            [positions addObject:[NSIndexPath indexPathForSpringboardPage:[cur springboardPage]
                                                                   column:[cur springboardColumn]
                                                                      row:row]];
        }
        
        if( ([cur springboardPage] == [botRight springboardPage] && 
             [cur springboardColumn] == [botRight springboardColumn]) )
            break;
        
        NSInteger nextPage = [cur springboardPage];
        NSInteger nextCol = ([cur springboardColumn]+1) % [self columnCount];
        if( nextCol < [cur springboardColumn] ) nextPage++;
        cur = [NSIndexPath indexPathForSpringboardPage:nextPage
                                                column:nextCol
                                                   row:[topLeft springboardRow]];
        
        if( [cur springboardPage] == [self pageCount] )
            break;
    }
    
    return positions;
}


- (CGRect) activeRect
{
    // make sure there is at least 1 column
    NSInteger columnCount = [self columnCount];
    if( columnCount <= 0 )
        return CGRectZero;
    
    CGRect rect;    
    CGFloat widthPad = ([self pageWidth] / columnCount) * self.columnPadding;
    rect.origin.x = self.scrollView.contentOffset.x - widthPad;
    rect.origin.y = self.scrollView.contentOffset.y;
    rect.size.width = self.scrollView.bounds.size.width + (widthPad*2); // double to accomodate the left width
    rect.size.height = self.scrollView.bounds.size.height;
    //NSLog(@"activeRect:%@", NSStringFromCGRect(rect));
    return rect;
}


#pragma UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{    
    CGRect visibleFrame = [self activeRect];
    
    for( NSIndexPath* pos in [[[self.cells allKeys] copy] autorelease] )
    {
        id cell = [self.cells objectForKey:pos];
        if( cell != nil )
        {
            CGRect zone = [self zoneRectForCellWithPosition:pos];
            if( !CGRectIntersectsRect(zone, visibleFrame) )
            {
                //NSLog( @"pruning: %@", pos );
                if( cell != [NSNull null] )
                {
                    [self addUnusedCell:cell];
                    [cell removeFromSuperview];
                }
                [self.cells removeObjectForKey:pos];
            }
        }
    }
    
    //NSLog(@"visible rect: %@", NSStringFromCGRect(visibleFrame));
    NSArray* positions = [self positionsIntersectingRect:visibleFrame];
    [self updateCellsForPositions:positions];
    
    // -- recalculate page control    
    self.pageControl.currentPage = self.currentPage;
}


- (void) deselectCellWithPosition:(NSIndexPath*)position
{
    id cell = [self getCellForPosition:position];
    if( VALID_SPRINBOARD_CELL(cell) )
    {
        [cell setHighlighted:NO];
    }
    self.selectedPosition = nil;
}


- (void) deselectSelectedCell
{
    if( self.selectedPosition )
    {
        [self deselectCellWithPosition:self.selectedPosition];
    }
}


- (void) selectCellWithPosition:(NSIndexPath*)position
{
    if( self.selectedPosition != nil )
    {
        [self deselectCellWithPosition:position];
    }
    
    id cell = [self getCellForPosition:position];
    if( VALID_SPRINBOARD_CELL(cell) )
    {
        [cell setHighlighted:YES];
        self.selectedPosition = position;
    }
}


- (void) informDelegateOfSelectedCellPosition
{
    if( self.selectedPosition != nil )
    {
        [self.delegate springboardView:self
             didSelectCellWithPosition:self.selectedPosition];
        [self performSelector:@selector(deselectSelectedCell) withObject:nil afterDelay:0.0];
    }
}


- (BOOL) isValidPosition:(NSIndexPath*)position
{
    if( [position springboardPage] >= [self pageCount] ) // unsigned so don't have to check for negative
        return NO;
    
    if( [position springboardColumn] >= [self columnCount] ) // unsigned so don't have to check for negative
        return NO;
    
    if( [position springboardRow] >= [self rowCount] ) // unsigned so don't have to check for negative
        return NO;
    
    return YES;
}

@end


// -----------------------------------------------------------------------------------
#pragma -
@implementation AMSpringboardContentView


@synthesize springboardView = _springboardView;
@synthesize highlightTimer = _highlightTimer;

- (void)dealloc 
{
    [_highlightTimer invalidate];
    [_highlightTimer release];
    [super dealloc];
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch* touch = [touches anyObject];
    CGPoint p = [touch locationInView:self.springboardView.contentView];
    
    NSIndexPath* position = [self.springboardView positionForPoint:p];
    
    self.highlightTimer = [NSTimer scheduledTimerWithTimeInterval:kCellHighlightDelay
                                                           target:self
                                                         selector:@selector(highlightTimerFired:)
                                                         userInfo:position
                                                          repeats:NO];
}


- (void) highlightTimerFired:(NSTimer*)timer
{
    NSIndexPath* position = [timer userInfo];
    if( [self.springboardView isValidPosition:position] )
    {
        [self.springboardView selectCellWithPosition:position];
    }
}


- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.highlightTimer invalidate];
    [self.springboardView deselectSelectedCell];
}


- (void) touchesEnded: (NSSet *) touches withEvent: (UIEvent *) event
{
    [self.highlightTimer fire];
    [self.highlightTimer invalidate];
    [self.springboardView informDelegateOfSelectedCellPosition];
}


@end
