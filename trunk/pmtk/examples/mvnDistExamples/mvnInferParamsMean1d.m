%% MVN Infer Mean 1D
priorVars = [1 5];
for i=1:numel(priorVars)
    priorVar = priorVars(i);
    prior = MvnDist(0, priorVar);
    sigma2 = 1;
    m = MvnDist(prior, sigma2);
    x = 3;
    m = fit(m, 'data', x);
    post = m.params.mu;
    % The likelihood is proportional to the posterior when we use a flat prior
    priorBroad = MvnDist(0, 1e10);
    m2 = MvnDist(priorBroad, sigma2);
    m2 = fit(m2, 'data', x);
    lik = m2.params.mu;
    % Now plot
    figure;
    xrange = [-5 5];
    hold on
    plot(prior, 'xrange', xrange, 'plotArgs', { 'r-', 'linewidth', 2});
    legendstr{1} = 'prior';
    plot(lik, 'xrange', xrange,'plotArgs', {'k:o', 'linewidth', 2});
    legendstr{2} = 'lik';
    plot(post, 'xrange', xrange,'plotArgs', {'b-.', 'linewidth', 2});
    legendstr{3} = 'post';
    legend(legendstr,'Location','NorthWest')
    title(sprintf('prior variance = %3.2f', priorVar))
end
