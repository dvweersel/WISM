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
            aBot.depth.(aTime).stockPrice = StockPrice(aBot.depth.(aTime).askLimitPrice, aBot.depth.(aTime).bidLimitPrice)
                        
            %% Store the depth of the options
            nOption = GetAllOptionISINs();

            [S, T, p, K] = ParseOptionISINs(nOption);
            
            N=length(p);
            for v = 1:N
                if p(v) == 'Call'
                    p(v) = 0;
                else
                    p(v) = 1;
                end
            end
            V=0;
            
            
            
            aBot.optionDepth.(aTime) = struct('T', T, 'p', p, 'K', K,'V',V);
        end
        
        function ShowPlots(aBot)
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
            subplot(2, 2, 1), plot(xData, bidData, 'b');
            hold on
            subplot(2, 2, 2), plot(xData, askData, 'r');
            subplot(2, 2, 3), plot(xData, stockPriceData, 'k');
        end
        
        function PlotOptionSpread(aBot)
            TIME =  500;
            
            
        end
        
        function PlotOptionTime(aBot)
            
        end
        
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