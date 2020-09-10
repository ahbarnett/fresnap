% Demo of FRESNAP computing Fresnel diffraction from various starshades.
% Barnett 9/8/20
clear; verb = 1;  % verbosity

tol = 1e-9;       % desired accuracy
lambdaz = 9.0;    % wavelength*dist, in m^2, recall Fres # = Reff^2/(lambda.z)

design = 'erf';   % choose design from below list...
switch design 
 case 'disc'
  Np = 1; r0=5; r1=10; Afunc = @(r) 1+0*r; % 10m radius disc: Poisson spot u=1!
  n = 600; m = 80;                  % Afunc=1, r0, dummy hacks. Good to lz>=5 
 case 'lin'
  Np = 24; r0=5; r1=13; Afunc = @(r) (r1-r)/(r1-r0);   % simple linear apod.
  n = 600; m = 80;        % good to lambdaz>=9; convergence must be tested
 case 'HG'
  A = @(t) exp(-(t/0.6).^6);        % Cash'11 hyper-Gaussian on [0,1]
  Np = 16; r0 = 7; r1 = 14;         % # petals, inner, outer radii in meters
  Afunc = @(r) A((r-r0)/(r1-r0));   % apodization vs radius in meters
  n = 30; m = 80;
 case 'erf'                         % my analytic toy model, similar r0,r1
  Np=16; r0 = 7; r1 = 14;           % # petals, inner, outer radii in meters
  beta = 3.0;                       % good for A or 1-A to decay to 1e-5
  Afunc = @(r) erfc(beta*(2*r-(r0+r1))/(r1-r0))/2;
  %e=1e-3; Afunc = @(r) e + (1-e)*Afunc(r); % fatten the tips: get u(0,0)~e
  e=1e-2; Afunc = @(r) e*(r1-r)/(r1-r0) + (1-e)*Afunc(r);  % sharp linear tips
  %e=1e-3; Afunc = @(r) (1-e)*Afunc(r); % fatten the gaps: get u(0,0)~e
  n = 30; m = 100;       % good to lambdaz>=9; convergence must be tested
 case 'NI2'                         % actual NI2 starshade, cubic interpolated
  cwd = fileparts(mfilename('fullpath')); file = [cwd '/occulter/NI2'];
  Np = 24;                          % petals told cut off harshly at r1 ...bad
  [~,r0,r1] = eval_sister_apod(file,0);   % get apodization range [r0,r1]
  Afunc = @(r) eval_sister_apod(file,r);  % func handle (reads file when called)
  % try destroying the 1e-2 Poisson spot due to both petal flat ends...
  %Afunc = @(r) Afunc(r).*((r<=12) + (r>12).*cos(pi/2*(r-12)).^2); % C^1 blend
  %Afunc = @(r) 1 - (1-Afunc(r)).*((r>=6) + (r<6).*cos(pi/2*(6-r)).^2);  % "
  n = 40; m = 400;    % use quad_conv_apod_NI2 converged m (to 1e-6), lz>=5
 case 'NW2'                         % actual NI2 starshade, cubic interpolated
  file = '/home/alex/physics/starshade/SISTER/input_scenes/locus/in/NW2';
  Np = 24;                          % petals told cut off harshly at r1 ...bad
  [~,r0,r1] = eval_sister_apod(file,0);   % get apodization range [r0,r1]
  Afunc = @(r) eval_sister_apod(file,r);  % func handle (reads file when called)
  % try destroying the 1e-2 Poisson spot due to both petal flat ends...
  %Afunc = @(r) Afunc(r).*((r<=12) + (r>12).*cos(pi/2*(r-12)).^2); % C^1 blend
  %Afunc = @(r) 1 - (1-Afunc(r)).*((r>=6) + (r<6).*cos(pi/2*(6-r)).^2);  % "
  n = 50; m = 700;    % use quad_conv_apod_NI2 converged m (to 1e-6), lz>=5
  lambdaz = 20;       % bigger since Reff~27 bigger.
end
fprintf('apod: 1-A(%.5g)=%.3g, A(%.5g)=%.3g\n',r0,1-Afunc(r0),r1,Afunc(r1))


[xq yq wq bx by] = starshadequad(Np,Afunc,r0,r1,n,m,verb);   % fill areal quadr

if verb>1, figure(1); clf; scatter(xq,yq,10,wq); axis equal tight; colorbar;
  hold on; plot([bx;bx(1)], [by;by(1)], 'k-'); title('starshade quadr');
  xi = -5; eta = -10;     % see Fresnel integrand resolved for a target...
  int = exp((1i*pi/lambdaz)*((xq-xi).^2+(yq-eta).^2));  % integrand w/o prefac
  figure(2); clf; scatter(xq,yq,10,real(int)); axis equal tight; colorbar;
  hold on; plot([bx;bx(1)], [by;by(1)], 'k-'); title('Fresnel integrand');
  drawnow
end

ximax = 15.0; ngrid = 1e3;     % ngrid^2 centered target grid out to +-ximax
[u xigrid] = fresnap_grid(xq, yq, wq, lambdaz, ximax, ngrid, tol, verb);
it = 1; jt = 1;  % grid indices to test, eg (1,1) is SW corner of grid
ut = u(it,jt); xi = xigrid(it); eta = xigrid(jt);     % math check u
fprintf('u(%.3g,%.3g) = %.12g + %.12gi\n',xi,eta,real(ut),imag(ut))
%return                     % useful for convergence testing

figure(3); clf;
u = 1-u;               % convert aperture to occulter
imagesc(xigrid,xigrid,log10(abs(u)'.^2));  % note transpose: x is fast, y slow.
colorbar; caxis([-11 0.2]); hold on; axis xy equal tight;
plot([bx;bx(1)], [by;by(1)], 'k+-','markersize',1);
xlabel('\xi'); ylabel('\eta'); title('log_{10} |u|^2, occulter, grid');
if strcmp(design,'NI2'), show_bdry_occulter('NI2'); end    % check geom good
it = ceil(ngrid/2+1); jt = it;      % indices of center xi=eta=0
fprintf('intensity at (0,0) is %.3g\n',abs(u(it,jt)).^2)
