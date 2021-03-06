% BDWF  Cady's line integral method scalar Fresnel diffraction of 0-1 occulter
%
% E = bdwf(xVals, yVals, zVals, Z, lambda, dxO, nO, psi1, psi2, deltaX, deltaY)
%
%  implements Cady's 2012 method for scalar Fresnel diffraction from an occulter
%  defined by a set of boundary quadrature points (locus).  The acronym BDWF is
%  "boundary diffraction wave fast".  It evaluates U in eqn (4) in Cady's paper,
%  with A=1, on a square grid of targets (eta,xi), but the notation is
%  apparently different, since an arbitrary incident wave spherical direction,
%  not included in (4), is also allowed.
%  In the case psi1=0 (on-axis), it thus evaluates
%
%      u(xi,eta) = exp(2.pi.z/lambda) [  1 - (i.lambdaz)^{-1} int_Omega
%                      exp { i.pi.lambdaz [(x-xi)^2+(y-eta)^2] }  dxdy  ]
%
%  This is evaluated for each point (xi,eta) in target grid described
%  below. The convergence (based on test_bdwf below) appears to be 1st order,
%  ie O(1/n), w.r.t. n the number of nodes, even for a smooth boundary.
%
%  Reference: Cady, E. "Boundary diffraction wave integrals for diffraction
%   modeling of external occulters", Opt. Expr. 20(14) 15196--15208 (2012).
%
% Inputs:
%   xVals, yVals - vectors of ordered boundary point x,y (in-plane) coords,
%                  with the last point *repeating* the first, in meters.
%                  Ie, if an n-point quadrature is used, these are length n+1.
%   zVals - z coords (along viewing axis), in meters, length n+1.
%           If empty, 0 is used.
%   Z - downstream propagation distance, in meters
%   lambda - set of wavelengths (vector length nLambda), in meters
%   dxO - target grid spacing in both eta and xi directions, in meters
%   nO - target grid size in both directions
%   psi1 - off-axis angle of source wave (relative to z axis), radians
%   psi2 - polar angle of source wave (measured around the z axis), radians
%   deltaX, deltaY - target grid translation in eta, xi, in meters.
%
% Outputs:
%   E   -  nO*nO*nLambda 3D array of complex amplitudes at the square
%          detector grid, for each target (eta, xi), and wavelength lambda.
%          This grid in the (eta,xi) detector plane is the product of the
%          1D grids:  xi = -deltaX + ((-nO+1)/2 : (nO-1)/2) * dxO and
%                    eta = -deltaY + ((-nO+1)/2 : (nO-1)/2) * dxO
%
% Notes:
%  1) Translation of the occulter (xVals,yVals) by (xi0,eta0) is
%   equivalent to translation (-deltaX,-deltaY) of the detector grid by
%   (-xi0,-eta0), which is also equivalent, up to accuracy O(psi1^2), to
%   changing the incident direction from on-axis (psi1=0) to:
%      psi1 = sqrt(xi0^2+eta0^2) / Z
%      psi2 = atan2(eta0,xi0)
% 2) The xVals, yVals (and zVals if relevant) lists *must repeat* the first
%   point as the last; this is just how their input format is.
% 3) For a smooth domain, 2nd-order accuracy in n, the number of boundary
%   points, is expected. This is due to use of the midpoint as opposed to
%   trapezoid rule. (In contrast, see NSLI.)
%
% For testing, see test_bdwf.m
%
% See also: bdry_pts, nsli_pts, make_grid_bdwf.
%
% Documentation by Alex H. Barnett, 9/2/20, since none found.

