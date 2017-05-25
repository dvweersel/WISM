function S = StockPrice(aAskPrices, aBidPrices)
    %   Returns the stock price    

    SKEW = 0;
    
    if(~isempty(aAskPrices) && ~isempty(aBidPrices))
        S = ((1-SKEW)*aAskPrices(1) + (1+SKEW)*aBidPrices(1))/2;
    elseif(isempty(aAskPrices) && ~isempty(aBidPrices))
        S = aBidPrices(1);
    elseif(~isempty(aAskPrices) && isempty(aBidPrices))
        S = aAskPrices(1);
    else
        S = NaN;
    end
end