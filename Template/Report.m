function Report(aTrades,aSpot)
    % @struct aTrades   price: The price of the stock
    %                   volume: The volume of the stock
    %                   ISIN: The identification string
    %                   side: Buy (1) or sell (-1)

    % The position at the ING
    myINGPosition = zeros(1,length(aTrades.price));
        
    % The positions at the ING options
    myINGOptionPositions = zeros(20,length(aTrades.price));
        
    % The cash position at the ING
    myINGCash = zeros(1,length(aTrades.price));
        
    % The cash positions at the ING options
    myINGOptionCash = zeros(20,length(aTrades.price));
    
    % The sum of the positions
    myPositionSum = zeros(1,length(aTrades.price));
        
    % The sum of the cash positions
    myCashSum = zeros(1,length(aTrades.price));
    
    nOption = GetAllOptionISINs();              
    
    %updating the positions
    %We loop through the entire struct
    for i=1:length(aTrades.price)
        % IF ISIN = ING we add it to the ING portfolio
        if(strcmp(aTrades.ISIN(i), 'ING'))
            % Assets = side * volume;
            myINGPosition(i+1) = myINGPosition(i) + aTrades.side(i) * aTrades.volume(i); 
            myINGOptionPositions(:,i+1) = myINGOptionPositions(:,i);
        % ELSE we add it to the INGOptions portfolio in the same way
        else
            myINGPosition(i+1) = myINGPosition(i); 
            myINGOptionPositions(:,i+1) = myINGOptionPositions(:,i);
            for k=1:20
                cell1 = nOption(k);
                cell2 = aTrades.ISIN(i);
                % IF ISIN equals the ISIN of an option we add it to
                % the portfolio of that option
                if (strcmp(cell1{1}, cell2{1}))
                    m=k;
                    break;
                end
            end
            myINGOptionPositions(m,i+1) = myINGOptionPositions(m,i) + aTrades.side(i) * aTrades.volume(i);
        end
        myPositionSum(i+1) = myINGPosition(i+1) + sum(myINGOptionPositions(:,i+1));
    end
    
    %updating the cash positions
    % We loop through the entire struct
    for i=1:length(aTrades.price)
        % IF ISIN = ING we add it to the ING portfolio
        if(strcmp(aTrades.ISIN(i), 'ING'))
            % Cash = - side * volume * price; If we buy stock, we spend cash
            myINGCash(i+1) = myINGCash(i) ...
                            - aTrades.side(i) * aTrades.volume(i) * aTrades.price(i); 
            myINGOptionCash(:,i+1) = myINGOptionCash(:,i);
        % ELSE we add it to the INGOptions portfolio in the same way
        else
            myINGCash(i+1) = myINGCash(i); 
            myINGOptionCash(:,i+1) = myINGOptionCash(:,i);
            for k=1:20
                cell1 = nOption(k);
                cell2 = aTrades.ISIN(i);
                % IF ISIN equals the ISIN of an option we add it to
                % the portfolio of that option
                if (strcmp(cell1{1}, cell2{1}))
                    m=k;
                    break;
                end
            end
            myINGOptionCash(m,i+1) = myINGOptionCash(m,i) ...
                                    - aTrades.side(i) * aTrades.volume(i) * aTrades.price(i);
        end
        myCashSum(i+1) = myINGCash(i+1) + sum(myINGOptionCash(:,i+1));
    end
    subplot(2,3,1)
    plot(myINGPosition)
    subplot(2,3,2)
    for k=1:20
        plot(myINGOptionPositions(k,:))
        hold on
    end
    hold off
    subplot(2,3,3)
    plot(myPositionSum)
    
    subplot(2,3,4)
    plot(myINGCash)
    subplot(2,3,5)
    for k=1:20
        plot(myINGOptionCash(k,:))
        hold on
    end
    hold off
    subplot(2,3,6)
    plot(myCashSum)
    
    %Combining the two matrices to get a totalcash position
    CASH = myINGCash(end) + sum(myINGOptionCash(:,end));
    
    %Print the cashposition and the position on the two stocks
%     fileID= fopen('report.txt','w');
%     fprintf(fileID,'%8s %6s %3s %3s\r\n',' ','CASH','CBK','DBK');
%     fprintf(fileID,'%8s %6.2f %3.0f %3.0f','Position',CASH,myCBK(1),myDBK(1));
%     fclose(fileID);
%     type report.txt

    
end