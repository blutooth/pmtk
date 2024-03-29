% t  = locn
%   Z(t)|w ~ Discrete(w(:)), k in {1,2,3,4,k}
%   theta(:,t) | Z(t)=k ~ Dir(alpha(:,k))
%   x(i,t) | theta(:,t) ~ Discrete(theta(:,t))

%%%%%% Data generation

clear all

seed = 0; rand('state', seed); randn('state', seed); 
Nseq = 10;
Nlocn = 15;
Nletters = 4;
Nmix = 4;
pfg = 0.30;

mixweights = [pfg/Nmix*ones(1,Nmix) 1-pfg]; % 5 states
z = sampleDiscrete(mixweights, 1, Nlocn);
alphas = 1*ones(Nletters,Nmix);
for i=1:Nmix
  alphas(i,i) = 20; % reflects purity
end
alphas(:,Nmix+1) = ones(Nletters, 1); % state 5 is background

theta = zeros(Nletters, Nlocn);
data = zeros(Nseq, Nlocn);
chars = ['a' 'c' 'g' 't' '-']';
for t=1:Nlocn
  theta(:,t) = dirichlet_sample(alphas(:,z(t)),1)';
  data(:,t) = sampleDiscrete(theta(:,t), Nseq, 1);
  dataStr(:,t) = chars(data(:,t));
end

%dataStr
for i=1:Nseq
  for t=1:Nlocn
    fprintf('%s ', dataStr(i,t));
  end
  fprintf('\n');
end



seqlogo(dataStr)

zStr = chars(z);

%data = data(1:10,:);

if 0
figure(1); clf
image_rgb(data); title('location')
set(gca,'xtick',1:Nlocn);
for t=1:Nlocn
  str{t} = sprintf('%d', z(t));
end
set(gca,'xticklabel',str);
ylabel('sample')
end

%figure(2);clf
%image_rgb(z); title('z true'); 

%figure(3);clf
%imagesc(theta); title('theta'); colorbar

%%%%%%%%%%% Inference

nvec = zeros(Nletters, Nlocn);
for t=1:Nlocn
  prior = mixweights;
  nvec(:,t) = hist(data(:,t), 1:Nletters)';
  for k=1:Nmix+1
    loglik(k) = dirichlet_logmarglik(alphas(:,k), nvec(:,t));
  end
  logprior = log(prior);
  numer = logprior + loglik;
  postZ(:,t) = exp(numer - logsumexp(numer(:)));
end

prob = nvec./repmat(sum(nvec,1),4,1);


%figure(3);clf
%imagesc(postZ); title('p(Z(:,t)|Dt)'); colorbar

figure(3);clf;bar(entropy(prob));
title('entropy vs position')

postC = sum(postZ(1:4,:));
figure(4);clf
stem(postC); title('p(C(t)=1|Dt)');
hold on
for t=1:Nlocn
  if z(t)<5
    % if conserved, mark with x
    plot(t,postC(t),'rx','markersize',14);
  end
end
set(gca,'xlim',[0 Nlocn+1]);
