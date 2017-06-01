classdef AnalysisRobot < AutoTrader
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
                
                aBot.depth.(aTime).(ISIN).stockPrice = ...
                    StockPrice(aBot.depth.(aTime).askLimitPrice, aBot.depth.(aTime).bidLimitPrice);
            end
            
        end
        
        function ShowPlots(aBot)
            %% 1, 2
            PlotStock(aBot);

            %% 3
            PlotOptionSpread(aBot)
            
            %% 4
            PlotOptionTime(aBot)
        end
        
        function PlotStock(aBot)
            curly = @(x, varargin) x{varargin{:}};

            %% Plot of the bid, ask and stock price
            figure;

            % List of all the times)
            nTime = fieldnames(aBot.depth);

            lastTimeString = curly(nTime(end),1);

            lastTime = str2double(lastTimeString(2:end));

            % Pre allocate size
            xData = 1:lastTime;
            bidData = zeros(lastTime,1);
            askData = zeros(lastTime,1);
            stockPriceData = zeros(lastTime,1);

            for t = 1:lastTime

                timeField = curly(nTime(t),1);
                

                if(~isempty(aBot.depth.(timeField).bidLimitPrice))
                    bidData(t) = aBot.depth.(timeField).bidLimitPrice(1);     
                else
                    bidData(t) = NaN;
                end

                if(~isempty(aBot.depth.(timeField).askLimitPrice))
                    askData(t) = aBot.depth.(timeField).askLimitPrice(1);
                else
                    askData(t) = NaN;
                end

                stockPriceData(t) = StockPrice(bidData(t),askData(t));
            end
            subplot(2, 1, 1), plot(xData, bidData, 'b');
            hold on
            subplot(2, 1, 1), plot(xData, askData, 'r');
            subplot(2, 1, 2), plot(xData, stockPriceData, 'k');
        end
        
        function PlotOptionSpread(aBot)
            TIME =  500;
            
            
        end
        
        function PlotOptionTime(aBot)
          
        end
    end
end


