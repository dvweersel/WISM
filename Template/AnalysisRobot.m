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
                CalculateStockPrice(aBot);
            end
            
            %% calculate the IV and Greeks by an option depth update and add them to the depth
            optionNumber=length(aBot.optionISIN.ISIN);
            for k=1:optionNumber
                if isfield(aBot.depth.(aTime),aBot.optionISIN.ISIN(k))
                    CalculateIV(aBot,k);
                    CalculateGreeks(aBot,k);
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
        
        %%calculates the IV
        function CalculateIV(aBot,k)
            aTime = strcat('t', num2str(aBot.time));
            
            %all the names of the option ISINs
            ISINNames = aBot.optionISIN.ISIN;
                        
            %calculate the implied volatilities of the asks and bids of the options and add the average of them
            %to the depth
            ISINName=ISINNames(k);
            if isfield(aBot.depth.(aTime),aBot.optionISIN.ISIN(k))
                if ~isempty(aBot.depth.(aTime).(ISINName{1}).askLimitPrice)
                    optionIV1 = IV(aBot.depth.(aTime).('ING').stockPrice, ...
                                   aBot.optionISIN.K(k),...
                                   aBot.optionISIN.T(k),...
                                   aBot.depth.(aTime).(ISINName{1}).askLimitPrice(1),...
                                   aBot.optionISIN.p(k));
                    if isnan(optionIV1)
                        optionIV1 = [];
                    end
                else
                    optionIV1 = [];
                end
                              
                if ~isempty(aBot.depth.(aTime).(ISINName{1}).bidLimitPrice)
                    optionIV2 = IV(aBot.depth.(aTime).('ING').stockPrice, ...
                                   aBot.optionISIN.K(k),...
                                   aBot.optionISIN.T(k),...
                                   aBot.depth.(aTime).(ISINName{1}).bidLimitPrice(1),...
                                   aBot.optionISIN.p(k));
                    if isnan(optionIV2)
                        optionIV2 = [];
                    end                                       
                else
                    optionIV2 = [];
                end
                
                if ~isnan(Average(optionIV1,optionIV2))
                    aBot.depth.(aTime).(ISINName{1}).IV = Average(optionIV1,optionIV2);
                end
            end
        end
        
        %%Calculates the Greeks
        function CalculateGreeks(aBot,k)
            aTime = strcat('t', num2str(aBot.time));
            
            %all the names of the option ISINs
            ISINNames = aBot.optionISIN.ISIN;
            
            %calculate the deltas, gammas and vegas of the options by using BS.m
            ISINName = ISINNames(k);
            if isfield(aBot.depth.(aTime),aBot.optionISIN.ISIN(k))
                if isfield(aBot.depth.(aTime).(ISINName{1}),'IV')
                    BSM = BS(aBot.depth.(aTime).('ING').stockPrice, ...
                             aBot.optionISIN.K(k),...
                             aBot.optionISIN.T(k),...
                             aBot.depth.(aTime).(ISINName{1}).IV,...
                             aBot.optionISIN.p(k));   
                    aBot.depth.(aTime).(ISINName{1}).Delta = BSM(2,1);
                    aBot.depth.(aTime).(ISINName{1}).Gamma = BSM(3,1);
                    aBot.depth.(aTime).(ISINName{1}).Vega  = BSM(4,1);
                end
            end
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
    
            %plot the implied volatilities of all options at the plotTime
            plotTimeField = curly(nTime(plotTime),1);
            plotIV = zeros(1,optionNumber);
            for k=1:optionNumber
                ISINName = ISINNames(k);
                if isfield(aBot.depth.(plotTimeField),aBot.optionISIN.ISIN(k))
                    if isfield(aBot.depth.(plotTimeField).(ISINName{1}),'IV')
                        plotIV(1,k) = aBot.depth.(plotTimeField).(ISINName{1}).IV;
                    else
                        plotIV(1,k) = NaN;
                    end
                else
                    plotIV(1,k) = NaN;
                end
            end
            figure
            scatter(aBot.optionISIN.K,plotIV)
            
            
            title('The implied volatilities of the options at the plotTime')
            xlabel('Strike prices of options')
            ylabel('Implied volatilities of options')
            
            %plot the implied volatilities of the options over time
            %for each strike price
            figure
            for k=1:optionNumber
                ISINName=ISINNames(k);
                subplot(4,5,k)
                plotIV = zeros(1,lastTime);
                for t=1:lastTime
                    timeField = curly(nTime(t),1);
                    if isfield(aBot.depth.(timeField),aBot.optionISIN.ISIN(k))
                        if isfield(aBot.depth.(timeField).(ISINName{1}),'IV')
                            plotIV(1,t) = aBot.depth.(timeField).(ISINName{1}).IV;
                        else
                            plotIV(1,t) = NaN;
                        end
                    else
                        plotIV(1,t) = NaN;
                    end
                end
                t=1:lastTime;
                scatter(t,plotIV)
                
                title(aBot.optionISIN.ISIN(k))
            end
            suptitle('The implied volatilities of the options over time for each strike price')
        end
        
        %% 6
        function PlotGreeks(aBot)
            curly = @(x, varargin) x{varargin{:}};
            nTime = fieldnames(aBot.depth);
            lastTimeString = curly(nTime(end),1);
            lastTime = str2double(lastTimeString(2:end));
            
            %all the names of the option ISINs
            ISINNames = aBot.optionISIN.ISIN;
            
            %plot the deltas, gammas and vegas of the options over
            %time for a certain strike price
            figure
            optionNumber = 4;
            ISINName = ISINNames(optionNumber);
            subplot(3,1,1)
            plotDeltas = zeros(1,lastTime);
            for t=1:lastTime
                timeField = curly(nTime(t),1);
                if isfield(aBot.depth.(timeField),aBot.optionISIN.ISIN(optionNumber))
                    if isfield(aBot.depth.(timeField).(ISINName{1}),'Delta')
                        plotDeltas(1,t) = aBot.depth.(timeField).(ISINName{1}).Delta;
                    else
                        plotDeltas(1,t) = NaN;
                    end
                else
                    plotDeltas(1,t) = NaN;
                end
            end
            t=1:lastTime;
            scatter(t,plotDeltas)
            
            title('The deltas of the options with this optionNumber')
            xlabel('time')
            ylabel('deltas')
            
            subplot(3,1,2)
            plotGammas = zeros(1,lastTime);
            for t=1:lastTime
                timeField = curly(nTime(t),1);
                if isfield(aBot.depth.(timeField),aBot.optionISIN.ISIN(optionNumber))
                    if isfield(aBot.depth.(timeField).(ISINName{1}),'Gamma')
                        plotGammas(1,t) = aBot.depth.(timeField).(ISINName{1}).Gamma;
                    else
                        plotGammas(1,t) = NaN;
                    end
                else
                    plotGammas(1,t) = NaN;
                end
            end
            t=1:lastTime;
            scatter(t,plotGammas)
            
            title('The gammas of the options with this optionNumber')
            xlabel('time')
            ylabel('gammas')
            
            subplot(3,1,3)
            plotVegas = zeros(1,lastTime);
            for t=1:lastTime
                timeField = curly(nTime(t),1);
                if isfield(aBot.depth.(timeField),aBot.optionISIN.ISIN(optionNumber))
                    if isfield(aBot.depth.(timeField).(ISINName{1}),'Vega')
                        plotVegas(1,t) = aBot.depth.(timeField).(ISINName{1}).Vega;
                    else
                        plotVegas(1,t) = NaN;
                    end
                else
                    plotVegas(1,t) = NaN;
                end
            end
            t=1:lastTime;
            scatter(t,plotVegas)
            
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