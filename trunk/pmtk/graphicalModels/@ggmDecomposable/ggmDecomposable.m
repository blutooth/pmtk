classdef ggmDecomposable < ggm
  % gaussian graphical model on decomposable graphs
  
  properties
  end

  %%  Main methods
  methods
    function obj = ggmDecomposable(G, mu, Sigma)
      % obj = ggmDecomposable(G, hiwDist(...), []) uses a prior of the form
      % p(mu) propto 1, p(Sigma) = hiw(G)
       if nargin == 0
         G = []; mu = []; Sigma = [];
       end
       obj.G = G; obj.mu = mu; obj.Sigma = Sigma;
    end
    
    function d = nnodes(obj)
      if ~isempty(obj.G), d = nnodes(obj.G); return; end
      if isa(obj.mu, 'hiwDist')
        d = size(obj.mu.Phi,1); 
      end
    end
    
    function L = logmarglik(obj, varargin)
      % L = logmarglik(obj, 'param1', name1, ...)
      % Arguments:
      % 'data' - data(i,:) is value for i'th case
      [Y] = process_options(varargin, 'data', []);
      assert(isa(obj.mu, 'hiwDist'))
      % p77 of Helen Armstrong's PhD thesis eqn 4.16
      n = size(Y,1);
      Sy = n*cov(Y,1);
      G = obj.G; delta = obj.mu.delta; Phi = obj.mu.Phi;
      nstar = n-1; d = ndims(obj);
      L = lognormconst(hiwDist(G, delta, Phi)) ...
        - lognormconst(hiwDist(G, delta+n, Phi+Sy)) ...
        -  (nstar*d/2) * log(2*pi);
    end
    
    function objs = mkAllGgmDecomposable(obj)
      % objs{i} = ggmDecomp with HIW prior for i'th chordal graph
      assert(isa(obj.mu, 'hiwDist'))
      delta = obj.mu.delta; Phi = obj.mu.Phi;
      nnodes = size(Phi,1);
      Gs = mkAllChordal(chordalGraph, nnodes, true);
      for i=1:length(Gs)
        objs{i} = ggmDecomposable(Gs{i}, hiwDist(Gs{i}, delta, Phi), []);
      end
    end
    
    function [logpostG, GGMs, mapG, mapPrec, postG, postMeanPrec, postMeanG] = ...
        computePostAllModelsExhaustive(obj, Y)
      GGMs = mkAllGgmDecomposable(obj);
      N = length(GGMs);
      prior = normalize(ones(1,N));
      logpostG = zeros(1,N);
      for i=1:N
        logpostG(i) = log(prior(i)) + logmarglik(GGMs{i}, 'data', Y);
      end
      bestNdx = argmax(logpostG);
      mapG = GGMs{bestNdx}.G;
      n = size(Y,1);
      nstar = n-1; % since mu is unknown
      Sy = n*cov(Y,1);
      delta = obj.mu.delta; Phi = obj.mu.Phi;
      deltaStar = delta + nstar; PhiStar = Phi + Sy;
      mapPrec = meanInverse(hiwDist(mapG, deltaStar, PhiStar));
      if nargout >= 3
        logZ = logsumexp(logpostG(:));
        postG = exp(logpostG - logZ);
      end
      if nargout >= 4
        d = nnodes(obj);
        postMeanPrec = zeros(d,d);
        postMeanG = zeros(d,d);
        % Armstrong thesis p80
        for i=1:N
          postMeanPrec = postMeanPrec + postG(i) * meanInverse(hiwDist(GGMs{i}.G, deltaStar, PhiStar));
          postMeanG = postMeanG + postG(i) * GGMs{i}.G.adjMat;
        end
      end
    end
    
    
  end
  
  
  %% Demos
  methods(Static=true)
    function demoPostModelsExhaustive(varargin)
      % Examples
      % demoExhaustive('n',10,'d',5,'graphType','chain')
      % demoExhaustive('n',100,'d',4,'graphType','loop')
      % demoExhaustive('n',100,'d',4,'graphType','aline4')
      [doPrint, n, d, graphType] = process_options(...
        varargin, 'doPrint', false, 'n', 10, 'd', 4, 'graphType', 'chain');
       seeds = 1:3;
       for i=1:length(seeds)
         [loss(i,:), nll(i,:), names] = ...
           ggmDecomposable.helperPostModelsExhaustive('seed', seeds(i), ...
           'd', d, 'n', n, 'graphType', graphType);
       end
       figure(4);clf
       subplot(1,2,1); boxplot(loss, 'labels', names); title('KL loss')
       subplot(1,2,2); boxplot(nll, 'labels', names); title('nll')
       suptitle(sprintf('d=%d, n=%d, graph=%s, ntrials = %d', ...
         d, n, graphType, length(seeds)))
    end
    
    function [loss, nll, names] = helperPostModelsExhaustive(varargin)
      [seed, n, d, graphType] = process_options(...
        varargin, 'seed', 0, 'n', 10, 'd', 4, 'graphType', 'chain');
      Phi = 0.1*eye(d); delta = 5; % hyper-params
      setSeed(seed);
      Gtrue = undirectedGraph('type', graphType, 'nnodes', d);
      truth = ggm(Gtrue, [], []);
      Atrue = Gtrue.adjMat;
      truth = mkRndParams(truth);
      Y = sample(truth, n);
     
      prec{1} = inv(truth.Sigma); names{1} = 'truth';
      prec{2} = inv(cov(Y)); names{2} = 'emp';
      obj = ggmDecomposable([], hiwDist([], delta, Phi), []);
      [logpostG, GGMs, mapG, mapPrec, postG, postMeanPrec, postMeanG] = ...
        computePostAllModelsExhaustive(obj, Y);
      prec{3} = postMeanPrec; names{3} = 'mean';
      prec{4} = mapPrec; names{4} = 'mode';
      
      % predictive accuracy
      nTest = 1000;
      Ytest = sample(truth, nTest);
      for i=1:4
        SigmaHat = inv(prec{i});
        model = mvnDist(mean(Y), SigmaHat);
        nll(i) = negloglik(model, Ytest);
      end
      
      figure(1);clf;
      bar(postG);
      trueNdx = [];
      for i=1:length(GGMs)
        if isequal(GGMs{i}.G.adjMat, Atrue)
          trueNdx = i; break;
        end
      end
      if isempty(trueNdx)
        title(sprintf('p(G|D), truth=non decomposable'));
      else
         title(sprintf('p(G|D), truth=%d', trueNdx));
      end
      
      figure(2);clf;
      for i=1:4
        SigmaHat = inv(prec{i});
        M = SigmaHat * inv(truth.Sigma);
        loss(i) = trace(M) - log(det(M)) - d; % KL loss
        subplot(2,2,i);
        %imagesc(prec{i}); colormap('gray');
        hintonDiagram(prec{i});
        title(sprintf('%s, KLloss = %3.2f, nll =%3.2f', names{i}, loss(i), nll(i)));
        hold on
      end

      [pmax, Gmax] = max(postG);
      Gmap = GGMs{Gmax}.G;
      Amap = Gmap.adjMat;
      %draw(Gmap); title('Gmap')
      hamming = sum(abs(Amap(:) - Atrue(:)));
      figure(3);clf
      subplot(2,2,1); hintonDiagram(Atrue); title('true G')
      subplot(2,2,2); hintonDiagram(Amap); title(sprintf('G map, hamdist=%d', hamming))
      subplot(2,2,3); hintonDiagram(postMeanG); title('post mean G');
     
      restoreSeed;
    end
    
  end
    

end