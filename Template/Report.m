function Report(aTrades, aSpot)
    % @struct aTrades   price: The price of the stock
    %                   volume: The volume of the stock
    %                   ISIN: The identification string
    %                   side: Buy (1) or sell (-1)
%     
%     myING = zeros(3,1);
%         
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
%     
    %We make a list of all the options we bought
    boughtOptions = {aTrades.ISIN{1}};
    for i=1:length(aTrades.ISIN)
        anOption = aTrades.ISIN(i);
        j = 1;
        while j<= length(boughtOptions)
            if(~strcmp(anOption{1},boughtOptions(j)))
                if(j == length(boughtOptions))
                    boughtOptions = [boughtOptions anOption{1}];
                else
                    j = j+1;
                end
            else
                break;
            end
        end
    end
    
    aTrades.optionInfo = struct('ISIN',boughtOptions,'p',[],'v',[]);
%     We loop through the entire struct
%     for i=1:length(aTrades.price)
%         
        

    % Report cash and position given the trades and a spot at the time of expiry
    fileID= fopen('report.txt','wt');
    fprintf(fileID,'%19s %8s %5s %5s\r\n','ISIN','POSITION','VALUE','TOTAL');
    for i=1:length(boughtOptions)
        myOption = boughtOptions(i);
        fprintf(fileID,'%19s %8.0f %5.0f %5.0f\r\n',myOption{1},100,20,30);
    end
    fclose(fileID);
    type report.txt
end
