classdef TradingRobot < AutoTrader
    properties
        depth = struct
        optionISIN = struct
        time = 0
        
        % Amount - Delta - Gamma
        portfolio = zeros(21, 3)
        delta = []
        gamma = []
<<<<<<< HEAD
        TradeDeltas = []
        TradeGammas = []
=======
>>>>>>> 865c4b95723c427fefb2e33b98b34fa095f70e49
        
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
                if(mod(aBot.time,5) == 0)
                    Hedge(aBot);
<<<<<<< HEAD
                end
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
            DeltaPosition = sum(aBot.TradeDeltas);
            GammaPosition = sum(aBot.TradeGammas);
            fileID= fopen('report.txt','wt');
            fprintf(fileID,'%19s %8.0f %10s %10.2f\r\n','Delta',DeltaPosition,'Gamma',GammaPosition);
            fclose(fileID);
            type report.txt
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
                    
                    if strcmp(ISIN,'ING')
                        aBot.TradeDeltas(end+1) = 1 * myVolume;
                        aBot.TradeGammas(end+1) = 0;
                    else
                        if isfield(aBot.depth.(aTime).(ISIN),'Delta') && isfield(aBot.depth.(aTime).(ISIN),'Gamma')
                            if ~isnan(aBot.depth.(aTime).(ISIN).Delta) && ~isnan(aBot.depth.(aTime).(ISIN).Gamma)
                                aBot.TradeDeltas(end+1) = aBot.depth.(aTime).(ISIN).Delta * myVolume;
                                aBot.TradeGammas(end+1) = aBot.depth.(aTime).(ISIN).Gamma * myVolume;
                            end
                        end
                    end
                    
                elseif(~isempty(aBot.depth.(aTime).(ISIN).bidLimitPrice))
                    myBidPrice = aBot.depth.(aTime).(ISIN).bidLimitPrice(1);
                    myVolume = aBot.depth.(aTime).(ISIN).bidVolume(1);
                    
                    aBot.SendNewOrder(myBidPrice, myVolume, -1, {ISIN}, {'IMMEDIATE'}, 0);
                    
                    if strcmp(ISIN,'ING')
                        aBot.TradeDeltas(end+1) = -1 * myVolume;
                        aBot.TradeGammas(end+1) = 0;
                    else
                        if isfield(aBot.depth.(aTime).(ISIN),'Delta') && isfield(aBot.depth.(aTime).(ISIN),'Gamma')
                            if ~isnan(aBot.depth.(aTime).(ISIN).Delta) && ~isnan(aBot.depth.(aTime).(ISIN).Gamma)
                                aBot.TradeDeltas(end+1) = -1 * aBot.depth.(aTime).(ISIN).Delta * myVolume;
                                aBot.TradeGammas(end+1) = -1 * aBot.depth.(aTime).(ISIN).Gamma * myVolume;
                            end
                        end
                    end
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
=======
>>>>>>> 865c4b95723c427fefb2e33b98b34fa095f70e49
                end
            end
        end
        
        %% Try to arbitrage
        function TryArbitrage(aBot)
            ALPHA = 0.05;
            
            % We look at the previous depth.
            aTime = strcat('t', num2str(aBot.time - 1));
            
<<<<<<< HEAD
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
=======
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
>>>>>>> 865c4b95723c427fefb2e33b98b34fa095f70e49
                        
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
        
        function A = Average(aAskPrices, aBidPrices)
            %   Returns the stock price
            
            if(~isempty(aAskPrices) && ~isempty(aBidPrices))
                A = (aAskPrices(1) + aBidPrices(1))/2;
            elseif(isempty(aAskPrices) && ~isempty(aBidPrices))
                A = aBidPrices(1);
            elseif(~isempty(aAskPrices) && isempty(aBidPrices))
                A = aAskPrices(1);
            else
                A = NaN;
            end
        end
        
        function W = BS(S, K, T, sigma, p)
            n=length(S);
            
            d1=zeros(1,n);
            d2=zeros(1,n);
            prices=zeros(1,n);
            deltas=zeros(1,n);
            gammas=zeros(1,n);
            vegas=zeros(1,n);
            I1=zeros(1,n);
            I2=zeros(1,n);
<<<<<<< HEAD
            I3=zeros(1,n);
            I4=zeros(1,n);
