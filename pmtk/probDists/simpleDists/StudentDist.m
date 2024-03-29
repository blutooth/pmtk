classdef StudentDist < ProbDist 
  %  student T p(X|dof, mu,sigma2) 
  
  properties
    mu;
    sigma2;
    dof;
    productDist;
  end
  
  %% Main methods
  methods
    function m = StudentDist(varargin)
      [m.dof, m.mu, m.sigma2, m.productDist] = processArgs(varargin, ...
        '-dof', [], '-mu', [], '-sigma2', [], '-productDist', false);
    end

    function d = ndistrib(m)
      d = length(m.mu);
    end
    
    function [l,u] = credibleInterval(obj, p)
      if nargin < 2, p = 0.95; end
      alpha = 1-p;
      sigma = sqrt(var(obj));
      mu = obj.mu;
      nu = obj.dof;
      l = mu + sigma.*tinv(alpha/2, nu);
      u = mu + sigma.*tinv(1-(alpha/2), nu);
    end
    
    function logZ = lognormconst(obj)
      v = obj.dof;
      logZ = -gammaln(v/2 + 1/2) + gammaln(v/2) + 0.5 * log(v .* pi .* obj.sigma2);
    end
    
    
    function L = logprob(obj, X)
      % Return col vector of log probabilities for each row of X
       % L(i) = log p(X(i) | params) 
       % L(i) = log p(X(i) | params(i)) (set distrib)
       % L(i) = sum_j log p(X(i,j) | params(j)) (prod distrib)
       % L = sum_j log p(X(1,j) | params(j)) (prod distrib)
      N = size(X,1);
      v = obj.dof; mu = obj.mu; s2 = obj.sigma2;
      logZ = lognormconst(obj);
      if ~obj.productDist
        X = X(:);
        if isscalar(mu)
          M = repmat(mu, N, 1); S2 = repmat(s2, N, 1);
          V = repmat(v, N, 1); LZ = repmat(logZ, N, 1);
        else
          % set distribution
          M = mu(:); S2 = s2(:); V = v(:); LZ = logZ(:);
        end
        L = (-(V+1)/2) .* log(1 + (1./V).*( (X-M).^2 ./ S2 ) ) - LZ;
      else
        M = repmat(rowvec(mu), N, 1);
        S2 = repmat(rowvec(s2), N, 1);
        V = repmat(rowvec(v), N, 1);
        LZ = repmat(rowvec(logZ), N, 1);
        Lij = (-(V+1)/2) .* log(1 + (1./V).*( (X-M).^2 ./ S2 ) ) - LZ;
        L = sum(Lij,2);
        if 0 % debugging
          for j=1:d
            v = obj.dof(j); mu = obj.mu(j); s2 = obj.sigma2(j);
            x = X(:,j);
            L2(:,j) = (-(v+1)/2) * log(1 + (1/v)*( (x-mu).^2 / s2 ) ) - logZ(j);
          end
          assert(approxeq(Lij,L2))
        end
      end
    end
    
   
   
     function X = sample(obj, n)
      % X(i,j) = sample ffrom params(j) i=1:n
      d = ndistrib(obj);
      assert(statsToolboxInstalled); %#statsToolbox
      X = zeros(n, d);
      for j=1:d
        mu = repmat(obj.mu(j), n, 1);
        X(:,j) = mu + sqrt(obj.sigma2(j))*trnd(obj.dof(j), n, 1);
      end
    end

    function mu = mean(obj)
      mu = obj.mu;
    end

    function mu = mode(m)
      mu = mean(m);
    end

    function v = var(obj)
      v = (obj.dof./(obj.dof-2)).*obj.sigma2;
    end
   
    function obj = fit(obj, varargin)
        % m = fit(model, 'name1', val1, 'name2', val2, ...)
        % Finds the MLE. Needs stats toolbox.
        % Arguments are
        % data - data(i) = case i
        %
        [X, suffStat, method] = process_options(...
            varargin, 'data', [], 'suffStat', [], 'method', 'mle');
        assert(statsToolboxInstalled); %#statsToolbox
        params = mle(X, 'distribution', 'tlocationscale');
        obj.mu = params(1);
        obj.sigma2 = params(2);
        obj.dof = params(3);
    end
      
    function h=plot(obj, varargin)
      sf = 2;
      if(~obj.productDist)
        m = mean(obj); v = sqrt(var(obj));
        xrange = [m-sf*v, m+sf*v];
        [plotArgs, npoints, xrange, useLog] = processArgs(...
          varargin, '-plotArgs' ,{}, '-npoints', 100, ...
          '-xrange', xrange, '-useLog', false);
        xs = linspace(xrange(1), xrange(2), npoints);
        p = logprob(obj, xs(:));
      if ~useLog, p = exp(p); end
      h = plot(colvec(xs), colvec(p), plotArgs{:});
      else
        m = mean(obj); v = sqrt(var(obj))';
        xrange = [m-sf*v, m+sf*v];
        [plotArgs, npoints, xrange, useLog] = processArgs(...
          varargin, '-plotArgs' ,{}, '-npoints', 100, ...
          '-xrange', xrange, '-useLog', false);
        [X1,X2] = meshgrid(linspace(xrange(1,1), xrange(1,2), npoints)',...
                    linspace(xrange(2,1), xrange(2,2), npoints)');
        X = [X1(:) X2(:)];
        p = logprob(obj, X);
      if ~useLog, p = exp(p); end
      [nr] = size(X1,1); nc = size(X2,1);
      p = reshape(p, nr, nc);
      %h = plot(X1, X2, colvec(p), plotArgs{:});
      [c,h] = contour(X1, X2, p, plotArgs{:});
      end
    end
    
  end % methods

  
  
end
