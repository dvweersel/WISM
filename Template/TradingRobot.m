classdef TradingRobot < AutoTrader
    properties
        depth = struct
        optionISIN = struct
        time = 0
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
        end

        function Unwind(aBot)
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
        
        function varargout = curly(x, varargin)
            [varargout{1:nargout}] = x{varargin{:}};
        end    
    end
end
