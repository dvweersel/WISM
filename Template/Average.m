function A = Average(aAskPrices, aBidPrices)
    %   Returns the stock price    

    SKEW = 0;
    
    if(~isempty(aAskPrices) && ~isempty(aBidPrices))
        A = ((1-SKEW)*aAskPrices(1) + (1+SKEW)*aBidPrices(1))/2;
    elseif(isempty(aAskPrices) && ~isempty(aBidPrices))
        A = aBidPrices(1);
    elseif(~isempty(aAskPrices) && isempty(aBidPrices))
        A = aAskPrices(1);
    else
        A = NaN;
    end
end