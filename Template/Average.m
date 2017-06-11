function A = Average(aAskPrices, aBidPrices)
    %   Returns the average price    

    SKEW = 0;
    
    if(~isempty(aAskPrices) && ~isempty(aBidPrices) && ~isnan(aBidPrices(1)) && ~isnan(aAskPrices(1)))
        A = ((1-SKEW)*aAskPrices(1) + (1+SKEW)*aBidPrices(1))/2;
    elseif(isempty(aAskPrices) && ~isempty(aBidPrices) && ~isnan(aBidPrices(1)))
        A = aBidPrices(1);
    elseif(isnan(aAskPrices) && ~isempty(aBidPrices) && ~isnan(aBidPrices(1)))
        A = aBidPrices(1);
    elseif(~isempty(aAskPrices) && isempty(aBidPrices) && ~isnan(aAskPrices(1)))
        A = aAskPrices(1);
    elseif(~isempty(aAskPrices) && isnan(aBidPrices) && ~isnan(aAskPrices(1)))
        A = aAskPrices(1);
    else
        A = NaN;
    end
end