% Below code and header have not been altered by AHB, apart from debug comments:



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SISTER: Starshade Imaging Simulation Toolkit for Exoplanet Reconnaissance
%
% Copyright (c) <2019>, California Institute of Technology ("Caltech"). U.S. Government sponsorship acknowledged.
% All rights reserved.
%
% Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
%
% • Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
%
% • Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
%
% • Neither the name of Caltech nor its operating division, the Jet Propulsion Laboratory, nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Boundary diffraction wave, fast
% Eric J. Cady (eric.j.cady@jpl.nasa.gov), Caltech/JPL   1/24/12
%  8/2/13: Switched to use outPoly on the clip tests in place of
%   xVals/yVals
%
% Following Miyamoto and Wolf (I and II) 1962
% Version #4: takes edges in directly, can do off-axis and out-of-plane,
% can do lateral errors, can do multiple wavelengths at once, very fast if
% you're not overlapping the geometric outline of the occulter.
%
% Note: Still assumes an underlying grid.

function E = bdwf(xVals, yVals, zVals, Z, lambda, dxO, nO, psi1, psi2, deltaX, deltaY)

% AHB debug: was the only way to figure what's being sent into this code...
%disp('in bdwf. whos:')
%whos
%figure; plot(xVals,yVals,'.'); axis equal tight; title('input locus to bdwf'); drawnow;
%Z
%deltaX,deltaY
%dxO
%lambda
%nO
%psi1
%psi2

% Set up output grid
Nx = nO;
Ny = nO;

width = nO*dxO;
xO = -width/2+dxO/2:dxO:width/2-dxO/2;
yO = xO - deltaY;
xO = xO - deltaX;

% Prep flags
if isempty(zVals) || isequal(zVals, zeros(size(zVals)))
    flagZ = false;
else
    flagZ = true;
end

if psi1 ~= 0
    flagP1 = true;
else
    flagP1 = false;
end

inOccFlag = 0;
outPoly = [xVals(:), yVals(:)]; %polyclip(xVals, yVals, min(xO)-dxO/2, max(xO)+dxO/2, min(yO)-dxO/2, max(yO)+dxO/2, 0);
% outPoly = polyclip(xVals, yVals, min(xO)-dxO/2, max(xO)+dxO/2, min(yO)-dxO/2, max(yO)+dxO/2, 0);
% if isequal(size(outPoly),[5,2]) && max(outPoly(:,1)) == max(xO)+dxO/2 && min(outPoly(:,1)) == min(xO)-dxO/2 ...
%         && max(outPoly(:,2)) == max(yO)+dxO/2 && min(outPoly(:,2)) == min(yO)-dxO/2
%     inOccFlag = 1;
% else
%     inOccFlag = 0;
% end

% Assign variables prior to loop
p2l = 2*pi./lambda;
pil = pi./lambda;
pilz = pi./(lambda*Z);
nLambda = length(lambda);
E = zeros(Nx, Ny, nLambda);
wind = zeros(Nx, Ny);
vt = outPoly;

s1 = sin(psi1);
c1 = cos(psi1);
s2 = sin(psi2);
c2 = cos(psi2);

% Use midpoints for integral, endpoints to get vector ell for the dot
% product and dl.
xm = (xVals(2:end) + xVals(1:end-1))/2;
ym = (yVals(2:end) + yVals(1:end-1))/2;

xl = xVals(2:end) - xVals(1:end-1);
yl = yVals(2:end) - yVals(1:end-1);

