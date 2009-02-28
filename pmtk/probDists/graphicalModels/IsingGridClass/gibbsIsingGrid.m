function avgX = gibbsIsingGrid(J, CPDs, visVals, varargin)
% visVals should be an n*m matrix
% Returns p(X(i,j)=1|y)

%#author Brani Vidakovic

[Nsamples, Nburnin, progressFn] = process_options(...
  varargin, 'Nsamples', 50000, 'Nburnin', 1000, ...
  'progressFn', []);

[M,N] = size(visVals);
Npixels = M*N;
localEvidence = zeros(Npixels, 2);
for k=1:2
  localEvidence(:,k) = exp(logprob(CPDs{k}, visVals(:)));
end

% init
[junk, guess] = max(localEvidence, [], 2);  % start with best local guess
X = ones(M, N);
offState = 1; onState = 2;
X((guess==offState)) = -1;
X((guess==onState)) = +1;

% And go...
avgX = zeros(size(X));
S = (Nsamples + Nburnin);
offState = 1; onState = 2;
for iter =1:S
  % select a pixel at random
  ix = ceil( N * rand(1) ); iy = ceil( M * rand(1) );
  pos = iy + M*(ix-1);
  neighborhood = pos + [-1,1,-M,M];
  neighborhood(([iy==1,iy==M,ix==1,ix==N])) = [];
  % compute local conditional
  wi = sum( X(neighborhood) );
  p1  = exp(J*wi) * localEvidence(pos,onState);
  p0  = exp(-J*wi) * localEvidence(pos,offState);
  prob = p1/(p0+p1);
  if rand < prob
    X(pos) = +1;
  else
    X(pos) = -1;
  end
  if (iter > Nburnin) %&& (mod(iter, thin)==0)
    avgX = avgX+X;
  end
  if ~isempty(progressFn)
    feval(progressFn, X, iter);
  end
end
avgX = avgX/Nsamples;
end
