classdef TradingRobot < AutoTrader
    properties
        depth = struct
        optionISIN = struct
        time = 0
        
        % The position at the ING
        myINGPosition = zeros(1,1)
    end

    methods
        function HandleDepthUpdate(aBot, ~, aDepth)
            DAYS_IN_YEARS = 254;
            
            %% Store the available option ISINs
            if(aBot.time == 0)
                nOption = GetAllOptionISINs();
                
                [~, T, p, K] = ParseOptionISINs(nOption);
                
                T = (T - now())/DAYS_IN_YEARS;
                
                aBot.optionISIN = struct('ISIN', [], 'T', T, 'p', p, 'K', K);

                aBot.optionISIN.ISIN = nOption;
            end
            
            %% Update time if its a stock depth update
            ISIN = aDepth.ISIN;
            
            if(strcmp(ISIN,'ING'))
                aBot.time = aBot.time + 1;
            end
            aTime = strcat('t', num2str(aBot.time));
            
            %% Store the depth of the stocks
            aBot.depth.(aTime).(ISIN) = struct(aDepth);
            
            %% Calculate the stock price if it's a stock depth update
            if(strcmp(ISIN,'ING'))
                CalculateStockPrice(aBot);
            else % And the Greeks/IV if it's an option
                CalculateIV(aBot,ISIN);
                CalculateGreeks(aBot,ISIN);
            end
            
            %% look for arbitrage opportunities in the options
            k=0;
            for i=1:length(aBot.optionISIN.ISIN)-1
                cell1 = aBot.optionISIN.ISIN(i);
                cell2 = aBot.optionISIN.ISIN(i+1);
                if(strcmp(cell1{1}, ISIN))
                    k = i;
                    break;
                end
            end
            
            if k~= 0
                if (aBot.optionISIN.p(k) == 0 && isfield(aBot.depth.(aTime).ING, 'stockPrice'))
                    stockPrice = aBot.depth.(aTime).ING.stockPrice;
                    strikePrice = aBot.optionISIN.K(k);
                    if (isfield(aBot.depth.(aTime),(cell1{1})) && isfield(aBot.depth.(aTime),(cell2{1})))
                        if (~isempty(aBot.depth.(aTime).(cell1{1}).askLimitPrice) && ...
                            ~isempty(aBot.depth.(aTime).(cell2{1}).askLimitPrice))
                            optionCallPrice = aBot.depth.(aTime).(cell1{1}).askLimitPrice(1);
                            optionPutPrice = aBot.depth.(aTime).(cell2{1}).askLimitPrice(1);
                            %by using the put call parity we can see if the
                            %put or the call is undervalued
                            if optionPutPrice + stockPrice - strikePrice < optionCallPrice
                                %we buy the undervalued one
                                aBot.TradeBestListing(cell2{1},1);
                                aBot.TradeBestListing('ING',1);
                            else
                                aBot.TradeBestListing(cell1{1},1);
                                aBot.TradeBestListing('ING',-1);
                            end
                        end
                    end    
                end
            end
        end
        
        %% Calculates the stock price
        function CalculateStockPrice(aBot)
            aTime = strcat('t', num2str(aBot.time));
            
            if(isempty(aBot.depth.(aTime).ING.askLimitPrice))
                askLimitPrice = [];
            else
                askLimitPrice = aBot.depth.(aTime).ING.askLimitPrice;
            end
            
            if(isempty(aBot.depth.(aTime).ING.bidLimitPrice))
                bidLimitPrice = [];
            else
                bidLimitPrice = aBot.depth.(aTime).ING.bidLimitPrice;
            end
            
            aBot.depth.(aTime).ING.stockPrice = ...
                Average(askLimitPrice, bidLimitPrice);
        end
        
        %%  Calculates the implied volatility by averaging the value found
        %   using the bid and ask
        function CalculateIV(aBot, ISIN)
            aTime = strcat('t', num2str(aBot.time));

            % The position of ISIN in optionISIN
            for i=1:length(aBot.optionISIN.ISIN)
                cell = aBot.optionISIN.ISIN(i);
                if(strcmp(cell{1}, ISIN))
                    n = i;
                    break;
                end
            end
            
            % The stockprice needs to be defined to calculate IV
            if isfield(aBot.depth.(aTime).ING, 'stockPrice')
                if ~isempty(aBot.depth.(aTime).(ISIN).askLimitPrice)
                    optionAskIV = IV(aBot.depth.(aTime).ING.stockPrice, ...
                        aBot.optionISIN.K(n),...
                        aBot.optionISIN.T(n),...
                        aBot.depth.(aTime).(ISIN).askLimitPrice(1),...
                        aBot.optionISIN.p(n));
                else
                    optionAskIV = [];
                end
                
                if ~isempty(aBot.depth.(aTime).(ISIN).bidLimitPrice)
                    optionBidIV = IV(aBot.depth.(aTime).ING.stockPrice, ...
                        aBot.optionISIN.K(n),...
                        aBot.optionISIN.T(n),...
                        aBot.depth.(aTime).(ISIN).bidLimitPrice(1),...
                        aBot.optionISIN.p(n));
                else
                    optionBidIV = [];
                end
                
                aBot.depth.(aTime).(ISIN).IV = Average(optionAskIV,optionBidIV);
            end
        end
        
        %% Calculates the Greeks
        function CalculateGreeks(aBot,ISIN)
            aTime = strcat('t', num2str(aBot.time));
            
            % The position of ISIN in optionISIN
            for i=1:length(aBot.optionISIN.ISIN)
                cell = aBot.optionISIN.ISIN(i);
                if(strcmp(cell{1}, ISIN))
                    n = i;
                    break;
                end
            end
            
            % The stockprice needs to be defined to calculate IV
            if isfield(aBot.depth.(aTime).ING, 'stockPrice')
                BSM = BS(aBot.depth.(aTime).ING.stockPrice, ...
                        aBot.optionISIN.K(n),...
                        aBot.optionISIN.T(n),...
                        aBot.depth.(aTime).(ISIN).IV,...
                        aBot.optionISIN.p(n));
                    aBot.depth.(aTime).(ISIN).Delta = BSM(2,1);
                    aBot.depth.(aTime).(ISIN).Gamma = BSM(3,1);
                    aBot.depth.(aTime).(ISIN).Vega  = BSM(4,1);
            end
        end
        
        %% function to send the orders
        function TradeBestListing(aBot, ISIN, side)
            aTime = strcat('t', num2str(aBot.time));
            if(side == 1)
                myAskPrice = aBot.depth.(aTime).(ISIN).askLimitPrice(1);
                myVolume = aBot.depth.(aTime).(ISIN).askVolume(1);
                            
                aBot.SendNewOrder(myAskPrice, myVolume, 1, {ISIN}, {'IMMEDIATE'}, 0);
                if(strcmp(ISIN, 'ING'))
                    aBot.myINGPosition(end+1) = aBot.myINGPosition(end) + 1 * myVolume;
                end
            else
                myBidPrice = aBot.depth.(aTime).(ISIN).bidLimitPrice(1);
                myVolume = aBot.depth.(aTime).(ISIN).bidVolume(1);
                            
                aBot.SendNewOrder(myBidPrice, myVolume, -1, {ISIN}, {'IMMEDIATE'}, 0);
                if(strcmp(ISIN, 'ING'))
                    aBot.myINGPosition(end+1) = aBot.myINGPosition(end) - 1 * myVolume;
                end
            end
        end
        
        %% Function used to get the positions at 0 again
        function Unwind(aBot)
            curly = @(x, varargin) x{varargin{:}};
            nTime = fieldnames(aBot.depth);
            lastTime = curly(nTime(end),1);
            
            nOption = GetAllOptionISINs();
            
            for i=1:length(aBot.ownTrades.volume)
                m=0;
                for k=1:20
                    cell1 = nOption(k);
                    cell2 = aBot.ownTrades.ISIN(i);
                    % IF ISIN equals the ISIN of an option we add it to
                    % the portfolio of that option
                    if (strcmp(cell1{1}, cell2{1}))
                        m=k;
                        break;
                    end
                end
                
                if aBot.myINGPosition(end)~=0
                    if m~=0
                        if aBot.optionISIN.p(m) == 0
                            myAskPrice = aBot.optionISIN.K(m);
                            aBot.ownTrades.volume(i);
                            aBot.depth.(lastTime).ING.askVolume(1);
                            aBot.myINGPosition(end);
                            myVolume = min(aBot.ownTrades.volume(i),min(aBot.depth.(lastTime).ING.askVolume(1),aBot.myINGPosition(end)));
                            
                            aBot.SendNewOrder(myAskPrice, myVolume, 1, {'ING'}, {'IMMEDIATE'}, 0);
                            aBot.myINGPosition(end+1) = aBot.myINGPosition(end) + 1 * myVolume
                        
                        else
                            myBidPrice = aBot.optionISIN.K(m);
                            aBot.ownTrades.volume(i);
                            aBot.depth.(lastTime).ING.bidVolume(1);
                            aBot.myINGPosition(end);
                            myVolume = min(aBot.ownTrades.volume(i),min(aBot.depth.(lastTime).ING.bidVolume(1),aBot.myINGPosition(end)));
                            
                            aBot.SendNewOrder(myBidPrice, myVolume, -1, {'ING'}, {'IMMEDIATE'}, 0);
                            aBot.myINGPosition(end+1) = aBot.myINGPosition(end) - 1 * myVolume
                        end
                    end
                end
            end
        end
        
        %% extra function
        function varargout = curly(x, varargin)
            [varargout{1:nargout}] = x{varargin{:}};
        end  
    end
end