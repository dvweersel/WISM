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
            
            %% Calculate the stock price if it's a stock depth update and else the option depth
            if(strcmp(ISIN,'ING'))                
                CalculateStockPrice(aBot);
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
        
        %% Shows some plots
        function ShowPlots(aBot)
            %% Close all the old figures
            close all;
            
            %% 1, 2
            PlotStock(aBot);
            
            %% 3
            PlotOptionSpread(aBot)
            
            %% 4
            PlotOptionTime(aBot)
            
            %% 5
           PlotOptionIVs(aBot);
            
            %% 6 
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
                
                stockPriceData(t) = Average(bidData(t),askData(t));
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
        function PlotOptionIVs(aBot)
            curly = @(x, varargin) x{varargin{:}};
            nTime = fieldnames(aBot.depth);
            lastTimeString = curly(nTime(end),1);
            lastTime = str2double(lastTimeString(2:end));
            
            optionNumber=length(aBot.optionISIN.ISIN);
            
            %the time of the plot
            plotTime = 101;
            
            %all the names of the option ISINs
            ISINNames = aBot.optionISIN.ISIN;
                        
            %calculate the implied volatilities of all asks and bids of the options and add the average of them
            %to the depth
            for t=1:lastTime
                timeField = curly(nTime(t),1);
                for k=1:optionNumber
                    ISINName=ISINNames(k);
                    if isfield(aBot.depth.(timeField),aBot.optionISIN.ISIN(k))
                        if ~isempty(aBot.depth.(timeField).(ISINName{1}).askLimitPrice)
                        optionIV1 = IV(aBot.depth.(timeField).('ING').stockPrice, ...
                                          aBot.optionISIN.K(k),...
                                          aBot.optionISIN.T(k),...
                                          aBot.depth.(timeField).(ISINName{1}).askLimitPrice,...
                                          aBot.optionISIN.p(k));
                        end
                    else
                        optionIV1 = NaN;
                    end
                    
                    if isfield(aBot.depth.(timeField),aBot.optionISIN.ISIN(k))
                        if ~isempty(aBot.depth.(timeField).(ISINName{1}).bidLimitPrice)
                        optionIV2 = IV(aBot.depth.(timeField).('ING').stockPrice, ...
                                          aBot.optionISIN.K(k),...
                                          aBot.optionISIN.T(k),...
                                          aBot.depth.(timeField).(ISINName{1}).bidLimitPrice,...
                                          aBot.optionISIN.p(k));
                        end
                    else
                        optionIV2 = NaN;
                    end
                    
                    aBot.depth.(timeField).(ISINName{1}).IV = Average(optionIV1,optionIV2);
                end
            end
            
            %plot the implied volatilities of all options at the plotTime
            plotTimeField = curly(nTime(plotTime),1);
            plotIV = zeros(1,optionNumber);
            for k=1:optionNumber
                ISINName = ISINNames(k);
                plotIV(1,k) = aBot.depth.(plotTimeField).(ISINName{1}).IV;
            end
            figure
            scatter(aBot.optionISIN.K,plotIV)
            
            
            title('The implied volatilities of the options at the plotTime')
            xlabel('Strike prices of options')
            ylabel('Implied volatilities of options')
            
            %plot the implied volatilities of the options over time
            %for each strike price
            figure
            for i=1:optionNumber
                ISINName=ISINNames(i);
                subplot(4,5,i)
                plotIV = zeros(1,lastTime);
                for t=1:lastTime
                    timeField = curly(nTime(t),1);
                    plotIV(1,t) = aBot.depth.(timeField).(ISINName{1}).IV;
                end
                t=1:lastTime;
                scatter(t,plotIV)
                
                title(aBot.optionISIN.ISIN(i))
            end
            suptitle('The implied volatilities of the options over time for each strike price')
        end
        
        %% 6
        function PlotGreeks(aBot)
            curly = @(x, varargin) x{varargin{:}};
            nTime = fieldnames(aBot.depth);
            lastTimeString = curly(nTime(end),1);
            lastTime = str2double(lastTimeString(2:end));
            
            optionNumber=length(aBot.optionISIN.ISIN);
 
            %all the names of the option ISINs
            ISINNames = aBot.optionISIN.ISIN;
            
            %calculate the deltas, gammas and vegas of the options by using BS.m
            for t= 1:lastTime
                timeField = curly(nTime(t),1);
                for k=1:optionNumber
                    ISINName = ISINNames(k);
                    if (isfield(aBot.depth.(timeField),aBot.optionISIN.ISIN(k)) && ~isnan(aBot.depth.(timeField).(ISINName{1}).IV))
                        BSM = BS(aBot.depth.(timeField).('ING').stockPrice, ...
                                 aBot.optionISIN.K(k),...
                                 aBot.optionISIN.T(k),...
                                 aBot.depth.(timeField).(ISINName{1}).IV,...
                                 aBot.optionISIN.p(k));   
                        aBot.depth.(timeField).(ISINName{1}).Delta = BSM(2,1);
                        aBot.depth.(timeField).(ISINName{1}).Gamma = BSM(3,1);
                        aBot.depth.(timeField).(ISINName{1}).Vega  = BSM(4,1);
                    else
                        aBot.depth.(timeField).(ISINName{1}).Delta = NaN;
                        aBot.depth.(timeField).(ISINName{1}).Gamma = NaN;
                        aBot.depth.(timeField).(ISINName{1}).Vega  = NaN;
                    end
                end
            end
            
            %plot the deltas, gammas and vegas of the options over
            %time for a certain strike price
            figure
            optionNumber = 4;
            ISINName = ISINNames(optionNumber);
            subplot(3,1,1)
            plotIV1 = zeros(1,lastTime);
            for t=1:lastTime
                timeField = curly(nTime(t),1);
                plotIV1(1,t) = aBot.depth.(timeField).(ISINName{1}).Delta;
            end
            t=1:lastTime;
            scatter(t,plotIV1)
            
            title('The deltas of the options with this optionNumber')
            xlabel('time')
            ylabel('deltas')
            
            subplot(3,1,2)
            plotIV2 = zeros(1,lastTime);
            for t=1:lastTime
                timeField = curly(nTime(t),1);
                plotIV2(1,t) = aBot.depth.(timeField).(ISINName{1}).Gamma;
            end
            t=1:lastTime;
            scatter(t,plotIV2)
            
            title('The gammas of the options with this optionNumber')
            xlabel('time')
            ylabel('gammas')
            
            subplot(3,1,3)
            plotIV3 = zeros(1,lastTime);
            for t=1:lastTime
                timeField = curly(nTime(t),1);
                plotIV3(1,t) = aBot.depth.(timeField).(ISINName{1}).Vega;
            end
            t=1:lastTime;
            scatter(t,plotIV3)
            
            title('The vegas of the options with this optionNumber')
            xlabel('time')
            ylabel('vegas')
            
            suptitle('The greeks of the options over time')
        end
    end
end

function varargout = curly(x, varargin)
    [varargout{1:nargout}] = x{varargin{:}};
end