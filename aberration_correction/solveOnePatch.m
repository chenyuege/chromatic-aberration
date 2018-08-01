% A helper function for 'solvePatches()'
%
% Originally, 'solveOnePatch()' was a nested function, but was moved to a
% separate function because it could not be called from within a `parfor`
% loop.
%
% See also solvePatches

% Bernard Llanos
% Supervised by Dr. Y.H. Yang
% University of Alberta, Department of Computing Science
% File created July 17, 2018

function [I, image_sampling_J_f, dispersion_matrix_patch, varargout] = solveOnePatch(...
        image_sampling, J, align, dispersion_matrix, sensitivity,...
        lambda, patch_size, padding, f, f_args, corner...
)

% Find the linear indices of pixels in the output patch
patch_lim_I = [
    corner(1) - padding, corner(2) - padding;
    corner(1) + patch_size(1) + padding - 1, corner(2) + patch_size(2) + padding - 1
    ];
trim = [padding + 1, padding + 1];
if patch_lim_I(1, 1) < 1
    trim(1, 1) = trim(1, 1) + patch_lim_I(1, 1) - 1;
    patch_lim_I(1, 1) = 1;
end
if patch_lim_I(1, 2) < 1
    trim(1, 2) = trim(1, 2) + patch_lim_I(1, 2) - 1;
    patch_lim_I(1, 2) = 1;
end
trim = [trim; trim + patch_size - 1];
if patch_lim_I(2, 1) > image_sampling(1)
    trim(2, 1) = trim(2, 1) + min(0, image_sampling(1) - patch_lim_I(2, 1) + padding);
    patch_lim_I(2, 1) = image_sampling(1);
end
if patch_lim_I(2, 2) > image_sampling(2)
    trim(2, 2) = trim(2, 2) + min(0, image_sampling(2) - patch_lim_I(2, 2) + padding);
    patch_lim_I(2, 2) = image_sampling(2);
end
[patch_subscripts_col_I, patch_subscripts_row_I] = meshgrid(...
    patch_lim_I(1, 2):patch_lim_I(2, 2),...
    patch_lim_I(1, 1):patch_lim_I(2, 1)...
    );
patch_subscripts_row_I = reshape(patch_subscripts_row_I, [], 1);
patch_subscripts_col_I = reshape(patch_subscripts_col_I, [], 1);
patch_ind_I_spatial = sub2ind(...
    image_sampling, patch_subscripts_row_I, patch_subscripts_col_I...
);
n_bands = length(lambda);
patch_ind_I_spatial_rep = repmat(patch_ind_I_spatial, n_bands, 1);
patch_subscripts_lambda_I = repelem((1:n_bands).', length(patch_ind_I_spatial), 1);
patch_ind_I_spectral = patch_ind_I_spatial_rep +...
    ((patch_subscripts_lambda_I - 1) * prod(image_sampling));

% Find the pixels mapped to in the input image
has_dispersion = ~isempty(dispersion_matrix);
if has_dispersion
    all_mappings_J = logical(dispersion_matrix(:, patch_ind_I_spectral));
    patch_ind_I_replicates = sum(all_mappings_J, 1);
    patch_ind_I_spectral = repelem(patch_ind_I_spectral, patch_ind_I_replicates);
    patch_ind_I_warped = mod(find(all_mappings_J) - 1, size(dispersion_matrix, 1));
    patch_ind_J = mod(patch_ind_I_warped, numel(J)) + 1;
    patch_ind_I_warped = patch_ind_I_warped + 1;
else
    patch_ind_I_replicates = ones(1, length(patch_ind_I_spectral));
    patch_ind_I_warped = patch_ind_I_spectral;
    patch_ind_J = patch_ind_I_spatial_rep;
end

% Find a bounding box of those pixels: The input patch
image_sampling_J_local = size(J);
[patch_subscripts_row_J, patch_subscripts_col_J] = ind2sub(...
    image_sampling_J_local, patch_ind_J...
);
patch_lim_J = [
    min(patch_subscripts_row_J), min(patch_subscripts_col_J);
    max(patch_subscripts_row_J), max(patch_subscripts_col_J)
];

% Construct a direct map between indices in the two patches
image_sampling_I_f = [diff(patch_lim_I, 1, 1) + 1, n_bands];
patch_ind_I_f = sub2ind(...
    image_sampling_I_f,...
    repelem(repmat(patch_subscripts_row_I, n_bands, 1), patch_ind_I_replicates) - patch_lim_I(1, 1) + 1,...
    repelem(repmat(patch_subscripts_col_I, n_bands, 1), patch_ind_I_replicates) - patch_lim_I(1, 2) + 1,...
    repelem(patch_subscripts_lambda_I, patch_ind_I_replicates)...
);
image_sampling_J_f = diff(patch_lim_J, 1, 1) + 1;
patch_ind_J_f = sub2ind(...
    image_sampling_J_f,...
    patch_subscripts_row_J - patch_lim_J(1, 1) + 1,...
    patch_subscripts_col_J - patch_lim_J(1, 2) + 1 ...
);
[...
    patch_subscripts_row_I_warped,...
    patch_subscripts_col_I_warped,...
    patch_subscripts_lambda_I_warped...
] = ind2sub([image_sampling_J_local, n_bands], patch_ind_I_warped);
image_sampling_I_warped_f = [image_sampling_J_f, n_bands];
patch_ind_I_warped_f = sub2ind(...
    image_sampling_I_warped_f,...
    patch_subscripts_row_I_warped - patch_lim_J(1, 1) + 1,...
    patch_subscripts_col_I_warped - patch_lim_J(1, 2) + 1,...
    patch_subscripts_lambda_I_warped...
);

% Construct arguments for the image estimation algorithm
align_f = offsetBayerPattern(patch_lim_J(1, :), align);
if has_dispersion
    dispersion_f = sparse(...
        patch_ind_I_warped_f, patch_ind_I_f,...
        dispersion_matrix(...
            sub2ind(size(dispersion_matrix), patch_ind_I_warped, patch_ind_I_spectral)...
        ),...
        prod(image_sampling_I_warped_f), prod(image_sampling_I_f)...
    );
else
    dispersion_f = [];
end
J_f = zeros(image_sampling_J_f);
J_f(patch_ind_J_f) = J(patch_ind_J);

% Solve for the output patch
varargout = cell(nargout - 3, 1);
[I_f, varargout{:}] = f(...
    image_sampling_I_f(1:2), align_f, dispersion_f, sensitivity, lambda,...
    J_f, f_args{:}...
);

% Remove padding
padding_filter = false(image_sampling_I_f);
padding_filter((trim(1, 1)):(trim(2, 1)), (trim(1, 2)):(trim(2, 2)), :) = true;
padding_filter = reshape(padding_filter, [], 1, 1);
I = I_f(padding_filter);
I = reshape(I, [diff(trim, 1, 1) + 1, n_bands]);
if has_dispersion
    dispersion_matrix_patch = dispersion_f(:, padding_filter);
else
    dispersion_matrix_patch = [];
end
end