% Do edge integral
if flagZ
    % Out-of-plane errors present
    zm = (zVals(2:end) + zVals(1:end-1))/2;
    zl = zVals(2:end) - zVals(1:end-1);
    
    if flagP1
        % Off-axis source present, as well as out-of-plane errors
        tilt = zeros(nO, nO);
        
        for jj = 1:Nx
            for kk = 1:Ny
                
                dx = (xm - xO(jj));
                dy = (ym - yO(kk));
                dz = (zm - Z);
                
                f = -s1*dz + c1*c2*dx + c1*s2*dy;
                g =        -    s2*dx +    c2*dy;
                h = -c1*dz - s1*c2*dx - s1*s2*dy;
                
                fSquarePlusGSquare = f.*f + g.*g;
                sHatCrossPDotLdl = xl.*(f*s2 + g*c1*c2) + yl.*(-f*c2 + g*c1*s2) + zl.*(-g*s1);
                
                for qq = 1:nLambda
                    E(jj, kk, qq) = sum(exp(1i*pil(qq)*(fSquarePlusGSquare./h))./(fSquarePlusGSquare).*sHatCrossPDotLdl);
                end
                
                wind(jj, kk) = polywindFlag(vt, [(xO(jj) - Z*s1*c2) (yO(kk) - Z*s1*s2)], inOccFlag);
                tilt(jj, kk) = xO(jj)*c2 + yO(kk)*s2;
            end
        end
        
        for qq = 1:nLambda
            eikz = exp(1i*p2l(qq)*Z*c1)*exp(1i*p2l(qq)*s1*tilt);
            E(:,:,qq) = eikz./(2*pi).*E(:,:,qq);
            E(:,:,qq) = eikz.*(wind == 0) - E(:,:,qq);
        end
    else
        % Out-of-plane but on-axis
        for jj = 1:Nx
            for kk = 1:Ny
                h = (Z - zm);
                
                fSquarePlusGSquare = (xm - xO(jj)).^2 + (ym - yO(kk)).^2;
                sHatCrossPDotLdl = xl.*(ym - yO(kk)) - yl.*(xm - xO(jj));
                for qq = 1:nLambda
                    E(jj, kk, qq) = sum(exp(1i*pil(qq)*(fSquarePlusGSquare./h))./(fSquarePlusGSquare).*sHatCrossPDotLdl);
                end
                
                wind(jj, kk) = polywindFlag(vt, [xO(jj) yO(kk)], inOccFlag);
            end
        end
        
        for qq = 1:nLambda
            eikz = exp(1i*p2l(qq)*Z);
            E(:,:,qq) = eikz./(2*pi).*E(:,:,qq);
            E(:,:,qq) = eikz.*(wind == 0) - E(:,:,qq);
        end
    end
    
else
    % Entirely in-plane
    if flagP1
tic
% SRH
%Nx_0 = Nx ;
%Ny_0 = Ny ;
%Nx = 32 ;
%Ny = 32 ;
%sprintf( 'Nx, Ny=%i,%i changed to %i,%i', Nx_0, Ny_0, Nx, Ny )

        % Off-axis source present but in-plane
        tilt = zeros(nO, nO);
        
        for jj = 1:Nx
        % SRH: some timing when the computation is long
        t_jj = tic ;
            for kk = 1:Ny
                dx = (xm - xO(jj));
                dy = (ym - yO(kk));
% 6% running time for f, g and h                
                f = s1*Z + c1*c2*dx + c1*s2*dy;
                g =      -    s2*dx +    c2*dy;
                h = c1*Z - s1*c2*dx - s1*s2*dy;
                
% 3% running time spent here:
                fSquarePlusGSquare = f.*f + g.*g;
%                sHatCrossPDotLdl = xl.*(s2*s1*Z + c1*dy) + yl.*(-c2*s1*Z - c1*dx);
% SRH
% 7% running time spent with tmp_1 and tmp_2
                tmp_1 = fSquarePlusGSquare./h ;
                tmp_2 = ( xl.*(s2*s1*Z + c1*dy) + yl.*(-c2*s1*Z - c1*dx) ) ./ fSquarePlusGSquare ;
                for qq = 1:nLambda
%                     E(jj, kk, qq) = sum(exp(1i*pil(qq)*(fSquarePlusGSquare./h))./(fSquarePlusGSquare).*sHatCrossPDotLdl);
% SRH
% 32% of the running time spent here
                    E(jj, kk, qq) = sum(exp(1i*pil(qq)*tmp_1).*tmp_2) ; 
                end
% 48% running time spent here                
                wind(jj, kk) = polywindFlag(vt, [(xO(jj) - Z*s1*c2) (yO(kk) - Z*s1*s2)], inOccFlag);
