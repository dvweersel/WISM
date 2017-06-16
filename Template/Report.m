function Report(aTrades, aSpot)
    % @struct aTrades   price: The price of the stock
    %                   volume: The volume of the stock
    %                   ISIN: The identification string
    %                   side: Buy (1) or sell (-1)
    
%     myING = zeros(3,1);
%     % We loop through the entire struct
%     for i=1:length(aTrades.price)
%         for j=1:length(aTrades.ISIN)
%             if(strcmp(aTrades.ISIN(i),aTrades.ISIN(j))
%                 % Assets = side * volume;
%                 my_aTrades.ISIN(i)(1)=my_aTrades.ISIN(i)(1)+ aTrades.side(i) * aTrades.volume(i);
%                 % Value = ?
%                 ?;
%                 % Total = Assets * Value
%                 ?;
%             else
%                 % We add to the portfolio of the shares of ING
%                 myING(1) = myING(1)+aTrades.side(i)*aTrades.volume(i);
%                 myING(2) = ?;
%             end
%         end
%     end
    
    
                
    % Report cash and position given the trades and a spot at the time of expiry
    fileID= fopen('report.txt','w');
    fprintf(fileID,'%19s %8s %5s %5s\r\n','ISIN','POSITION','VALUE','TOTAL');
        
    fprintf(fileID,'%19s %8s %5s %5s\r\n',aTrades.ISIN{1},100,20);
    fclose(fileID);
    type report.txt
end
