function [out, weights] = initBaek2017Algorithm2LowMemory(...
    image_sampling, align, dispersion_matrix, sensitivity, lambda, weights, options...
)
% INITBAEK2017ALGORITHM2LOWMEMORY  Allocate memory for 'baek2017Algorithm2LowMemory()'
%
% ## Syntax
% [out, weights] = initBaek2017Algorithm2LowMemory(...
%   image_sampling, align, dispersion_matrix, sensitivity, lambda, weights, options...
% )
%
% ## Description
% [out, weights] = initBaek2017Algorithm2LowMemory(...
%   image_sampling, align, dispersion_matrix, sensitivity, lambda, weights, options...
% )
%   Returns a structure containing arrays to be used by
%   'baek2017Algorithm2LowMemory()', as well as normalized regularization
%   weights for 'baek2017Algorithm2LowMemory()'.
%
% ## Input Arguments
%
% image_sampling -- Image dimensions
%   A two-element vector containing the height and width, respectively, of
%   the latent image `I`, and of the captured input image, `J`, to which
%   `I` corresponds.
%
% align -- Bayer pattern description
%   A four-character character vector, specifying the Bayer tile pattern of
%   the input image `J`. For example, 'gbrg'. `align` has the same form
%   as the `sensorAlignment` input argument of `demosaic()`.
%
% dispersion_matrix -- Model of dispersion
%   `dispersion_matrix` can be empty (`[]`), if there is no model of
%   dispersion. Otherwise, `dispersion_matrix` must be a matrix for warping
%   `I`, the latent image, to `J`, which is affected by dispersion. The
%   k-th row of `dispersion_matrix` contains the weights of pixels in `I`
%   used to re-estimate the k-th pixel in `J`.
%
% sensitivity -- Spectral band conversion matrix
%   A 2D array, where `sensitivity(i, j)` is the sensitivity of the i-th
%   colour channel of the input image `J` to the j-th input colour channel
%   or spectral band of `I`. `sensitivity` is a matrix mapping colours in
%   `I` to colours in `J`.
%
% lambda -- Wavelength bands
%   A vector containing the wavelengths or colour channel indices
%   corresponding to the spectral bands or colour channels of `I`.
%
% weights -- Regularization weights
%   `weights(1)` is the 'alpha' weight on the regularization of the spatial
%   gradient of the image in Equation 6 of Baek et al. 2017. `weights(2)`
%   is the 'beta' weight on the regularization of the spectral gradient of
%   the spatial gradient of the image in Equation 6 of Baek et al. 2017.
%   `weights(3)` is the weight on a second-order gradient prior designed to
%   penalize colour-filter array artifacts.
%
%   If all elements of `weights` are zero, and `options.nonneg` is `false`,
%   this function will throw an error, in contrast to
%   'baek2017Algorithm2()', as this case is expected to be handled by the
%   caller.
%
% options -- Options and small parameters
%   A structure with the following fields:
%   - 'rho': A three or four-element vector containing penalty parameters
%     used in the ADMM framework. The first three elements correspond to
%     the regularization terms. The fourth element is a penalty parameter
%     for a non-negativity constraint on the solution, and is only required
%     if the 'nonneg' field is `true`.
%   - 'full_GLambda': A Boolean value used as the `replicate` input
%     argument of 'spectralGradient()' when creating the spectral gradient
%     matrix for regularizing the spectral dimension of the latent image.
%     Refer to the documentation of 'spectralGradient.m' for details.
%     'full_GLambda' is not used if spectral regularization is disabled
%     (when `weights(2) == 0` is `true`).
%   - 'int_method': The numerical integration method used for spectral to
%     colour space conversion. `int_method` is passed to
%     'channelConversionMatrix()' as its `int_method` argument. Refer to
%     the documentation of 'channelConversionMatrix.m' for details. If
%     'int_method' is 'none', numerical integration will not be performed.
%     'int_method' should be 'none' when `I` contains colour channels as
%     opposed to spectral bands.
%   - 'norms': A three-element logical vector, corresponding to the
%     regularization terms. Each element specifies whether to use the L1
%     norm (`true`) or an L2 norm (`false`) of the corresponding
%     regularization penalty vector. If some elements of 'norms' are
%     `false`, the ADMM iterations are simplified by eliminating slack
%     variables. If all elements are `false`, and 'nonneg' is `false`, then
%     ADMM reduces to a least-squares solution.
%   - 'nonneg': A Boolean scalar specifying whether or not to enable a
%     non-negativity constraint on the estimated image. If `true`, 'rho'
%     must have four elements.
%
% ## Output Arguments
%
% out -- Preallocated arrays and intermediate data
%   The `in` input/output argument of 'baek2017Algorithm2LowMemory()'.
%   Refer to the documentation of baek2017Algorithm2LowMemory.m.
%
% weights -- Normalized regularization weights
%   A version of the `weights` input argument where each regularization
%   weight has been normalized by the length of the vector whose norm is
%   the regularization term to which it corresponds.
%
% See also baek2017Algorithm2LowMemory, baek2017Algorithm2, mosaicMatrix,
% antiMosaicMatrix, channelConversionMatrix, spatialGradient,
% spectralGradient,

% Bernard Llanos
% Supervised by Dr. Y.H. Yang
% University of Alberta, Department of Computing Science
% File created October 9, 2018

