seed = 0; randn('state', seed);
n = 5;
X=[randn(n,2)+2.*ones(n,2);2.*randn(n,2)-2.*ones(n,2)];

[n d] = size(X);
[W, Z, evals, Xrecon, mu] = pcaPmtk(X, 1);

figure(1);clf;
plot(mu(1), mu(2), '*', 'markersize', 15, 'color', 'r');
hold on
plot(X(:,1), X(:,2), 'ro');
plot(Xrecon(:,1), Xrecon(:,2), 'g+', 'markersize', 12, 'linewidth',2);
for i=1:n
  h=line([Xrecon(i,1) X(i,1)], [Xrecon(i,2) X(i,2)], 'color', 'b');
end
% plot the linear subspace
Z2 = [-5;5]; % 2 ``extreme'' points in latent space
Xrecon2 = Z2*W' + repmat(mu, 2,1);
h=line([Xrecon2(1,1) Xrecon2(2,1)], [Xrecon2(1,2) Xrecon2(2,2)], 'color', 'm');
axis equal

if doPrintPmtk, printPmtkFigures('pcaDemo2'); end;