% Negligible time spent here
                tilt(jj, kk) = xO(jj)*c2 + yO(kk)*s2;
            end
        % SRH: print out a message if it is going to be a long calculation
        t_jj = toc( t_jj ) ;
          if ( t_jj > 120 / Nx ) && ( jj == 1 )
          clck = clock ;
          tm_s_nw = clck( 4 ) * 3600 + clck( 5 ) * 60 + clck( 6 ) ;
          tm_s_end = tm_s_nw + t_jj * Nx ;
          hr_end = floor( tm_s_end / 3600 ) ;
          min_end = ceil( ( tm_s_end - 3600 * hr_end ) / 60 ) ;
          disp( sprintf( 'The single, multi-wavelength, PSF construction should finish at %02i:%02i', hr_end, min_end ) )
          end
        end
%toc        
%  Negligible time spent here
        for qq = 1:nLambda
            eikz = exp(1i*p2l(qq)*Z*c1)*exp(1i*p2l(qq)*s1*tilt);
            E(:,:,qq) = eikz./(2*pi).*E(:,:,qq);
            E(:,:,qq) = eikz.*(wind == 0) - E(:,:,qq);
        end
    else
        % On-axis source & flat occulter
% SRH:
tic
%Nx_0 = Nx ;
%Ny_0 = Ny ;
%Nx = 4 ; 
%Ny = 4 ;
%sprintf( 'Nx, Ny=%i,%i changed to %i,%i', Nx_0, Ny_0, Nx, Ny ) 
        for jj = 1:Nx
        % SRH: some timing when the computation is long
        t_jj = tic ;
            for kk = 1:Ny
                fSquarePlusGSquare = (xm - xO(jj)).^2 + (ym - yO(kk)).^2;
                sHatCrossPDotLdl = xl.*(ym - yO(kk)) - yl.*(xm - xO(jj));
% SRH
                tmp = sHatCrossPDotLdl ./ fSquarePlusGSquare ;                
%if ( jj == 1 ) && ( kk == 1 )
%disp( sprintf( 'xm(1),ym(1)=%3.6f,%3.6f', xm( 1 ), ym( 1 ) ) )
%disp( sprintf( 'X0,y0=%3.6f,%3.6f', xO(jj),yO(kk) ) )
%disp( sprintf( 'tmp=%3.6f', tmp(1) ) )
%end
                for qq = 1:nLambda
% SRH
                    E(jj,kk,qq) = sum(exp(1i*fSquarePlusGSquare*pilz(qq)).*tmp);
%                    E(jj,kk,qq) = sum(exp(1i*pilz(qq)*(fSquarePlusGSquare))./(fSquarePlusGSquare).*sHatCrossPDotLdl);
%                    D(jj,kk,qq) = E2(jj,kk,qq) - E(jj,kk,qq) ;
                end
                
                wind(jj, kk) = polywindFlag(vt, [xO(jj) yO(kk)], inOccFlag);
            end
        % SRH: print out a message if it is going to be a long calculation
        t_jj = toc( t_jj ) ;
          if ( t_jj > 120 / Nx ) && ( jj == 1 )
          clck = clock ;
          tm_s_nw = clck( 4 ) * 3600 + clck( 5 ) * 60 + clck( 6 ) ;
          tm_s_end = tm_s_nw + t_jj * Nx ;
          hr_end = floor( tm_s_end / 3600 ) ;
          min_end = floor( ( tm_s_end - 3600 * hr_end ) / 60 ) ;
          disp( sprintf( 'The single, multi-wavelength, PSF construction should finish at %02i:%02i', hr_end, min_end ) )
          end
        end
%toc
%make_a_stop
        
        for qq = 1:nLambda
            eikz = exp(1i*p2l(qq)*Z);
            E(:,:,qq) = eikz./(2*pi).*E(:,:,qq);
            E(:,:,qq) = eikz.*(wind == 0) - E(:,:,qq);
%if ( qq == 1 )
%disp( sprintf( 'E(1,1,1)=%3.6e', E( 1, 1, qq ) ) )
%end
        end
    end
end
%make_a_stop
