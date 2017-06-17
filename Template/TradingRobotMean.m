classdef TradingRobotMean < AutoTrader
    properties
        depth = struct
        optionISIN = struct
        time = 0
        
        % Amount - Delta - Gamma
        portfolio = zeros(21, 3)
        
        MIN = 20;
        MAX = 30;
    end
    
    methods
        function HandleDepthUpdate(aBot, ~, aDepth)
            DAYS_IN_YEARS = 254;
            
            % Store the available option ISINs
            if(aBot.time == 0)
                nOption = GetAllOptionISINs();
                
                [~, T, p, K] = ParseOptionISINs(nOption);
                
                T = (T - now())/DAYS_IN_YEARS;
                
                aBot.optionISIN = struct('ISIN', [], 'T', T, 'p', p, 'K', K);
                
                aBot.optionISIN.ISIN = nOption;
            end
            ISIN = aDepth.ISIN;
            
            % Update time if its a stock depth update
            if(strcmp(ISIN,'ING'))
                aBot.time = aBot.time + 1;
            end
            aTime = strcat('t', num2str(aBot.time));
            
            % Store the depth of the stocks
            aBot.depth.(aTime).(ISIN) = struct(aDepth);
            
            % Calculate the stock price if it's a stock depth update
            if(strcmp(ISIN,'ING'))
                CalculateStockPrice(aBot);
                CalculateStockVolatility(aBot);
            % And the Greeks/IV if it's an option
            else 
                CalculateIV(aBot,ISIN);
                CalculateGreeks(aBot,ISIN);
            end
            
            if(aBot.time > aBot.MIN)
                TryArbitrage(aBot);
                Hedge(aBot);
            end
        end
        
        %% Try to arbitrage
        function TryArbitrage(aBot)
            ALPHA = 0.1;
            
            % We look at the previous depth. 
            aTime = strcat('t', num2str(aBot.time - 1));
            
            % Calculate mean
            options = fieldnames(aBot.depth.(aTime));
            
            if length(options) > 1
                meanIV = 0;
                n = 0;
                
                for f = options'
                    if not(strcmp(f{1}, 'ING')) && ~isnan(aBot.depth.(aTime).(f{1}).IV)
                        meanIV = meanIV + aBot.depth.(aTime).(f{1}).IV;
                        n = n + 1;
                    end
                end
                
               meanIV = meanIV/n;
                
                % Buy options under mean
                for f = options'
                    if not(strcmp(f{1}, 'ING')) && ~isnan(aBot.depth.(aTime).(f{1}).IV)
                        if(aBot.depth.(aTime).(f{1}).IV < meanIV* (1-ALPHA))
                            TradeBestListing(aBot, f{1}, 1);
                        elseif(aBot.depth.(aTime).(f{1}).IV > meanIV*(1+ALPHA))
                            TradeBestListing(aBot, f{1}, -1);
                        end
                    end
                end
            end
        end
        
        %% Function used to get the position at 0 again
        function Unwind(aBot)
            
            times = fieldnames(aBot.depth);
            lastTime = times(end);
            stockPrice = aBot.depth.(lastTime{1}).ING.stockPrice;
            
            % Stock - call + put = 0
            position = aBot.portfolio(21, 1);
            
            for i=1:length(aBot.optionISIN.ISIN)
                
                [~, ~, ~, strikePrice] = ParseOptionISINs(aBot.optionISIN.ISIN(i));
                
                if aBot.optionISIN.p(i) == 0 && strikePrice < stockPrice 
                    position = position + aBot.portfolio(i, 1);
                elseif strikePrice > stockPrice 
                    position = position - aBot.portfolio(i, 1);
                end
            end
            
            if position > 0
               debug = 0; 
            end
        end
        
        %% function to send the orders
        function TradeBestListing(aBot, ISIN, side)
            aTime = strcat('t', num2str(aBot.time - 1));
            
            myVolume = 0;
            
            if(isfield(aBot.depth.(aTime), ISIN))
                if(side == 1 && ~isempty(aBot.depth.(aTime).(ISIN).askLimitPrice))
                    myAskPrice = aBot.depth.(aTime).(ISIN).askLimitPrice(1);
                    myVolume = aBot.depth.(aTime).(ISIN).askVolume(1);            

                    aBot.SendNewOrder(myAskPrice, myVolume, 1, {ISIN}, {'IMMEDIATE'}, 0);
                elseif(~isempty(aBot.depth.(aTime).(ISIN).bidLimitPrice))
                    myBidPrice = aBot.depth.(aTime).(ISIN).bidLimitPrice(1);
                    myVolume = aBot.depth.(aTime).(ISIN).bidVolume(1);

                    aBot.SendNewOrder(myBidPrice, myVolume, -1, {ISIN}, {'IMMEDIATE'}, 0);
                end
            end

            % The position of ISIN in optionISIN (1 - 21)
            if(~strcmp(ISIN,'ING'))
                for i=1:length(aBot.optionISIN.ISIN)
                    cell = aBot.optionISIN.ISIN(i);
                    if(strcmp(cell{1}, ISIN))
                        n = i;
                        break;
                    end
                end
            end
            
            aBot.portfolio(n, 1) = aBot.portfolio(n, 1) + myVolume*side;
        end
        
        %% Hedge using stocks
        function Hedge(aBot)
            aTime = strcat('t', num2str(aBot.time));
          
            for i=1:length(aBot.optionISIN.ISIN)
                if(aBot.portfolio(i, 1) ~= 0)
                    S = aBot.depth.(aTime).ING.stockPrice;
                    K = aBot.optionISIN.K(i);
                    T = aBot.optionISIN.T(i);
                    IV = aBot.depth.(aTime).ING.IV;
                    p = aBot.optionISIN.p(i);
                    BSM = BS(S, K, T, IV, p);
                    
                    aBot.portfolio(i, 2) = floor(aBot.portfolio(i, 1) * BSM(2, 1));
                    aBot.portfolio(i, 3) = floor(aBot.portfolio(i, 1) * BSM(3, 1));
                end
            end
            
            if sum(aBot.portfolio(:, 1)) > 0
                delta = floor(sum(aBot.portfolio(:, 2)));
                
                if(delta ~= 0)
                    if(delta < 0 && ~isempty(aBot.depth.(aTime).ING.askLimitPrice))
                        myAskPrice = aBot.depth.(aTime).ING.askLimitPrice(1);
                        myVolume = min(aBot.depth.(aTime).ING.askVolume(1),abs(delta));            

                        aBot.SendNewOrder(myAskPrice, myVolume, 1, {'ING'}, {'IMMEDIATE'}, 0);    
                        aBot.portfolio(21, 1) = aBot.portfolio(21, 1) + myVolume;
                    elseif(~isempty(aBot.depth.(aTime).ING.bidLimitPrice))
                        myBidPrice = aBot.depth.(aTime).ING.bidLimitPrice(1);
                        myVolume = min(aBot.depth.(aTime).ING.bidVolume(1),delta);

                        aBot.SendNewOrder(myBidPrice, myVolume, -1, {'ING'}, {'IMMEDIATE'}, 0);
                        aBot.portfolio(21, 1) = aBot.portfolio(21, 1) - myVolume;
                    end
                    
                    % Delta of stock is 1
                    aBot.portfolio(21, 2) = aBot.portfolio(21, 1);
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
        
         %% Calculates the stock price
        function CalculateStockVolatility(aBot)
            
            n = min(length(fieldnames(aBot.depth)) - 1, aBot.MAX);
            if(n > aBot.MIN)
                
                priceArray = zeros(n,1);

                % Average the last n values of the stock
                for i=1:n
                    aTime = strcat('t', num2str(aBot.time - i));
                    if(isfield(aBot.depth.(aTime).ING, 'stockPrice'))
                        priceArray(i) = aBot.depth.(aTime).ING.stockPrice;
                    end
                end
                
                aTime = strcat('t', num2str(aBot.time));
                
                percentageArray = zeros(length(priceArray),1);
                
                for i=2:length(priceArray)
                    percentageArray(i) = (priceArray(i) - priceArray(i-1))/priceArray(i)*100;
                end
                
                aBot.depth.(aTime).ING(1).IV = std(percentageArray);
                
            end
        end
        
        %%  Calculates the implied volatility
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
        
        %% extra function
        function varargout = curly(x, varargin)
            [varargout{1:nargout}] = x{varargin{:}};
        end
    end
end