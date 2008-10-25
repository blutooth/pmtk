classdef sampleDist < probDist
  % sample based representation of a pdf
  
  properties
    samples; % rows are samples, columns are dimensions
  end

  %%  Main methods
  methods
    function m = sampleDist(X)
      if nargin < 1, X = []; end
      m.samples = X;
    end
    
    function mu = mean(obj)
      mu = mean(obj.samples)';
    end
    
    function mu = median(obj)
      mu = median(obj.samples)';
    end
    
    function m = mode(obj)
      [ndx, m] = max(obj.samples)';
    end
    
    function v = var(obj)
      v = var(obj.samples);
    end
    
    function C = cov(obj)
      C = cov(obj.samples);
    end
    
    function mm = marginal(m, queryVars)
      mm = sampleDist(m.samples(:,queryVars));
    end
    
    function [l,u] = credibleInterval(obj, p)
      if nargin < 2, p = 0.95; end
      q= (1-p)/2;
      [Nsamples d] = size(obj.samples);
      for j=1:d
        tmp = sort(obj.samples(:,j), 'ascend');
        l(j) = tmp(floor((1-q)*Nsamples));
        u(j) = tmp(floor(q*Nsamples));
      end
    end
    
    function [h, hist_area] = plot(obj, varargin)
      [scaleFactor, useHisto] = process_options(...
        varargin, 'scaleFactor', 1, 'useHisto', 1);
      switch nfeatures(obj)
        case 1,
          if useHisto
            [bin_counts, bin_locations] = hist(obj.samples, 20);
            bin_width = bin_locations(2) - bin_locations(1);
            hist_area = (bin_width)*(sum(bin_counts));
            %counts = scaleFactor * normalize(counts);
            %counts = counts / hist_area;
            h=bar(bin_locations, bin_counts);
          else
            [f,xi] = ksdensity(obj.samples(:,1));
            plot(xi,f);
          end
        case 2, h=plot(obj.samples(:,1), obj.samples(:,2), '.');
        otherwise, error('can only plot in 1d or 2d'); 
      end
    end
      
    function d = nfeatures(obj)
      % num dimensions (variables)
      mu = mean(obj); d = length(mu);
    end
  end
  
  %% Demos
  methods(Static = true)
    function demo(seed)
      if nargin < 1, seed = 1; end
      setSeed(seed);
      m = mvnDist;
      m = mkRndParams(m, 2);
      X = sample(m, 500);
      mS = sampleDist(X);
      figure(1);clf
      for i=1:2
        subplot2(2,2,i,1);
        mExact = marginal(m,i);
        mApprox = marginal(mS,i);
        [h, histArea] = plot(mApprox, 'useHisto', true);
        hold on
        [h, p] = plot(mExact, 'scaleFactor', histArea, 'plotArgs', {'linewidth', 2, 'color', 'r'});
        title(sprintf('exact mean=%5.3f, var=%5.3f', mean(mExact), var(mExact)));
        subplot2(2,2,i,2);
        plot(mApprox, 'useHisto', false);
        title(sprintf('approx mean=%5.3f, var=%5.3f', mean(mApprox), var(mApprox)));
      end
      figure(2);clf
      plot(m, 'useContour', 'true');
      hold on
      plot(mS);
    end
  end
  
end