clear myExchange;
clear myFeedPublisher;
clear myOptionsQuoter;
clear myTradingRobot;

load('ING2.mat');

myExchange = CreateExchangeOpt();

myFeedPublisher = FeedPublisher();
myExchange.RegisterAutoTrader(myFeedPublisher);
myFeedPublisher.StartAutoTrader(myExchange);

myOptionsQuoter = OptionsQuoter();
myExchange.RegisterAutoTrader(myOptionsQuoter);
myOptionsQuoter.StartAutoTrader(myExchange, myFeedPublisher);

myTradingRobot = TradingRobot();
%myAnalysisRobot = AnalysisRobot();

myExchange.RegisterAutoTrader(myTradingRobot);
%myExchange.RegisterAutoTrader(myAnalysisRobot);

myTradingRobot.StartAutoTrader(myExchange);
%myAnalysisRobot.StartAutoTrader(myExchange);

myFeedPublisher.StartVeryShortFeed(myFeed);
myTradingRobot.Unwind();
%myAnalysisRobot.ShowPlots();

curly = @(x, varargin) x{varargin{:}};
nTime = fieldnames(myTradingRobot.depth);
lastTime = curly(nTime(end),1);

Report(myTradingRobot.ownTrades, myTradingRobot.depth.(lastTime).ING.stockPrice);
%ReportPlots(myTradingRobot.ownTrades);