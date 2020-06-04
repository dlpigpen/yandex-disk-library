/* Лицензионное соглашение на использование набора средств разработки
 * «SDK Яндекс.Диска» доступно по адресу: http://legal.yandex.ru/sdk_agreement
 */


#import "YOAuth2ViewController.h"
#import "NSNotificationCenter+Additions.h"
#import "YDConstants.h"
#import <WebKit/WebKit.h>

@interface YOAuth2ViewController ()

@property (nonatomic, assign) BOOL appeared;
@property (nonatomic, assign) BOOL done;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, copy, readwrite) NSString *token;

@end


@implementation YOAuth2ViewController

@synthesize token = _token;
@synthesize delegate = _delegate;

- (instancetype)initWithDelegate:(id<YOAuth2Delegate>)authDelegate
{
    self = [super init];
    if (self) {
        _delegate = authDelegate;
    }
    return self;
}

- (void)loadView
{
    WKWebViewConfiguration *webConfiguration = [[WKWebViewConfiguration alloc] init];
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration: webConfiguration];

    self.webView = webView;
    self.webView.UIDelegate = self;
    self.webView.navigationDelegate = self;

    self.view = self.webView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setTitle:@"Sign-In"];
    
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:@"Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36", @"UserAgent", nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
    
    NSURL *url = [NSURL URLWithString:self.authURI];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];

    [self.webView loadRequest:request];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.appeared = YES;
    [self handleResult];
}

#pragma mark - UIWebViewDelegate methods

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    if (navigationAction.navigationType == UIWebViewNavigationTypeLinkClicked) {
        NSString *uri = navigationAction.request.URL.absoluteString;
        if ([uri hasPrefix:self.delegate.redirectURL]) { // did we get redirected to the redirect url?
            NSArray *split = [uri componentsSeparatedByString:@"#"];
            NSString *param = split[1];
            split = [param componentsSeparatedByString:@"&"];
            NSMutableDictionary *paraDict = [NSMutableDictionary dictionary];

            for (NSString *s in split) {
                NSArray *kv = [s componentsSeparatedByString:@"="];
                if (kv) {
                    paraDict[kv[0]] = kv[1];
                }
            }

            if (paraDict[@"access_token"]) {
                self.token = paraDict[@"access_token"];
                self.done = YES;
            }
            else if (paraDict[@"error"]) {
                self.error = [NSError errorWithDomain:kYDSessionAuthenticationErrorDomain
                                                 code:kYDSessionErrorUnknown
                                             userInfo:paraDict];
                self.done = YES;
            }
            [self handleResult];
        }
        decisionHandler(WKNavigationActionPolicyCancel);
    }
    


    decisionHandler(WKNavigationActionPolicyAllow);
}


- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSString *uri = request.URL.absoluteString;
    if ([uri hasPrefix:self.delegate.redirectURL]) { // did we get redirected to the redirect url?
        NSArray *split = [uri componentsSeparatedByString:@"#"];
        NSString *param = split[1];
        split = [param componentsSeparatedByString:@"&"];
        NSMutableDictionary *paraDict = [NSMutableDictionary dictionary];

        for (NSString *s in split) {
            NSArray *kv = [s componentsSeparatedByString:@"="];
            if (kv) {
                paraDict[kv[0]] = kv[1];
            }
        }

        if (paraDict[@"access_token"]) {
            self.token = paraDict[@"access_token"];
            self.done = YES;
        }
        else if (paraDict[@"error"]) {
            self.error = [NSError errorWithDomain:kYDSessionAuthenticationErrorDomain
                                             code:kYDSessionErrorUnknown
                                         userInfo:paraDict];
            self.done = YES;
        }
        [self handleResult];
    }
    return !self.done;
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (!self.done) {
           NSLog(@"%@", error.localizedDescription);
           [self handleError:error];
    }
}

- (NSString *)authURI
{
    return [NSString stringWithFormat:@"https://oauth.yandex.com/authorize?response_type=token&client_id=%@&display=popup", self.delegate.clientID];
}

- (void)handleResult
{
    if (self.done && self.appeared) {
        if (self.token) {
            [self.delegate OAuthLoginSucceededWithToken:self.token];
            [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidAuthNotification
                                                                               object:self
                                                                             userInfo:@{@"token": self.token}];
        } else if (self.error) {
            [self handleError:self.error];
        }
    }
}

- (void)handleError:(NSError *)error
{
    [self.delegate OAuthLoginFailedWithError:error];
    [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidFailWithAuthRequestNotification
                                                                       object:self
                                                                     userInfo:@{@"error": error}];
}

@end
