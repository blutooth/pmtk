classdef bernoulliDist < binomDist
  
  %% main methods
  methods
    function obj = bernoulliDist(mu)
     obj; % make dummy object
      if nargin == 0;
        mu = [];
      end
     obj = setup(obj, 1, mu, true);
    end
  end
  
  %% demos
  methods(Static = true)
    function demoSeqUpdate()
      setSeed(0);
      m = bernoulliDist(0.7);
      n = 100;
      X = sample(m, n);
      figure; hold on;
      [styles, colors, symbols] =  plotColors();
      ns = [0 5 50 100];
      for i=1:length(ns)
        n = ns(i);
        mm = bernoulliDist(betaDist(1,1));
        mm = inferParams(mm, 'data', X(1:n));
        plot(mm.mu, 'plotArgs', {styles{i}, 'linewidth', 2});
        legendstr{i} = sprintf('n=%d', n);
      end
      legend(legendstr)
      xbar = mean(X);
      pmax = 10;
      h=line([xbar xbar], [0 pmax]); set(h, 'linewidth', 3);
    end
    
    function demoBayesianUpdatingDiscretePrior()
      Thetas = 0:0.1:1;
      K = length(Thetas);
      prior = discreteDist(normalize((1:K).^3), Thetas);
      N1 = 3; N0 = 7; % data
      %p = binomDist(1, prior);
      p = bernoulliDist(prior);
      p = inferParams(p, 'suffStat', [N1 N1+N0]);
      post = p.mu;
      ThetasDense = 0:0.01:1;
      likDense = ThetasDense.^N1 .* (1-ThetasDense).^N0;
      figure;
      subplot(3,1,1); plot(prior); title('prior');
      subplot(3,1,2); plot(ThetasDense, likDense); title('likelihood')
      subplot(3,1,3); plot(post); title('posterior');
    end
     
  end
 
 
end
