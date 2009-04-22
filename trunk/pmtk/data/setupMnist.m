function [Xtrain,Xtest,ytrain,ytest] = setupMnist(binary, Ntrain, Ntest,full)

if nargin < 1, binary = false; end
if nargin < 2, Ntrain = 60000; end
if nargin < 3, Ntest = 10000; end
if nargin < 4, full  = false; end

%if(~exist('mnistAll.mat','file'))
%    error('Please download mnistAll.mat from http://www.cs.ubc.ca/~murphyk/pmtk/mnistALL.mat');    
%end
try
    load mnistALL
catch ME
    error('Please download mnistAll.mat from http://www.cs.ubc.ca/~murphyk/pmtk/mnistALL.mat');     
end
Xtrain = reshape(mnist.train_images(:,:,1:Ntrain),28*28,Ntrain)';
Xtest = reshape(mnist.test_images(:,:,1:Ntest),28*28,Ntest)';
ytrain = (mnist.train_labels);
ytest = (mnist.test_labels);
ytrain = ytrain(1:Ntrain);
ytest = ytest(1:Ntest);
clear mnist;
if(binary)
    mu = mean([Xtrain(:);Xtest(:)]);
    Xtrain = Xtrain >=mu;
    Xtest = Xtest >=mu;
end
ytrain = double(ytrain);
ytest  = double(ytest);

if(full)
   Xtrain = double(Xtrain);
   Xtest  = double(Xtest);
end

end