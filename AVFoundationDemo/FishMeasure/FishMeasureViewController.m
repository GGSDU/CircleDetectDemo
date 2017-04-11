//
//  ViewController.m
//  AVFoundationDemo
//
//  Created by Story5 on 4/6/17.
//  Copyright © 2017 Story5. All rights reserved.
//

#import "FishMeasureViewController.h"
#import "CoinDetectView.h"

@interface FishMeasureViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (nonatomic,strong) CoinDetectView *coinDetectView;

@end

@implementation FishMeasureViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSLog(@"%s",__func__);
    self.view.backgroundColor = [UIColor redColor];
 
    self.coinDetectView = [[CoinDetectView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.coinDetectView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.coinDetectView startRunning];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self.coinDetectView stopRunning];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self.coinDetectView stopRunning];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end