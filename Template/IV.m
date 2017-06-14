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