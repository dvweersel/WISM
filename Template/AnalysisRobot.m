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
            
            %% Add the stock price if it's a stock depth update
            if(strcmp(ISIN,'ING'))
                CalculateStockPrice(aBot);
            end
            
        end
        
        %% Shows some plots
        function ShowPlots(aBot)
            
            %% Close all the old figures
            close all;
            
            %% 1, 2
            PlotStock(aBot);
            
            %% 3
            PlotOptionSpread(aBot);
            
            %% 4
            PlotOptionTime(aBot);
            
            %% 5
            PlotOptionIV1(aBot);
            
            %% 6
            PlotOptionIV2(aBot);
            
            %% 7
            PlotGreeks(aBot);
            
        end
        
        %% 1,2 Plot of the bid, ask and stock price
        function PlotStock(aBot)
            % List of all the times
            nTime = fieldnames(aBot.depth);
            
            lastTimeString = curly(nTime(end),1);
            
            lastTime = str2double(lastTimeString(2:end));
            
            % Pre allocate size
            xData = 1:lastTime;
            bidData = zeros(lastTime,1);
            askData = zeros(lastTime,1);
            stockPriceData = zeros(lastTime,1);
            
            % Go through the depths and store the bids and asks
            for t = 1:lastTime
                
                timeField = curly(nTime(t),1);
                
                
                if(~isempty(aBot.depth.(timeField).ING.bidLimitPrice))
                    bidData(t) = aBot.depth.(timeField).ING.bidLimitPrice(1);
                else
                    bidData(t) = NaN;
                end
                
                if(~isempty(aBot.depth.(timeField).ING.askLimitPrice))
                    askData(t) = aBot.depth.(timeField).ING.askLimitPrice(1);
                else
                    askData(t) = NaN;
                end
                
                stockPriceData(t) = StockPrice(bidData(t),askData(t));
            end
            
            % Plot everything
            figure;
            subplot(2, 1, 1), plot(xData, bidData, 'b');
            hold on
            subplot(2, 1, 1), plot(xData, askData, 'r');
            subplot(2, 1, 2), plot(xData, stockPriceData, 'k');
        end
        
        %% 3 Plots the option prices for a certain time
        function PlotOptionTime(aBot)
            %% Determine the depth with the largest number of options
            times = fieldnames(aBot.depth);
            
            % We store the time with the largest amount of options
            k = 0;
            kField = 0;
            for t = times'
                
                tField = t{1};
                numberOfOptions = length(fieldnames(aBot.depth.(tField)));
                
                if(numberOfOptions > k)
                    
                    k = numberOfOptions;
                    kField = tField;
                end
            end
            
            % All the ISIN's and strike prices
            nOption = aBot.optionISIN.ISIN;
            K = aBot.optionISIN.K;
            
            price = zeros(length(nOption),2);
            
            % Loop through the options
            for i = 1:length(nOption)
                
                iOption = curly(nOption(i), 1);
                
                % If the ask/bid exists, store it. Otherwise NaN
                if(isfield(aBot.depth.(kField), iOption))
                    if(~isempty(aBot.depth.(kField).(iOption).askLimitPrice))
                        price(i,1) = aBot.depth.(kField).(iOption).askLimitPrice(1);
                    else
                        price(i,1) = NaN;
                    end
                    
                    if(~isempty(aBot.depth.(kField).(iOption).bidLimitPrice))
                        price(i,2) = aBot.depth.(kField).(iOption).bidLimitPrice(1);
                    else
                        price(i,2) = NaN;
                    end
                    
                else
                    price(i, 1) = NaN;
                    price(i, 2) = NaN;
                end
            end
            
            % Plot everything
            figure
            scatter(K, price(:,1), 'r');
            hold on
            scatter(K, price(:,2), 'b');
            title(tField);
            xlabel('Strike price')
            ylabel('Price')
            hold off
        end
        
        %% 4
        function PlotOptionSpread(aBot)
            times = fieldnames(aBot.depth);
            
            % Allocate size
            xData = 1:length(times);
            bidOptionData = zeros(length(times), length(aBot.optionISIN.ISIN));
            askOptionData = zeros(length(times), length(aBot.optionISIN.ISIN));
            
            % Loop through the depth
            for t = times'
                tField = t{1};
                tDouble = str2double(tField(2:end));
                
                nOption = aBot.optionISIN.ISIN;
                % For each time, loop through the ISINs
                for i = 1:length(nOption)
                    
                    iOption = curly(nOption(i),1);
                    
                    % If the option exists and has a bid/ask in the depth
                    % store it
                    if(isfield(aBot.depth.(tField), iOption))
                        
                        if(~isempty(aBot.depth.(tField).(iOption).bidLimitPrice))
                            bidOptionData(tDouble, i) = aBot.depth.(tField).(iOption).bidLimitPrice(1);
                        else
                            bidOptionData(tDouble, i) = NaN;
                        end
                        
                        if(~isempty(aBot.depth.(tField).(iOption).askLimitPrice))
                            askOptionData(tDouble, i) = aBot.depth.(tField).(iOption).askLimitPrice(1);
                        else
                            askOptionData(tDouble, i) = NaN;
                        end
                    else
                        askOptionData(tDouble, i) = NaN;
                        bidOptionData(tDouble, i) = NaN;
                    end
                end
            end
            
            % Plot everything
            figure
            for i = 1:length(nOption)
                subplot(4,5,i);
                scatter(xData, bidOptionData(:,i), 'x');
                hold on
                scatter(xData, askOptionData(:,i), 'r');
                title(curly(nOption(i),1));
                hold off
            end
        end
        
        %% 5
        function PlotOptionIV1(aBot)
            plotTime = 0;
            N=length(aBot.optionDepth.(aTime).V);
            optionIV1 =  zeros(N,1);
            for v = 1:N
                optionIV1(v)=IV(aBot.depth.(plotTime).stockPrice, ...
                    aBot.optionDepth.(plotTime).K(v),...
                    aBot.optionDepth.(plotTime).T(v),...
                    aBot.optionDepth.(plotTime).V(v),...
                    aBot.optionDepth.(plotTime).p(v));
            end
            plot(aBot,optionDepth.(plotTime).K,optionIV1)
        end
        
        %% 6
        function PlotOptionIV2(aBot)
            nTime = fieldnames(aBot.depth);
            lastTimeString = curly(nTime(end),1);
            lastTime = str2double(lastTimeString(2:end));
            
            optionIV2 = zeros(lastTime,1);
            
            for t= 1:lastTime
                N=length(aBot.optionDepth.(t).K);
                optionIV2(t) = zeros(1,N);
                for k=1:N
                    optionIV2(t,k) = IV(aBot.depth.(t).stockPrice, ...
                        aBot.optionDepth.(t).K(k),...
                        aBot.optionDepth.(t).T(k),...
                        aBot.optionDepth.(t).V(k),...
                        aBot.optionDepth.(t).p(k));
                end
            end
            
            for k=1:length(aBot.optionDepth.(0).K)
                t=1:lastTime;
                plot(optionIV2(t,k),t)
                hold on
            end
            hold off
        end
        
        %% 7
        function PlotGreeks(aBot)
            nTime = fieldnames(aBot.depth);
            lastTimeString = curly(nTime(end),1);
            lastTime = str2double(lastTimeString(2:end));
            
            optionIV2 = zeros(lastTime,1);
            
            for t= 1:lastTime
                N=length(aBot.optionDepth.(t).K);
                optionIV2(t) = zeros(1,N);
                for k=1:N
                    optionIV2(t,k) = IV(aBot.depth.(t).stockPrice, ...
                        aBot.optionDepth.(t).K(k),...
                        aBot.optionDepth.(t).T(k),...
                        aBot.optionDepth.(t).(k),...
                        aBot.optionDepth.(t).p(k));
                end
            end
            
            optionDeltas = zeros(lastTime,1);
            optionGammas = zeros(lastTime,1);
            optionVegas = zeros(lastTime,1);
            for t= 1:lastTime
                N=length(aBot.optionDepth.(t).K);
                optionDeltas(t) = zeros(1,N);
                optionGammas(t) = zeros(1,N);
                optionVegas(t) = zeros(1,N);
                for k=1:N
                    BSM = BS(aBot.depth.(t).stockPrice, ...
                        aBot.optionDepth.(t).K(k),...
                        aBot.optionDepth.(t).T(k),...
                        optionIV2(t,k),...
                        aBot.optionDepth.(t).p(k));
                    optionDeltas(t,k)=BSM(2,1);
                    optionGammas(t,k)=BSM(3,1);
                    optionVegas(t,k)=BSM(4,1);
                end
            end
            
            for k=1:length(aBot.optionDepth.(0).K)
                t=1:lastTime;
                subplot(3,1,1)
                plot(optionDeltas(t,k),t)
                hold on
            end
            hold off
            
            for k=1:length(aBot.optionDepth.(0).K)
                t=1:lastTime;
                subplot(3,1,2)
                plot(optionGammas(t,k),t)
                hold on
            end
            hold off
            
            for k=1:length(aBot.optionDepth.(0).K)
                t=1:lastTime;
                subplot(3,1,3)
                plot(optionVegas(t,k),t)
                hold on
            end
            hold off
        end
    end
end

%% Help function
function varargout = curly(x, varargin)
    [varargout{1:nargout}] = x{varargin{:}};
end