=======
>>>>>>> 865c4b95723c427fefb2e33b98b34fa095f70e49
            for i=1:n
                %calculating the bounds of the integrals as a function of s,k,t and o.
                d1(1,i) = 1./(sigma(1,i).*sqrt(T(1,i))).*(log(S(1,i)./K(1,i)) + 0.5.*sigma(1,i).^2.*T(1,i));
                d2(1,i) = d1(1,i) - sigma(1,i).*sqrt(T(1,i));
                
                %calculating the cdfs with the bounds d1 and d2
                I1(1,i) = NDcdf(d1(1,i));
                I2(1,i) = NDcdf(d2(1,i));
                I3(1,i) = NDcdf(-d2(1,i));
                I4(1,i) = NDcdf(-d1(1,i));
                
                %calculating the prices, deltas, gammas and vegas of the options
                if p(1,i)==0
                    prices(1,i) = S(1,i).*I1(1,i) - K(1,i).*I2(1,i);
                    deltas(1,i) = I1(1,i);
                    
                elseif p(1,i)==1
                    prices(1,i) = K(1,i).*I3(1,i) - S(1,i).*I4(1,i);
                    deltas(1,i) = -I4(1,i);
                end
                gammas(1,i) = NDpdf(d1(1,i))./(S(1,i).*sigma(1,i).*sqrt(T(1,i)));
                vegas(1,i)  = NDpdf(d1(1,i)).*S(1,i).*sqrt(T(1,i));
            end
            
            W=zeros(4,n);
            W(1,:)=prices(1,:);
            W(2,:)=deltas(1,:);
            W(3,:)=gammas(1,:);
            W(4,:)=vegas(1,:);
        end
        
        %this functions are used to get the cdf en pdf of the
        %standard normal distribution.
        function I = NDcdf(x)
            I = 0.5*(1.+erf(x./sqrt(2)));
        end
        
        function P = NDpdf(x)
            P = exp(-0.5*x.^2)./sqrt(2*pi);
        end
        
        function sigma = IV(S, K, T, V, p)
            %   Input Parameters
            %   S   Spot Price
            %   K   Strike Price
            %   T   Time until Expiry (years)
            %   V   Option Price
            %   p   Call = 0, Put = 1
            %
            %   References:
            %   1)  Li, 2006, "You Don't Have to Bother Newton for Implied Volatility"
            %       http://papers.ssrn.com/sol3/papers.cfm?abstract_id=952727
            %   2)  http://en.wikipedia.org/wiki/Householder's_method
            %   3)  http://en.wikipedia.org/wiki/Greeks_(finance)
            %
            
            %   Determine the size of the matrix
            lengths = [length(S) length(K) length(T) length(V) length(p)];
            k = max(lengths);
            
            %   If one of the arguments is constant extend it
            if(k > 1)
                if isscalar(S); S = S*ones(1,k); end
                if isscalar(K); K = K*ones(1,k); end
                if isscalar(T); T = T*ones(1,k); end
                if isscalar(V); V = V*ones(1,k); end
                if isscalar(p); p = p*ones(1,k); end
            end
            
            %   Eq (21)
            pi = [-0.969271876255; 0.097428338274; 1.750081126685];
            
            %   Eq (22)
            n = ones(1,14);
            n(:) = [...
                -0.068098378725;
                0.440639436211;
                -0.263473754689;
                -5.792537721792;
                -5.267481008429;
                4.714393825758;
                3.529944137559;
                -23.636495876611;
                -9.020361771283;
                14.749084301452;
                -32.570660102526;
                76.398155779133;
                41.855161781749;
                -12.150611865704];
            n = n(ones(1,k),:); % Repmat to size [k,14]
            
            m = ones(1,14);
            m(:) = [...
                6.268456292246;
                -6.284840445036;
                30.068281276567;
                -11.780036995036;
                -2.310966989723;
                -11.473184324152;
                -230.101682610568;
                86.127219899668;
                3.730181294225;
                -13.954993561151;
                261.950288864225;
                20.090690444187;
                -50.117067019539;
                13.723711519422];
            m = m(ones(1,k),:); % Repmat to size [k,14]
            
            i = ones(1,14);
            i(:) = [0,1,0,1,2,0,1,2,3,0,1,2,3,4];
            i = i(ones(1,k),:); % Repmat to size [k,14]
            j = ones(1,14);
            j(:) = [1,0,2,1,0,3,2,1,0,4,3,2,1,0];
            j = j(ones(1,k),:); % Repmat to size [k,14]
            
            % Calculate Normalized Moneyness Measure; Eq (11)
            d = log(S./K);
            
            % Convert Put to Call by Parity Relation; Eq (9)
            V(p==1) = V(p==1) + S(p==1) - K(p==1);
            
            C = V./S; % Normalized Call Price
            
            d = d'; d = d(:,ones(1,14)); % Repmat to [k x 14]
            C = C'; C = C(:,ones(1,14)); % Repmat to [k x 14]
            
            % Rational Function; Eq (19)
            fcnv = @(pi,m,n,i,j,d,C)(pi(1).*d(:,1) + pi(2).*sqrt(C(:,1)) + pi(3).*C(:,1)...
                + (sum(n.*((d.^i).*(sqrt(C).^j)), 2))./(1 + sum(m.*((d.^i).*(sqrt(C).^j)), 2)));
            v1 = fcnv(pi,m,n,i,j,d,C); % D- Domain (d<=-1)
            v2 = fcnv(pi,m,n,i,j,-d,exp(d).*C + 1 -exp(d)); % Reflection for D+ Domain (d>1)
            v = zeros(k,1);
            v(d(:,1)<=0)=v2(d(:,1)<=0);
            v(d(:,1)>0)=v1(d(:,1)>0);
            
            % Domain-of-Approximation is d={-0.5,+0.5},v={0,1},d/v={-2,2}
            domainFilter = d(:,1)>=-0.5 & d(:,1)<=0.5 & v > 0 & v <1 & (d(:,1)./v)<=2 & (d(:,1)./v)>=-2;
            v(~domainFilter) = NaN;
            
            sigma = v'./sqrt(T); % v = sigma.*(sqrt(T));
            
            %% OUT-OF-DOMAIN VALUES
            if any(~domainFilter(:) & ~isnan(V(:))) % any out-of-Li domain values
                
                Y = sigma(:);
                
                sigma(isnan(Y)) = sqrt(2*3.14159265359./T(isnan(Y))).*V(isnan(Y))./S(isnan(Y));
            end
            
            %%  ROOT-FINDER FOR INCREASED CONVERGENCE
            
            %   BS
            d1fcn = @(sig,B)((log(S(B)./K(B)) + sig(B).^2*0.5.*(T(B)))./(sig(B).*sqrt(T(B))));
            d2fcn = @(sig,B)((log(S(B)./K(B)) - sig(B).^2*0.5.*(T(B)))./(sig(B).*sqrt(T(B))));
            callfcn = @(sig,B)(S(B).*fcnN(d1fcn(sig,B)) - K(B).*fcnN(d2fcn(sig,B)));
            
            %   Greeks
            vegafcn = @(sig,B)(S(B).*fcnn(d1fcn(sig,B)).*(sqrt(T(B))));
            vommafcn = @(sig,B)(S(B).*fcnn(d1fcn(sig,B)).*(sqrt(T(B))).*d1fcn(sig,B).*d2fcn(sig,B)./sig(B));
            ultimafcn = @(sig,B)(-S(B).*fcnn(d1fcn(sig,B)).*(sqrt(T(B))).*(d1fcn(sig,B).*d2fcn(sig,B).*(1-d1fcn(sig,B).*d2fcn(sig,B))+d1fcn(sig,B).^2+d2fcn(sig,B).^2)./(sig(B).^2));
            
            %   Accepted error
            tolerance=1e-8;
            %   Amount of iterations
            kmax = 50;
            
            %   Difference between our answer and BS
            difffcn = @(sig,B)(V(B) - callfcn(sig,B));
            
            %   Initial error
            B = true(size(V(:)));
            
            err = difffcn(sigma,B);
            
            %   Convergence Matrix
            B = abs(err)>tolerance;
            
            k = 1; % Initialize Count
            while any(B) && k<=kmax % Iterate until convergence or limit
                
                % Calculate Derivatives (Greeks)
                vega = vegafcn(sigma,B); %f'(x_n)
                vomma = vommafcn(sigma,B); %f''(x_n)
                ultima = ultimafcn(sigma,B); %f'''(x_n)
                
                % Newton Raphson Method x_n+1 = x_n + f(x_n)/f'(x_n)
                % sigma(B) = sigma(B)  + (err(B)./vega) ;
                
                % Halley Method x_n+1 = x_n - f(x_n)/( f'(x_n) - f(x_n)*f''(x_n)/2*f'(x_n))
                sigma(B) = sigma(B)  - err(B)./(-vega-(-err(B).*vomma./(-2.*vega)));
                
                % Householder Method x_n+1 = x_n - f(x_n)/( f'(x_n) - f(x_n)*f''(x_n)/2*f'(x_n))
                %sigma(B) = sigma(B) - (6.*err(B).*vega.^2 + 3.*err(B).^2.*vomma)./(-6.*vega.^3 - 6.*err(B).*vega.*vomma - err(B).^2.*ultima);
                
                % Update Error
                err(B) = difffcn(sigma,B);
                
                % Ascertain Convergence to Tolerance
                B = abs(err)>tolerance; % Convergence Matrix
                
                % Increment Count
                k = k + 1;
            end
            
            sigma(B) = NaN; % any remaining sigma are not worth calculating
        end
        
        %%  Gaussian Subfunctions
        
        function p = fcnN(x)
            p = 0.5*(1.+erf(x./sqrt(2)));
        end
        %
        function p = fcnn(x)
            p = exp(-0.5*x.^2)./sqrt(2*pi);
        end
        
        %% extra function
        function varargout = curly(x, varargin)
            [varargout{1:nargout}] = x{varargin{:}};
        end
    end
end