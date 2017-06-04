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
                aBot.depth.(aTime).(ISIN).stockPrice = ...
                    StockPrice(aBot.depth.(aTime).(ISIN).askLimitPrice, aBot.depth.(aTime).(ISIN).bidLimitPrice);
            end
            
            aBot.depth.(aTime).('ING').optionPrice = zeros(length(aBot.optionISIN.ISIN),2);
            
            ISINNames= fieldnames(aBot.depth.(aTime));
            for i=1:length(ISINNames)
                ISINName=ISINNames(i);
                for k=1:length(aBot.optionISIN.ISIN)
                    optionISINName = aBot.optionISIN.ISIN(k);
                    if strcmp(aBot.depth.(aTime).(ISINName{1}).ISIN,optionISINName{1})
                        aBot.depth.(aTime).('ING').optionPrice(k,1) = aBot.depth.(aTime).(ISINName{1}).askLimitPrice;
                        aBot.depth.(aTime).('ING').optionPrice(k,2) = aBot.depth.(aTime).(ISINName{1}).bidLimitPrice;
                    end
                end
            end
            
        end
        
        %% Shows some plots
        function ShowPlots(aBot)
            
            %% Close all the old figures
            close all;
            
            %% 1, 2
            
            %            PlotStock(aBot);
            
            %% 3
            %            PlotOptionSpread(aBot)
            
            %% 4
            %            PlotOptionTime(aBot)
            
            %% 5
            PlotOptionIVs(aBot);
            
            %% 6
            %            PlotGreeks(aBot);
            
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
                
                
                if(~isempty(aBot.depth.(timeField).bidLimitPrice))
                    bidData(t) = aBot.depth.(timeField).bidLimitPrice(1);
                    
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
            
            subplot(2, 1, 1), plot(xData, bidData, 'b');
            hold on
            subplot(2, 1, 1), plot(xData, askData, 'r');
            subplot(2, 1, 2), plot(xData, stockPriceData, 'k');
        end
        
        function PlotOptionIVs(aBot)
            curly = @(x, varargin) x{varargin{:}};
            nTime = fieldnames(aBot.depth);
            lastTimeString = curly(nTime(end),1);
            lastTime = str2double(lastTimeString(2:end));
            
            optionNumber=length(aBot.optionISIN.ISIN);
            
            plotTime = 101;
            optionIV1 = zeros(lastTime,optionNumber);
            optionIV2 = zeros(lastTime,optionNumber);
            for t=1:lastTime
                timeField = curly(nTime(t),1);
                for k=1:optionNumber
                    if (isfield(aBot.depth.(timeField),aBot.optionISIN.ISIN(k)) && aBot.depth.(timeField).('ING').optionPrice(k,1) ~= 0)
                        optionIV1(t,k)=IV(aBot.depth.(timeField).('ING').stockPrice, ...
                            aBot.optionISIN.K(k),...
                            aBot.optionISIN.T(k),...
                            aBot.depth.(timeField).('ING').optionPrice(k,1),...
                            aBot.optionISIN.p(k));
                    else
                        optionIV1(t,k)=NaN;
                    end
                end
            end
            
            for t=1:lastTime
                timeField = curly(nTime(t),1);
                for k=1:optionNumber
                    if (isfield(aBot.depth.(timeField),aBot.optionISIN.ISIN(k)) && aBot.depth.(timeField).('ING').optionPrice(k,2) ~= 0)
                        optionIV2(t,k)=IV(aBot.depth.(timeField).('ING').stockPrice, ...
                            aBot.optionISIN.K(k),...
                            aBot.optionISIN.T(k),...
                            aBot.depth.(timeField).('ING').optionPrice(k,2),...
                            aBot.optionISIN.p(k));
                    else
                        optionIV2(t,k)=NaN;
                    end
                end
            end
            
            figure
            scatter(aBot.optionISIN.K,optionIV1(plotTime,:))
            hold on
            scatter(aBot.optionISIN.K,optionIV2(plotTime,:))
            hold off
            
            title('The implied volatilities of the options at the plotTime')
            xlabel('Strike prices of options')
            ylabel('Implied volatilities of options')
            
            figure
            t=1:lastTime;
            for i=1:optionNumber
                subplot(4,5,i)
                scatter(t,transpose(optionIV1(:,i)))
                hold on
                scatter(t,transpose(optionIV2(:,i)))
                hold off
            end
            suptitle('The implied volatilities of the options over time for each strike price')
        end
        
        
        
        function PlotGreeks(aBot)
            curly = @(x, varargin) x{varargin{:}};
            nTime = fieldnames(aBot.depth);
            lastTimeString = curly(nTime(end),1);
            lastTime = str2double(lastTimeString(2:end));
            
            optionIV2 = zeros(lastTime,1);
            
            for t= 1:lastTime
                timeField = curly(nTime(t),1);
                N=length(aBot.optionISIN.ISIN);
                optionIV2(t) = zeros(1,N);
                for k=1:N
                    optionISINName = aBot.optionISIN.ISIN(k);
                    optionIV2(t,k) = IV(aBot.depth.(timeField).('ING').stockPrice, ...
                        aBot.optionISIN.K(k),...
                        aBot.optionISIN.T(k),...
                        aBot.depth.(timeField).(optionISINName{1}).optionPrice(k),...
                        aBot.optionISIN.p(k));
                end
            end
            
            optionDeltas = zeros(lastTime,1);
            optionGammas = zeros(lastTime,1);
            optionVegas = zeros(lastTime,1);
            for t= 1:lastTime
                timeField = curly(nTime(t),1);
                optionDeltas(t) = zeros(1,N);
                optionGammas(t) = zeros(1,N);
                optionVegas(t) = zeros(1,N);
                for k=1:N
                    BSM = BS(aBot.depth.(timeField).('ING').stockPrice, ...
                        aBot.optionISIN.K(k),...
                        aBot.optionISIN.T(k),...
                        optionIV2(t,k),...
                        aBot.optionISIN.p(k));
                    optionDeltas(t,k)=BSM(2,1);
                    optionGammas(t,k)=BSM(3,1);
                    optionVegas(t,k)=BSM(4,1);
                end
            end
            
            for k=1:N
                t=1:lastTime;
                subplot(3,1,1)
                plot(optionDeltas(t,k),t)
                hold on
            end
            hold off
            
            for k=1:N
                t=1:lastTime;
                subplot(3,1,2)
                plot(optionGammas(t,k),t)
                hold on
            end
            hold off
            
            for k=1:N
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