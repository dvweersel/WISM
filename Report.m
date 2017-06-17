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
    [~, T, p, K] = ParseOptionISINs(nOption);
    T = (T - now())/254;
    optionISIN = struct('ISIN', [], 'T', T, 'p', p, 'K', K);
        
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
    end
    
   %at the end we exercise the options that make profit
    for i=length(aTrades.price)
        if not(strcmp(aTrades.ISIN(i), 'ING'))
            for k=1:20
                cell1 = nOption(k);
                cell2 = aTrades.ISIN(i);
                if (strcmp(cell1{1}, cell2{1}))
                    m=k;
                    break;
                end
            end
            
            % contractsize == 1, so we have that 1 volume option equals 1 volume stock
            if optionISIN.p(m) == 0 && optionISIN.K(m) < aSpot
                myINGPosition(end) = myINGPosition(end) + 1 * aTrades.volume(i);
                myINGOptionPositions(m,end) = myINGPosition(m,end) - 1 * aTrades.volume(i);
                myINGCash(end) = myINGPosition(end) - 1 * aTrades.volume(i) * optionISIN.K(m);
                myINGOptionCash(end) = myINGOptionCash(end) + 1 * aTrades.volume(i) * (aSpot - optionISIN.K(m));
            elseif optionISIN.p(m) == 1 && optionISIN.K(m) > aSpot
                myINGPosition(end) = myINGPosition(end) - 1 * aTrades.volume(i);
                myINGOptionPositions(m,end) = myINGPosition(m,end) + 1 * aTrades.volume(i);
                myINGCash(end) = myINGPosition(end) + 1 * aTrades.volume(i) * optionISIN.K(m);
                myINGOptionCash(end) = myINGOptionCash(end) - 1 * aTrades.volume(i) * (optionISIN.K(m) - aSpot);
            end
        end
    end
    
    for i=1:length(aTrades.price)
        myCashSum(i+1) = myINGCash(i+1) + sum(myINGOptionCash(:,i+1));
        myPositionSum(i+1) = myINGPosition(i+1) + sum(myINGOptionPositions(:,i+1));
    end
    
    subplot(2,3,1)
    plot(myINGPosition)
    title('Position of stock')
    xlabel('time')
    ylabel('position')
    
    subplot(2,3,2)
    for k=1:20
        plot(myINGOptionPositions(k,:))
        hold on
    end
    hold off
    title('Positions of options')
    xlabel('time')
    ylabel('position')
    
    subplot(2,3,3)
    plot(myPositionSum)
    title('Total position')
    xlabel('time')
    ylabel('position')
    
    subplot(2,3,4)
    plot(myINGCash)
    title('Cash position of the stock')
    xlabel('time')
    ylabel('cash position')
    
    subplot(2,3,5)
    for k=1:20
        plot(myINGOptionCash(k,:))
        hold on
    end
    hold off
    title('Cash position of the options')
    xlabel('time')
    ylabel('cash position')
    
    subplot(2,3,6)
    plot(myCashSum)
    title('Total cash position')
    xlabel('time')
    ylabel('cash position')
    
    %Combining the two matrices to get a totalcash position
    CASH = myINGCash(end); 
    
    %Write out the results
    fileID= fopen('report.txt','wt');
    myValues = [8,-8,9,-9,9.5,-9.5,9.75,-9.75,10,-10,10.25,-10.25,10.5,-10.5,11,-11,12,-12,14,-14];
    fprintf(fileID,'%19s %8s %10s %10s\r\n','ISIN','POSITION','VALUE','TOTAL');
    fprintf(fileID,'%19s %8.0f %10s %10s\r\n','ING',myINGPosition(end),aSpot,aSpot*myINGPosition(end));
    %Loop through all the options
    for i=1:20
        myOptionName = nOption(i);
        myOptPos = myINGOptionPositions(i,end);
        if(mod(i,2)==1)
            myOptVal = aSpot - myValues(i);
        else
            myOptVal = -myValues(i)-aSpot;
        end
        fprintf(fileID,'%19s %8.0f %10.2f %10.2f\r\n',myOptionName{1},myOptPos,myOptVal,myOptPos*myOptVal);
    end
    fprintf(fileID,'%19s %8.0f %10s %10s\r\n','Payments',sum(myINGOptionCash(:,end)),...
                'Value', myINGPosition(end)*aSpot + CASH + sum(myINGOptionCash(:,end)));
    fprintf(fileID,'%19s %8s %10s %10s\r\n','Delta','DELTA','Gamma','GAMMA');
    fclose(fileID);
    type report.txt
end