nargoutchk(2, 2);
narginchk(7, 7);

n_priors = 3;
nonneg_ind = 4;
enabled_weights = (weights ~= 0);

if length(weights) ~= n_priors
    error('Expected `weights` to have length %d for the %d prior terms.', n_priors, n_priors);
end
if any(weights < 0)
    error('All elements of `weights` must be non-negative numbers.');
end

nonneg = options.nonneg;
if all(~enabled_weights) && ~nonneg
    error('At least one element of `weights` must be positive, or `options.nonneg` must be `true`.');
end

norms = options.norms;
if length(norms) ~= n_priors
    error('Expected `options.norms` to have length %d for the %d prior terms.', n_priors, n_priors);
end

% Don't use ADMM to optimize priors given zero weight
norms(enabled_weights) = false;

rho = options.rho;
if nonneg && length(rho) < nonneg_ind
    error('A %d-th penalty parameter must be provided in `rho` when `options.nonneg` is `true`.', nonneg_ind);
elseif length(rho) < n_priors
    error('Expected `rho` to have length at least %d for the %d prior terms.', n_priors, n_priors);
end
if any(rho <= 0)
    error('The penalty parameters, `rho`, must be positive numbers.');
end

int_method = options.int_method;
if isStringScalar(int_method) || ischar(int_method)
    do_integration = ~strcmp(int_method, 'none');
else
    error('`options.int_method` must be a character vector or a string scalar.');
end

n_bands = length(lambda);
n_elements_I = prod(image_sampling) * n_bands;
if do_integration
    Omega_Phi = channelConversionMatrix(image_sampling, sensitivity, lambda, int_method);
else
    Omega_Phi = channelConversionMatrix(image_sampling, sensitivity);
end
if ~isempty(dispersion_matrix)
    if isfloat(dispersion_matrix) && ismatrix(dispersion_matrix)
        if size(dispersion, 1) ~= n_elements_I
            error('`dispersion_matrix` must have as many rows as there are pixels in `J` times bands.');
        elseif size(dispersion, 2) ~= n_elements_I
            error('`dispersion_matrix` must have as many columns as there are values in `I`.');
        end
    else
        error('`dispersion_matrix` must be a floating-point matrix.');
    end
    Omega_Phi = Omega_Phi * dispersion_matrix;
end

out.G = cell(n_priors, 1);
if enabled_weights(1) || enabled_weights(2)
    out.G{1} = spatialGradient([image_sampling, n_bands]);
end
if enabled_weights(2)
    G_lambda = spectralGradient([image_sampling, n_bands], options.full_GLambda);
    G_lambda_sz1 = size(G_lambda, 1);
    G_lambda_sz2 = size(G_lambda, 2);
    % The product `G_lambda * out.G{1}` must be defined, so `G_lambda` needs to be
    % replicated to operate on both the x and y-gradients.
    out.G{2} = [
        G_lambda, sparse(G_lambda_sz1, G_lambda_sz2);
        sparse(G_lambda_sz1, G_lambda_sz2), G_lambda
        ] * out.G{1};
end
if enabled_weights(3)
    out.G{3} = antiMosaicMatrix(image_sampling, align) * out.M_Omega_Phi;
end

out.M_Omega_Phi = mosaicMatrix(image_sampling, align) * Omega_Phi;

% Adjust the weights so that they have the same relative importance
% regardless of the differences in the lengths of the vectors whose norms
% are being weighted.
for w = 1:n_priors
    if enabled_weights(w)
        weights(w) = weights(w) * size(out.M_Omega_Phi, 1) / size(out.G{w}, 1);
    end
end

out.J = zeros(size(out.M_Omega_Phi, 1), 1);

out.M_Omega_Phi_J = zeros(n_elements_I, 1);
out.G_T = cell(n_priors, 1);
out.G_2 = cell(n_priors, 1);
for w = 1:n_priors
    if enabled_weights(w)
        out.G_T{w} = out.G{w}.';
        out.G_2{w} = (out.G{w}.' * out.G{w});
    end
end

out.A_const = (out.M_Omega_Phi.' * out.M_Omega_Phi);
for w = 1:n_priors
    if enabled_weights(w) && ~norms(w)
        out.A_const = out.A_const + weights(w) * out.G_2{w};
    end
end

if nonneg
    out.I_A = speye(size(out.A_const));
end

out.A = sparse(size(out.A));
out.b = zeros(n_elements_I, 1);

out.I = zeros(n_elements_I, 1);

active_constraints = [norms, options.nonneg];
n_Z = find(active_constraints, 1, 'last');

% Initialization
out.Z = cell(n_Z, 1);
out.U = cell(n_Z, 1);
out.g = cell(n_Z, 1);
out.Z_prev = cell(n_Z, 1);
out.R = cell(n_Z, 1);
out.Y = cell(n_Z, 1);

for z_ind = 1:n_Z
    if active_constraints(z_ind)
        len_Z = size(out.G{z_ind}, 1);
        out.Z{z_ind} = zeros(len_Z, 1);
        out.U{z_ind} = zeros(len_Z, 1);
        out.g{z_ind} = zeros(len_Z, 1);
        out.Z_prev{z_ind} = zeros(len_Z, 1);
        out.R{z_ind} = zeros(len_Z, 1);
        out.Y{z_ind} = zeros(len_Z, 1);
    end
end

end