classdef logregDist < condProbDist 
    % logistic regression, multiclass conditional distribution

    properties
        w; % MAP estimate of the optimal weights. w is  ndimensions-by-(nclasses-1)

        posteriorW;             % An mvnDist object representing the Laplace
                                % approximation to the full posterior, p(w|D).
                                % This is the approximation N(w|w_map|-inv(H))
                                % and is automatically set if fit() is called
                                % with prior = 'L2'.
        transformer;            % A data transformer object, e.g. kernelTransformer
        nclasses;               % The number of classes
    end

    %% Main methods
    methods

        function m =logregDist(varargin)
            % Constructor
            [m.transformer,  m.w, m.nclasses] = process_options( varargin ,...
                'transformer', []             ,...
                'w'          , []             , ...
                'nclasses'   , []);
        end

        function [obj, output] = fit(obj, varargin)
            % Compute the map estimate of the weights, obj.w for the model given
            % the training data, the prior type and regularization value, and the
            % optimization method. If prior is set to 'L2', the laplace
            % approximation to the posterior p(w|D) is also set.
            %
            % FORMAT:
            %           model = fit(model, 'name1', val1, 'name2', val2, ...)
            %
            % INPUT:
            %
            % 'X'      - The training examples: X(i,:) is the ith case
            % 'y'      - The class labels for X in {1...C}
            % 'prior'  - {'L1' | 'L2' | ['none']}]
            % 'lambda' - [0] regularization value
            % 'method' - 
            %
            %               ----L1----
            % {['projection'] | 'iteratedridge' | 'grafting' | 'orthantwise' |  'pdlb' |   'sequentialqp'
            %  |'subgradient' | 'unconstrainedapx' |  'unconstrainedapxsub' |  'boundoptrelaxed' |
            %  'boundoptstepwise'}
            %
            %            IF L2
            % {['lbfgs'] | 'newton' | 'bfgs' | 'newton0' | 'netwon01bfgs' | 'cg' |
            % 'bb' | 'sd' | 'tensor' | 'boundoptrelaxed' | 'boundoptstepwise'}
            %
            % OUTPUT:
            %
            % obj      - The fitted logregDist object
            % ouptut   - A structure holding the output of the fitting algorithm, if any.
            
            [X, y,  prior, lambda, method] = process_options(varargin,...
                'X'            , []                 ,...
                'y'            , []                 ,...
                'prior'        , 'none'             ,...
                'lambda'       , 0                  ,...
                'method'       ,'default'           );

            output = [];
            if lambda > 0 && strcmpi(prior, 'none'), prior = 'L2'; end

            offsetAdded = false;
            if ~isempty(obj.transformer)
                [X, obj.transformer] = train(obj.transformer, X);
                offsetAdded = obj.transformer.addOffset();
            end

            if isempty(obj.nclasses), obj.nclasses = length(unique(y)); end
            Y1 = oneOfK(y, obj.nclasses);

            switch lower(prior)
                case {'l1'}
                     obj = fitL1(obj,X,Y1,lambda,method,offsetAdded);
                case {'l2', 'none'}
                    [obj,output] = fitL2(obj,X,Y1,lambda,method,offsetAdded);
                otherwise
                    error(['unrecognized prior ' prior])
            end
        end

        function [pred,samples] = predict(obj,varargin)
        % Predict the class labels of the specified test examples using the
        % specified method.
        %
        % FORMAT:
        %          pred = predict(model, 'name1', val1, 'name2', val2, ...)
        %
        % INPUT:
        %
        % 'X'      The test data: X(i,:) is the ith case
        %
        % 'w'      (1) A matrix of weights of size
        %              ndimensions-by-(nclasses-1) representing the MAP
        %              estimate of the posterior p(w|D)
        %
        %          OR
        %
        %          (2) a mvnDist object representing the laplace
        %              approximation to the posterior p(w|D)
        %
        %          If not set, the value stored in this object is
        %          used instead, in particular: obj.w for case 1 and
        %          obj.posteriorW for case 2
        %
        % 'method' {['plugin'] | 'mc' | 'integral'}
        %
        %          The method to use:
        %
        %          'mc' is only available if w is an mvnDist object or if w was
        %          not specified and obj.posteriorW was set during the
        %          fitting of this object, (which occurs when the prior is
        %          set to 'L2').
        %
        %          'integral' uses a closed form approximation to the
        %          posterior predictive distribution but is only available
        %          in the 2 class case. Otherwise, the same conditions for
        %          'mc' apply
        %
        % nsamples [1000] The number of Monte Carlo samples to perform. Only
        %                 used when method = 'mc'
        %
        % OUTPUT:
        %
        % pred    - is a series of discrete distributions over class labels,
        %           one for each test example X(i,:). All of these are
        %           represented in a single discreteDist object such that
        %           pred.probs(i,c) is the probability that example i
        %           belongs to class c.
        %
        % samples -  A 3D matrix such that samples(i,c,s) = probability that
        %            example i belongs to class c according to sample s. If
        %            method is not 'mc', s = 1 and samples = pred.probs
            
            if(nargin == 2 && ~ischar(varargin{1}))
                varargin = [varargin,varargin{1}];
                varargin{1} = 'X';
            end
            [X,w,method,nsamples] = process_options(varargin,'X',[],'w',[],'method','plugin','nsamples',1000);
            if ~isempty(obj.transformer)
                X = test(obj.transformer, X);
            end
               
            switch method
                
                case 'plugin'
                    if(isempty(w)), w = obj.w; end
                    if(isempty(w)),error('Call fit() first or specify w');end
                    P = multiSigmoid(X,w);
                    pred = discreteDist(P);
                    samples = pred.probs;
                case 'mc'
                    w = checkW(w);
                    Wsamples = sample(w,nsamples);
                    samples = zeros(size(X,1),obj.nclasses,nsamples);
                    for s=1:nsamples
                        samples(:,:,s) = multiSigmoid(X,Wsamples(s,:)');
                    end
                    pred = discreteDist(mean(samples,3));
                case 'integral'
                    if(obj.nclasses ~=2),error('This method is only available in the 2 class case');                    end
                    w = checkW(w);
                    p = sigmoidTimesGauss(X, w.mu(:), w.Sigma);
                    p = p(:);
                    pred = discreteDist([p,1-p]);
                otherwise
                    error('%s is an unsupported prediction method',method);
                  
            end
                    function w = checkW(w)
                        if(isempty(w)),w = obj.posteriorW;end
                        if(isempty(w)),error('Call fit() first with an L2 prior or specify an mvnDist object for w representing p(w|D)');end
                        if(~isa(w,'mvnDist')),error('w must be an mvnDist object for this method');end
                    end
            
        end

        function p = logprob(obj, X, y)
        % p(i) = log p(y(i) | X(i,:), obj.w), y(i) in 1...C
            pred = predict(obj,'X',X,'method','plugin');
            P = pred.probs;
            Y = oneOfK(y, obj.nclasses);
            p =  sum(sum(Y.*log(P)));
        end

    end


    methods(Access = 'protected')

        function obj = fitL1(obj,X,Y1,lambda,method,offsetAdded)
        % Fit using the specified L1 regularizer, lambda via the specified method.
            [n,d] = size(X);                                %#ok
            
            lambdaVec = lambda*ones(d,obj.nclasses-1);
            if(offsetAdded),lambdaVec(:,1) = 0;end
            lambdaVec = lambdaVec(:);
            options.verbose = false;
            optfunc = [];
            switch lower(method)
                case 'iteratedridge'
                    optfunc = @L1GeneralIteratedRige;
                case 'projection'
                    optfunc = @L1GeneralProjection;
                case 'grafting'
                    optfunc = @L1GeneralGrafting;
                case 'orthantwise'
                    optfunc = @L1GeneralOrthantWist;
                case 'pdlb'
                    optfunc = @L1GeneralPrimalDualLogBarrier;
                case 'sequentialqp'
                    optfunc = @L1GeneralSequentialQuadraticProgramming;
                case 'subgradient'
                    optfunc = @L1GeneralSubGradient;
                case 'unconstrainedapx'
                    optfunc = @L1GeneralUnconstrainedApx;
                case 'unconstrainedapxsub'
                   optfunc = @L1GeneralUnconstrainedApx_sub;
                case 'boundoptrelaxed'
                    if(offsetAdded),warning('logregDist:offset','currently penalizes offset weight'),end
                    [obj.w,output] =  compileAndRun('boundOptL1overrelaxed',X, Y1, lambda);
                    output.ftrace = output.ftrace(output.ftrace ~= -1);
                case 'boundoptstepwise'
                    if(offsetAdded),warning('logregDist:offset','currently penalizes offset weight'),end
                    [obj.w, output] = compileAndRun('boundOptL1Stepwise',X, Y1, lambda);
                    output.ftrace = output.ftrace(output.ftrace ~= -1);    
                otherwise
                    optfunc = @L1GeneralProjection;
            end
            if(~isempty(optfunc))
                obj.w = optfunc(@multinomLogregNLLGradHessL2,zeros(d*(obj.nclasses-1),1),lambdaVec,options,X,Y1,0,false);
            end
        end

        function [obj,output] = fitL2(obj,X,Y1,lambda,method,offsetAdded)
        % Fit using the specified L1 regularizer, lambda via the specified method.
           [n,d] = size(X);                                                         %#ok
            switch lower(method)
                case 'boundoptrelaxed'
                    if(offsetAdded),warning('logregDist:offset','currently penalizes offset weight'),end
                    [obj.w, output] = compileAndRun('boundOptL2overrelaxed',X, Y1, lambda);
                    output.ftrace = output.ftrace(output.ftrace ~= -1);
                case 'boundoptstepwise'
                    if(offsetAdded),warning('logregDist:offset','currently penalizes offset weight'),end
                    [obj.w, output] = compileAndRun('boundOptL2Stepwise',X, Y1, lambda);
                    output.ftrace = output.ftrace(output.ftrace ~= -1);
                otherwise
                    if(strcmpi(method,'default'))
                        method = 'lbfgs';
                    end
                    options.Method = method;
                    options.Display = 0;
                    winit = zeros(d*(obj.nclasses-1),1);
                    [obj.w, f, exitflag, output] = minFunc(@multinomLogregNLLGradHessL2, winit, options, X, Y1, lambda,offsetAdded); %#ok
            end
            try
                wMAP = obj.w;
                [nll, g, H] = multinomLogregNLLGradHessL2(wMAP, X, Y1, lambda,offsetAdded); %#ok  H = hessian of neg log lik    
                C = inv(H);
                obj.posteriorW = mvnDist(wMAP, C); %C  = inv Hessian(neg log lik)
            catch
                warning('logregDist:Laplace','obj.posteriorW not set: could not invert the Hessian of the log-posterior.');
            end
        end

    end

%%

    %% Demos
    methods(Static = true)

        function test()
        % check functions are syntactically correct
            n = 10; d = 3; C = 2;
            X = randn(n,d );
            y = sampleDiscrete((1/C)*ones(1,C), n, 1);
            mL2 = logregDist('nclasses', C);
            mL2 = fit(mL2, 'X', X, 'y', y);
            predMAPL2 = predict(mL2, 'X',X);                                                %#ok
            [predMCL2,samplesL2]  = predict(mL2,'X',X,'method','mc','nsamples',2000);       %#ok
            predExactL2 = predict(mL2,'X',X,'method','integral');                           %#ok
            llL2 = logprob(mL2, X, y);                                                      %#ok
            %%
            mL1 = logregDist('nclasses',C);
            mL1 = fit(mL1,'X',X,'y',y,'prior','L1','lambda',0.1);
            pred = predict(mL1,'X',X);                                                      %#ok
        end %!

%-------------------------------------------------------------------------------
%-------------------------------------------------------------------------------
        
        function demoCrabs()
        % Here we fit an L2 regularized logistic regression model to the crabs 
        % data set and predict using three methods: MAP plugin approx, Monte
        % Carlo approx, and using a closed form approximation to the posterior
        % predictive. 
            [Xtrain, ytrain, Xtest, ytest] = makeCrabs;
            sigma2 = 32/5;
            T = chainTransformer({standardizeTransformer(false), kernelTransformer('rbf', sigma2)});
            m = logregDist('nclasses',2, 'transformer', T);
            lambda = 1e-3;
            m = fit(m, 'X', Xtrain, 'y', ytrain, 'lambda', lambda,'prior','l2');
            Pmap   = predict(m,'X',Xtest,'method','plugin');
            Pmc    = predict(m,'X',Xtest,'method','mc');
            Pexact = predict(m,'X',Xtest,'method','integral');
            nerrsMAP   = sum(mode(Pmap)' ~= ytest)                                      %#ok
            nerrsMC    = sum(mode(Pmc)' ~= ytest)                                       %#ok
            nerrsExact = sum(mode(Pexact)' ~= ytest)                                    %#ok
        end %!

%-------------------------------------------------------------------------------
%-------------------------------------------------------------------------------        

        function demoOptimizer()
            setSeed(1);
            load soy; % n=307, d = 35, C = 3;
            %load car; % n=1728, d = 6, C = 3;
            methods = {'bb',  'cg', 'lbfgs', 'newton'};
            lambda = 1e-3;
            figure; hold on;
            
            [styles, colors, symbols] =  plotColors;                                    %#ok
            
            for mi=1:length(methods)
                tic
                [m, output{mi}] = fit(logregDist, 'X', X, 'y', Y, ...                   
                    'lambda', lambda, 'method', methods{mi});                           %#ok
                T = toc                                                                 %#ok
                time(mi) = T;                                                           %#ok
                w{mi} = m.w;                                                            %#ok
                niter = length(output{mi}.ftrace)                                       %#ok
                h(mi) = plot(linspace(0, T, niter), output{mi}.ftrace, styles{mi});     %#ok
                legendstr{mi}  = sprintf('%s', methods{mi});                            %#ok
            end
            legend(legendstr)
        end %!

%-------------------------------------------------------------------------------
%-------------------------------------------------------------------------------

        function demoVisualizePredictive()
        %% Logistic Regression: Visualizing the Predictive Distribution
        % Here we fit a logistic regression model to synthetic data and visualize the
        % predictive distribution. We use an L2 regularizer and perform an RBF expansion
        % of the data.
        %% Load and Plot the Data
        % Our synthetic data consists of 300 2D examples from two different classes, 1 and 2.
        load synthetic2Ddata
        figure;
        plot(X(Y==1,1),X(Y==1,2),'.r','MarkerSize',20); hold on;
        plot(X(Y==2,1),X(Y==2,2),'.b','MarkerSize',20);
        set(gca,'XTick',0:0.5:1,'YTick',0:0.5:1);
        title('Training Data');
        legend({'Class1','Class2'},'Location','BestOutside');
        %% Create the Data Transformer
        % We will make use of PMTK's transformer objects to easily preprocess the data
        % and perform the basis expansion. We chain three transformers together, which
        % will be applied to the data in sequence. When we pass our chainTransformer to
        % our model, (which we will create shortly), all of the details of the
        % transformation are retained, and where appropriate, applied to future test data.
        %
        sigma2 = 1;          % kernel bandwidth
        T = chainTransformer({standardizeTransformer(false)      ,...
        kernelTransformer('rbf',sigma2)} );
        %% Create the Model
        % We now create a new logistic regression model and pass it the transformer object
        % we just created.
        model = logregDist('nclasses',2, 'transformer', T);
        %% Fit the Model
        % To fit the model, we simply call the model's fit method and pass in the data.
        % Here we use an L2 regularizer, however, an L1 sparsity promoting regularizer
        % could have been used just as easily by replacing the string 'l2' with 'l1'.
        lambda = 1e-3;                                              % L2 regularizer
        model = fit(model,'prior','l2','lambda',lambda,'X',X,'y',Y);
        %%
        % We can specify which optimization method we would like to use by passing in
        % its name to the fit method as in the following. There are number of options
        % but reasonable defaults exist.
        %%
        %  model = fit(model,'prior','l2','lambda',lambda,'X',X,'y',Y,'method','lbfgs');
        %% Predict
        % To visualize the predictive distribution we will first create grid of points
        % in our original 2D feature space and evaluate the posterior probability that
        % each point belongs to class 1.
        %
        [X1grid, X2grid] = meshgrid(0:0.01:1,0:0.01:1);
        [nrows,ncols] = size(X1grid);
        testData = [X1grid(:),X2grid(:)];
        %%
        % The output of the predict method is a discrete distribution over the class
        % labels. We extract the probabilities of each test point belonging to class 1
        % and reshape the vector for plotting purposes.
        pred = predict(model,'X',testData);              % pred is an object - a discrete distribution
        pclass1 = pred.probs(:,1);
        probGrid = reshape(pclass1,nrows,ncols);
        %% Plot the Predictive Distribution
        % We can now make use of Matlab's excellent plotting capabilities and plot the
        % surface of the distribution.
        figure;
        surf(X1grid,X2grid,probGrid);
        shading interp; view([0 90]); colorbar;
        set(gca,'XTick',0:0.5:1,'YTick',0:0.5:1);
        title('Predictive Distribution');
        end%!
        
%-------------------------------------------------------------------------------
%-------------------------------------------------------------------------------
        
        function demoSat()
        %% Binary Classification of SAT Data via Logistic Regression
        % In this example, we classify whether or not a student will pass a
        % course based on their SAT score, using logistic regression. 
        %% Load Data
        setSeed(0);
        stat = load('satData.txt'); 
        %%
        % The data is from Johnson and Albert p77 table 3.1
        %%
        % Columns of stat:
        %%
        % # pass [0 | 1]
        % # all ones
        % # all ones
        % # SAT score
        % # prerequisite grade where A=5,B=4,C=3,D=2,F=1
        %%
        % The data is in {0,1} 0 for fail, 1 for pass. We will convert to {1,2}
        y = stat(:,1);                      % class labels
        X = stat(:,4);                      % SAT scores
        [X,perm] = sort(X,'ascend');        % sort for plotting purposes
        y = y(perm) + 1;                    % logregDist requires labels in {1:C}
        %% Fit via MLE
        T = chainTransformer({standardizeTransformer(false),addOnesTransformer});
        m = logregDist('nclasses',2,'transformer', T);
        m = fit(m, 'X', X, 'y', y);         % MLE performed if no prior specified
        %% Classify Training Examples
        pred = predict(m,'X', X);           % predict on the training examples using MLE
        yhat = mode(pred) -1;               % most probable class labels (converted back to {0,1})                  
        yprob = pred.probs(:,2);            % probability of passing given SAT score and fitted weights
        %% Plot MLE
        figure; hold on
        plot(X, y-1 , 'ko', 'linewidth', 3, 'markersize', 12);    % y-1 to convert from {1,2} -> {0,1}
        plot(X, yhat, 'b.',                 'markersize', 18);
        plot(X, yprob,'xr', 'linewidth', 3, 'markersize', 12);
        set(gca, 'ylim'         , [-0.2 1.6]                ,...
                 'YTick'        , [0,0.5,1]                 ,...
                 'YTickLabel'   , {'Fail  0','','Pass  1'}  ,...
                 'FontSize'     , 12                        ,...
                 'YGrid'        , 'on'                      ,...
                 'box'          , 'on');
        xlabel('SAT Score')
        legend({'Actual','Predicted','p( passing | SAT Score , w )'},'Location','NorthWest');
        title('MLE');
        %%  Fit Using Laplace Approximation to the Posterior
        % Here we fit in much the same way but specify an L2 prior. The laplace 
        % approximation to the posterior, an mvnDist object, is automatically 
        % assigned to the posteriorW property of our logregDist object. 
        T = chainTransformer({standardizeTransformer(false),addOnesTransformer});
        mBayes = logregDist('nclasses',2,'transformer',T);
        mBayes = fit(mBayes,'X',X,'y',y,'prior','l2','lambda',1e-3); 
        %% Plot Posterior of w
        figure; hold on
        subplot2(2,2,1,1); plot(marginal(mBayes.posteriorW,1),'plotArgs', {'linewidth',2}); title('w0')
        subplot2(2,2,1,2); plot(mBayes.posteriorW); xlabel('w0'); ylabel('w1');
        subplot2(2,2,2,2); plot(marginal(mBayes.posteriorW,2),'plotArgs', {'linewidth',2}); title('w1')
        %% Predict using Monte Carlo sampling of the Posterior Predictive
        % When performing Monte Carlo sampling, the samples are automatically
        % averaged and used to create the discreteDist object storing
        % distributions over class labels for every example. However, the
        % original samples are also returned in a 3D matrix such that
        % samples(i,c,s) is the probability that example X(i,:) is in class c
        % according to sample s. 
        [pred,samples] = predict(mBayes,'X',X,'method','mc','nsamples',100);  
        %%
        % We will create a sampling distribution object by passing in the
        % samples corresponing to the probability of passing. The squeeze
        % function simply takes a matrix of size n-by-1-s and removes the
        % superfluous middle dimension. Finally, samples are stored row-wise
        % and so we transpose. 
        ps = sampleDist(squeeze(samples(:,2,:))');
        %% Plot Credible Intervals
        % Here we obtain error bars on our predictions by looking at the
        % credible intervals. 
        figure; hold on
        plot(X, y-1, 'ko', 'linewidth', 3, 'markersize', 12);
        for i=1:length(y)
            psi = marginal(ps, i);
            [Q5, Q95] = credibleInterval(psi);
            line([X(i) X(i)], [Q5 Q95], 'linewidth', 3);
            plot(X(i), median(psi), 'rx', 'linewidth', 3, 'markersize', 12);
        end
        set(gca, 'ylim'         , [-0.1 1.6]                                    ,...
                 'YTick'        , 0:0.25:1                                      ,...
                 'YTickLabel'   , {'(Fail)  0','0.25','0.5','0.75','(Pass)  1'} ,...
                 'FontSize'     , 12                                            ,...
                 'YGrid'        , 'on'                                          ,...
                 'box'          , 'on');
        xlabel('SAT Score')
        legend({'Actual','95% credible interval','p( passing | SAT Score , w )'},'Location','NorthWest');
        title('Bayes');  
        %% Plot Posterior Predictive Samples  
        figure; hold on
        plot(X, y-1, 'ko', 'linewidth', 3, 'markersize', 12);
        for s=1:30
            psi = ps.samples(s,:);
            plot(X, psi, 'r-');
        end
        axis tight
        set(gca, 'ylim'         , [-0.1 1.2]                                    ,...
                  'YTick'       , 0:0.25:1                                      ,...
                  'YTickLabel'  , {'(Fail)  0','0.25','0.5','0.75','(Pass)  1'} ,...
                  'FontSize'    , 12                                            ,...
                  'YGrid'       , 'on'                                          ,...
                  'box'         , 'on');
        xlabel('SAT Score');
        title('Posterior Predictive Samples');              
        end%!
        
%-------------------------------------------------------------------------------
%-------------------------------------------------------------------------------
        
        function demoLaplaceGirolami()
        % Based on code written by Mark Girolami
        setSeed(0);
        % We generate data from two Gaussians:
        % x|C=1 ~ gauss([1,5], I)
        % x|C=0 ~ gauss([-5,1], 1.1I)
        N=30;
        D=2;
        mu1=[ones(N,1) 5*ones(N,1)];
        mu2=[-5*ones(N,1) 1*ones(N,1)];
        class1_std = 1;
        class2_std = 1.1;
        X = [class1_std*randn(N,2)+mu1;2*class2_std*randn(N,2)+mu2];
        y = [ones(N,1);zeros(N,1)];
        alpha=100; %Variance of prior (alpha=1/lambda)

        %Limits and grid size for contour plotting
        Range=8;
        Step=0.1;
        [w1,w2]=meshgrid(-Range:Step:Range,-Range:Step:Range);
        [n,n]=size(w1);                                                      %#ok
        W=[reshape(w1,n*n,1) reshape(w2,n*n,1)];
 
        Range=12;
        Step=0.1;
        [x1,x2]=meshgrid(-Range:Step:Range,-Range:Step:Range);
        [nx,nx]=size(x1);
        grid=[reshape(x1,nx*nx,1) reshape(x2,nx*nx,1)];

        % Plot data and plug-in predictive
        figure;
        m = fit(logregDist, 'X', X, 'y', y+1);
        pred = predict(m,'X',grid);
        plotPredictive(pred.probs(:,2));
        
        title('p(y=1|x, wMLE)')

        % Plot prior and posterior
        eta=W*X';
        Log_Prior = log(mvnpdf(W, zeros(1,D), eye(D).*alpha));
        Log_Like = eta*y - sum(log(1+exp(eta)),2);
        Log_Joint = Log_Like + Log_Prior;
        figure;
        J=2;K=2;
        subplot(J,K,1)
        contour(w1,w2,reshape(-Log_Prior,[n,n]),30);
        title('Log-Prior');
        subplot(J,K,2)
        contour(w1,w2,reshape(-Log_Like,[n,n]),30);
        title('Log-Likelihood');
        subplot(J,K,3)
        contour(w1,w2,reshape(-Log_Joint,[n,n]),30);
        title('Log-Unnormalised Posterior')
        hold

        %Identify the parameters w1 & w2 which maximise the posterior (joint)
        [i,j]=max(Log_Joint);                                                                %#ok
        plot(W(j,1),W(j,2),'.','MarkerSize',40);
        %Compute the Laplace Approximation
        tic
        m  = fit(logregDist,'X',X,'y',y+1,'prior','l2','lambda',1/alpha);
        toc
        wMAP = m.posteriorW.mu;
        C = m.posteriorW.Sigma;
        %[wMAP, C] = logregFitIRLS(t, X, 1/alpha);
        Log_Laplace_Posterior = log(mvnpdf(W, wMAP', C)+eps);
        subplot(J,K,4);
        contour(w1,w2,reshape(-Log_Laplace_Posterior,[n,n]),30);
        hold
        plot(W(j,1),W(j,2),'.','MarkerSize',40);
        title('Laplace Approximation to Posterior')
        % Posterior predictive
        % wMAP
        figure;
        subplot(2,2,1)
        pred = predict(m,'X',grid,'method','plugin');
        plotPredictive(pred.probs(:,2));
        title('p(y=1|x, wMAP)')
        subplot(2,2,2); hold on
        S = 100;
        plot(X((y==1),1),X((y==1),2),'r.');                                 
        plot(X((y==0),1),X((y==0),2),'bo');
        [predDist,samples] = predict(m,'X',grid,'method','mc','nsamples',S);
        pred = sampleDist(squeeze(samples(:,2,:))');
        %pred = postPredict(m, grid, 'method', 'MC', 'nsamples', S);
        for s=1:min(S,20)
            p = pred.samples(s,:);
            contour(x1,x2,reshape(p,[nx,nx]),[0.5 0.5]);
        end
        set(gca, 'xlim', [-10 10]);
        set(gca, 'ylim', [-10 10]);
        title('decision boundary for sampled w')
        subplot(2,2,3)
        plotPredictive(mean(pred));
        title('MC approx of p(y=1|x)')
        subplot(2,2,4)
        pred = predict(m,'X',grid,'method','integral');
        plotPredictive(pred.probs(:,2));
        title('numerical approx of p(y=1|x)')
            % subfunction
            function plotPredictive(pred)
                contour(x1,x2,reshape(pred,[nx,nx]),30);
                hold on
                plot(X((y==1),1),X((y==1),2),'r.');
                plot(X((y==0),1),X((y==0),2),'bo');
            end
        end

%-------------------------------------------------------------------------------
%-------------------------------------------------------------------------------

        function demoOptimizer2()
            % slow
            %logregDist.helperOptimizer('documents');
            %logregDist.helperOptimizer('soy');
        end

        function helperOptimizer(dataset)
            setSeed(1);
            switch dataset
                case 'documents'
                    load docdata; % n=900, d=600, C=2in training set
                    y = ytrain; 
                    X = xtrain;
                    methods = {'bb',  'cg', 'lbfgs', 'newton'};
                case 'soy'
                    load soy; % n=307, d = 35, C = 3;
                    y = Y; % turn into a binary classification problem by combining classes 1,2
                    y(Y==1) = 2;
                    y(Y==2) = 2;
                    y(Y==3) = 1;
                    methods = {'bb',  'cg', 'lbfgs', 'newton',  'boundoptRelaxed'};
            end
            lambda = 1e-3;
            figure; hold on;
            [styles, colors, symbols] =  plotColors;                                     %#ok
            for mi=1:length(methods)
                tic
                [m, output{mi}] = fit(logregDist, 'X', X, 'y', y, 'lambda', lambda, 'method', methods{mi});   %#ok
                T = toc                                                                                        %#ok
                time(mi) = T;                                                                                   %#ok
                w{mi} = m.w;                                                                                    %#ok
                niter = length(output{mi}.ftrace)                                                                %#ok
                h(mi) = plot(linspace(0, T, niter), output{mi}.ftrace, styles{mi});                                %#ok
                legendstr{mi}  = sprintf('%s', methods{mi});                                                        %#ok
            end
            legend(legendstr)
        end





    end



end