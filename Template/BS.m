function W = BS(S, K, T, sigma, p)
    n=length(S);
        
    %We create variables so that we can differentiate later with these
    %variables to get things like the delta and gamma.
    %here s=stock price variable, k= strike price variable, t=expiry time
    %variable, o=volatility variable. 
    syms s k t o;    
    
    %calculating the bounds of the integrals as a function of s,k,t and o.     
    d1= 1/(o*t^(0.5))*(log(s/k) + 0.5*o^2*t);
    d2= 1/(o*t^(0.5))*(log(s/k) - 0.5*o^2*t);
    
    %creating the formulas for the price, delta and gamma by a call option
    I1= NormalDistcdf(d1);
    I2= NormalDistcdf(d2);
    price1 = s*I1-k*I2;
    delta1 = diff(price1,s);
    gamma1 = diff(delta1,s);
    
    %creating the formulas for the price, delta and gamma by a put option
    I3= NormalDistcdf(-d2);
    I4= NormalDistcdf(-d1);
    price2 = k*I3 - s*I4;       
    delta2 = diff(price2,s);
    gamma2 = diff(delta2,s);
    
    V=zeros(1,n);
    D=zeros(1,n);
    G=zeros(1,n);
    %Now we substitute our values in the formulas
    for i=1:n
        if p(1,i)==0
            V(1,i)=subs(price1, [s k t o], [S(1,i), K(1,i), T(1,i) sigma(1,i)]);
            D(1,i)=subs(delta1, [s k t o], [S(1,i), K(1,i), T(1,i) sigma(1,i)]);
            G(1,i)=subs(gamma1, [s k t o], [S(1,i), K(1,i), T(1,i) sigma(1,i)]);
        elseif p(1,i)==1
            V(1,i)=subs(price2, [s k t o], [S(1,i), K(1,i), T(1,i) sigma(1,i)]);
            D(1,i)=subs(delta2, [s k t o], [S(1,i), K(1,i), T(1,i) sigma(1,i)]);
            G(1,i)=subs(gamma2, [s k t o], [S(1,i), K(1,i), T(1,i) sigma(1,i)]);
        end
    end
    W=zeros(3,n);
    W(1,:)=V(1,:);
    W(2,:)=D(1,:);
    W(3,:)=G(1,:);
end

%this function is used to get the integrals of the density function of the
%standard normal distribution. 
function I=NormalDistcdf(d)
    syms x
    f=(2*pi)^(-1/2)*exp(-0.5*x^2);
    I = int(f,x,-inf,d);
end