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