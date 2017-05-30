classdef AnalysisRobot < AutoTrader
    properties
        depth = struct
        optionDepth = struct
        time = 0
    end

    methods
        function HandleDepthUpdate(aBot, ~, aDepth)
            %% Update time
            aBot.time = aBot.time + 1;
            aTime = strcat('t', num2str(aBot.time));
            
            %% Store the depth of the stocks
            aBot.depth.(aTime) = struct(aDepth);
            aBot.depth.(aTime).stockPrice = StockPrice(aBot.depth.(aTime).askLimitPrice, aBot.depth.(aTime).bidLimitPrice);
            
            %% Store the depth of the options
            nOption = GetAllOptionISINs();

            [S, T, p, K] = ParseOptionISINs(nOption);
            aBot.optionDepth.(aTime) = struct('T', T, 'p', p, 'K', K);
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
        %Dit is een test om te kijken of pushen werkt.
        function PlotOptionTime(aBot)
          
        end
    end
end


