classdef TradingRobotMean < AutoTrader
    properties
        depth = struct
        optionISIN = struct
        time = 0
        
        % Amount - Delta (last one is stock)
        portfolio = zeros(21, 2)
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
                if(aBot.time ~= 0)
                    TryArbitrage(aBot);
                    % Hedge
                    %aBot.Hedge();
                end
                aBot.time = aBot.time + 1;
            end
            aTime = strcat('t', num2str(aBot.time));
            
            % Store the depth of the stocks
            aBot.depth.(aTime).(ISIN) = struct(aDepth);
            
            % Calculate the stock price if it's a stock depth update
            if(strcmp(ISIN,'ING'))
                CalculateStockPrice(aBot);
                CalculateStockVolatility(aBot);
            else % And the Greeks/IV if it's an option
                CalculateIV(aBot,ISIN);
                CalculateGreeks(aBot,ISIN);
            end
        end
        
        %% Try to arbitrage
        function TryArbitrage(aBot)
            
            aTime = strcat('t', num2str(aBot.time));
            
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
                
                aBot.depth.(aTime).ING.IV = meanIV;
                
                % Buy options under mean
                for f = options'
                    if not(strcmp(f{1}, 'ING')) && ~isnan(aBot.depth.(aTime).(f{1}).IV)
                        if(aBot.depth.(aTime).(f{1}).IV < meanIV)
                            TradeBestListing(aBot, f{1}, 1);
                        end
                    end
                end
            end
        end
        
        %% Function used to get the positions at 0 again
        function Unwind(aBot)
            
        end
        
        %% function to send the orders
        function TradeBestListing(aBot, ISIN, side)
            aTime = strcat('t', num2str(aBot.time));
            
            if(side == 1)
                myAskPrice = aBot.depth.(aTime).(ISIN).askLimitPrice(1);
                myVolume = aBot.depth.(aTime).(ISIN).askVolume(1);            
                
                aBot.SendNewOrder(myAskPrice, myVolume, 1, {ISIN}, {'IMMEDIATE'}, 0);
            else
                myBidPrice = aBot.depth.(aTime).(ISIN).bidLimitPrice(1);
                myVolume = aBot.depth.(aTime).(ISIN).bidVolume(1);
                
                aBot.SendNewOrder(myBidPrice, myVolume, -1, {ISIN}, {'IMMEDIATE'}, 0);
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
            
            % Stock has delta 1
            aBot.portfolio(21,2) = aBot.portfolio(21, 1);
    
            for i=1:length(aBot.optionISIN.ISIN)
                
                BSM = BS(aBot.depth.(aTime).ING.stockPrice, ...
                    aBot.optionISIN.K(i),...
                    aBot.optionISIN.T(i),...
                    aBot.depth.(aTime).ING.IV,...
                    aBot.optionISIN.p(n));
                portfolio(i, 2) = portfolio(i, 1) * BSM(2, 1);
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
            MIN = 5;
            MAX = 20;
            
            n = min(length(fieldnames(aBot.depth)) - 1, MAX);
            if(n > MIN)
                
                priceArray = zeros(n,1);

                % Average the last n values of the stock
                for i=1:n
                    aTime = strcat('t', num2str(aBot.time - i));
                    if(isfield(aBot.depth.(aTime).ING, 'stockPrice'))
                        priceArray(i) = aBot.depth.(aTime).ING.stockPrice;
                    end
                end
                
                aTime = strcat('t', num2str(aBot.time));
                aBot.depth.(aTime).ING.IV = std(priceArray');
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