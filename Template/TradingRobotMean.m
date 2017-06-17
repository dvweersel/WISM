classdef TradingRobotMean < AutoTrader
    properties
        depth = struct
        optionISIN = struct
        time = 0
        
        % Amount - Delta - Gamma
        portfolio = zeros(21, 3)
        delta = []
        gamma = []
        
        % How many updates we use for the historical volatility
        N = 30;
        
        DAYS_IN_YEARS = 254;
    end
    
    methods
        function HandleDepthUpdate(aBot, ~, aDepth)
            
            % Store the available option ISINs
            if(aBot.time == 0)
                nOption = GetAllOptionISINs();
                
                [~, T, p, K] = ParseOptionISINs(nOption);
                
                T = (T - now())/aBot.DAYS_IN_YEARS;
                
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
            
            if(aBot.time > 1)
                TryArbitrage(aBot);
                Hedge(aBot);
            end
        end
        
        %% Try to arbitrage
        function TryArbitrage(aBot)
            ALPHA = 0.05;
            
            % We look at the previous depth.
            aTime = strcat('t', num2str(aBot.time - 1));
            
            options = fieldnames(aBot.depth.(aTime));
            
            % Calculate mean of all the option
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
                
                % Buy options signicantly under/above the historical mean of the stock
                % with a reasonable delta
                for i=1:length(aBot.optionISIN.ISIN)
                    ISIN = aBot.optionISIN.ISIN(i);
                    
                    if isfield(aBot.depth.(aTime), ISIN{1})
                        if ~isnan(aBot.depth.(aTime).(ISIN{1}).IV)
                            if(aBot.depth.(aTime).(ISIN{1}).IV < meanIV* (1-ALPHA)...
                                    && aBot.depth.(aTime).(ISIN{1}).Delta > 0.1)
                                TradeListing(aBot, ISIN{1}, 1);
                            elseif(aBot.depth.(aTime).(ISIN{1}).IV > meanIV*(1+ALPHA)...
                                    && aBot.depth.(aTime).(ISIN{1}).Delta > 0.1)
                                TradeListing(aBot, ISIN{1}, -1);
                            end
                        end
                    end
                end
            end
        end
        
        %% Hedge one last time
        function Unwind(aBot)
            
            Hedge(aBot);
        end
        
        %% function to send the orders
        function TradeListing(aBot, ISIN, side)
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
            
            % The position of ISIN in optionISIN (1 - 20)
            if(~strcmp(ISIN,'ING'))
                for i=1:length(aBot.optionISIN.ISIN)
                    cell = aBot.optionISIN.ISIN(i);
                    if(strcmp(cell{1}, ISIN))
                        n = i;
                        break;
                    end
                end
            end
            
            % Add it to the portfolio
            aBot.portfolio(n, 1) = aBot.portfolio(n, 1) + myVolume*side;
        end
        
        %% Hedge
        function Hedge(aBot)
            aTime = strcat('t', num2str(aBot.time));
            
            % Calculate portfolio delta and gamma
            for i=1:length(aBot.optionISIN.ISIN)
                if(aBot.portfolio(i, 1) ~= 0)
                    
                    [~, T, p, K] = ParseOptionISINs(aBot.optionISIN.ISIN(i));
                    
                    T = (T - now())/aBot.DAYS_IN_YEARS;
                    
                    S = aBot.depth.(aTime).ING.stockPrice;
                    IV = aBot.depth.(aTime).ING.IV;
                    BSM = BS(S, K, T, IV, p);
                    
                    aBot.portfolio(i, 2) = floor(aBot.portfolio(i, 1) * BSM(2, 1));
                    aBot.portfolio(i, 3) = floor(aBot.portfolio(i, 1) * BSM(3, 1));
                end
            end
            
            % If we have anything to hedge
            if sum(aBot.portfolio(:, 1)) > 0
                aBot.gamma = sum(aBot.portfolio(:, 3));
                aBot.delta = sum(aBot.portfolio(:, 2));
                
                % For options, we look at the last book
                lastTime = strcat('t', num2str(aBot.time - 1));
                
                % Look at the put-call pairs and try to hedge gamma
                if(aBot.gamma ~= 0)
                    for i=2:length(aBot.optionISIN.ISIN)/2
                        putISIN = aBot.optionISIN.ISIN(2*i);
                        callISIN = aBot.optionISIN.ISIN(2*i-1);
                        
                        % If the put-call pair exists in the depth...
                        if(isfield(aBot.depth.(lastTime), callISIN{1})...
                                && isfield(aBot.depth.(lastTime), putISIN{1})...
                                && aBot.portfolio(2*i, 3) + aBot.portfolio(2*i - 1, 3) ~= 0)
                            
                            callGamma = aBot.depth.(lastTime).(callISIN{1}).Gamma;
                            putGamma = aBot.depth.(lastTime).(putISIN{1}).Gamma;
                            
                            % We sell the option with the lowest gamma
                            if(aBot.portfolio(2*i - 1, 3) < aBot.portfolio(2*i, 3) ...
                                    && isfield(aBot.depth.(lastTime), callISIN{1}))
                                if ~isempty(aBot.depth.(lastTime).(callISIN{1}).bidLimitPrice)
                                    
                                    myBidPrice = aBot.depth.(lastTime).(callISIN{1}).bidLimitPrice(1);
                                    myVolume = min(aBot.depth.(lastTime).(callISIN{1}).bidVolume(1), floor(abs(putGamma*aBot.portfolio(2*i,1))));
                                    
                                    aBot.SendNewOrder(myBidPrice, myVolume, -1, callISIN, {'IMMEDIATE'}, 0);
                                    
                                    % Update the portfolio
                                    deltaOption = aBot.depth.(lastTime).(callISIN{1}).Delta;
                                    
                                    aBot.portfolio(2*i-1, 1) = aBot.portfolio(2*i-1, 1) - myVolume;
                                    aBot.portfolio(2*i-1, 2) = aBot.portfolio(2*i-1, 2) - aBot.portfolio(2*i-1, 1)*deltaOption;
                                end
                            elseif(isfield(aBot.depth.(lastTime), putISIN{1}))
                                if ~isempty(aBot.depth.(lastTime).(putISIN{1}).bidLimitPrice)
                                    
                                    myBidPrice = aBot.depth.(lastTime).(putISIN{1}).bidLimitPrice(1);
                                    myVolume = min(aBot.depth.(lastTime).(putISIN{1}).bidVolume(1), floor(abs(callGamma*aBot.portfolio(2*i-1,1))));
                                    
                                    aBot.SendNewOrder(myBidPrice, myVolume, -1, putISIN, {'IMMEDIATE'}, 0);
                                    
                                    % Update the portfolio, puts have
                                    % inverted delta
                                    deltaOption = aBot.depth.(lastTime).(putISIN{1}).Delta;
                                    aBot.portfolio(2, 1) = aBot.portfolio(2, 1) - myVolume;
                                    aBot.portfolio(2, 2) = aBot.portfolio(2, 2) + aBot.portfolio(2-1, 1)*deltaOption;
                                end
                            end
                        end
                        
                    end
                end
                if(aBot.delta ~= 0)
                    if(aBot.delta < 0 && ~isempty(aBot.depth.(aTime).ING.askLimitPrice))
                        myAskPrice = aBot.depth.(aTime).ING.askLimitPrice(1);
                        myVolume = min(aBot.depth.(aTime).ING.askVolume(1), abs(aBot.delta));
                        
                        aBot.SendNewOrder(myAskPrice, myVolume, 1, {'ING'}, {'IMMEDIATE'}, 0);
                        aBot.portfolio(21, 1) = aBot.portfolio(21, 1) + myVolume;
                    elseif(~isempty(aBot.depth.(aTime).ING.bidLimitPrice))
                        myBidPrice = aBot.depth.(aTime).ING.bidLimitPrice(1);
                        myVolume = min(aBot.depth.(aTime).ING.bidVolume(1), aBot.delta);
                        
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
            
            n = min(length(fieldnames(aBot.depth)), aBot.N);
            if(n >= aBot.N)
                
                priceArray = zeros(n-1,1);
                
                % Store the last n values of the stock
                for i=1:aBot.N-1
                    aTime = strcat('t', num2str(aBot.time - i));
                    if(isfield(aBot.depth.(aTime).ING, 'stockPrice'))
                        priceArray(i) = aBot.depth.(aTime).ING.stockPrice;
                    end
                end
                
                aTime = strcat('t', num2str(aBot.time));
                
                percentageArray = zeros(length(priceArray)-1,1);
                
                for i=2:length(priceArray)
                    percentageArray(i) = (priceArray(i) - priceArray(i-1))/priceArray(i)*100;
                end
                
                aBot.depth.(aTime).ING(1).IV = std(percentageArray);
                
            end
        end
        
        %%  Calculates the implied volatility
        function CalculateIV(aBot, ISIN)
            aTime = strcat('t', num2str(aBot.time));
            
            % The stockprice needs to be defined to calculate IV
            if isfield(aBot.depth.(aTime).ING, 'stockPrice')
                if ~isempty(aBot.depth.(aTime).(ISIN).askLimitPrice)
                    
                    [~, T, p, K] = ParseOptionISINs({ISIN});
                    
                    T = (T - now())/aBot.DAYS_IN_YEARS;
                    
                    S = aBot.depth.(aTime).ING.stockPrice;
                    V = aBot.depth.(aTime).(ISIN).askLimitPrice(1);
                    
                    optionAskIV = IV(S, K, T, V, p);
                else
                    optionAskIV = [];
                end
                
                if ~isempty(aBot.depth.(aTime).(ISIN).bidLimitPrice)
                    [~, T, p, K] = ParseOptionISINs({ISIN});
                    
                    T = (T - now())/aBot.DAYS_IN_YEARS;
                    
                    S = aBot.depth.(aTime).ING.stockPrice;
                    V = aBot.depth.(aTime).(ISIN).bidLimitPrice(1);
                    
                    optionBidIV = IV(S, K, T, V, p);
                else
                    optionBidIV = [];
                end
                
                aBot.depth.(aTime).(ISIN).IV = Average(optionAskIV,optionBidIV);
            end
        end
        
        %% Calculates the Greeks
        function CalculateGreeks(aBot,ISIN)
            aTime = strcat('t', num2str(aBot.time));
            
            % The stockprice needs to be defined to calculate IV
            if isfield(aBot.depth.(aTime).ING, 'stockPrice')
                
                [~, T, p, K] = ParseOptionISINs({ISIN});

                T = (T - now())/aBot.DAYS_IN_YEARS;

                S = aBot.depth.(aTime).ING.stockPrice;
                IV = aBot.depth.(aTime).(ISIN).IV;
                BSM = BS(S, K, T, IV, p);
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