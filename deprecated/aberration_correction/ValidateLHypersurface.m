%% Demosaicing and hyperspectral ADMM-based correction of chromatic aberration
% Test the L-hypersurface method of Belge et al. 2002 for selecting
% regularization weights
%
% ## Usage
% Modify the parameters, the first code section below, then run.
%
% ## Input
%
% ### Input images
%
% #### RAW image
% A RAW image to be demosaiced and corrected for chromatic aberration.
%
% The image is expected to have been preprocessed, such as using
% 'AverageRAWImages.m', so that it does not need to be linearized after
% being loaded.  For image format files, the image will simply be loaded
% with the Image Processing Toolbox 'imread()' function. For '.mat' files,
% the variable to be loaded must be provided in the script parameters.
%
% The image is expected to have 3 colour channels (Red, Green, Blue)
% (represented in a Bayer pattern as a 2D array). However, the colour
% channels can correspond to narrowband wavelength ranges - This script
% will input a mapping from the colour space of the latent image to the
% colour space of the RAW image.
%
% #### True image
% A spectral or colour image serving as the ground truth for image
% estimation. The true image is needed to compare the weights selected
% using the L-hypersurface with the weights giving the lowest error
% relative to the true image.
%
% The true image must be associated with a '.mat' file containing a vector
% with the variable 'bands'. 'bands' must have the same length as the third
% dimension of the true image, and must contain the colour channel indices
% or wavelengths corresponding to the true image. 'bands' is used to
% evaluate the dispersion model. Note that 'bands' takes precedence over
% the variable of the same name defined in 'SetFixedParameters.m'.
%
% ### Model of dispersion
%
% A '.mat' file containing several variables, which is the output of
% 'RAWDiskDispersion.m', 'DoubleConvexThickLensDispersion.m' or
% 'BimaterialImages.m', for example. The following variables are required:
% - 'dispersion_data': A model of chromatic aberration, modeling the warping
%   from the reference colour channel or wavelength band to the other
%   colour channels or wavelength bands. `dispersion_data` can be converted to
%   a function form using `dispersionfun = makeDispersionfun(dispersion_data)`.
% - 'model_from_reference': A parameter of the above scripts, which
%   determines the frame of reference for the model of chromatic
%   aberration. It must be set to `false`.
%
% The following two additional variables are optional. If they are present,
% they will be used for the following purposes:
% - Conversion between the coordinate system in which the model of chromatic
%   aberration was constructed and the image coordinate system.
% - Limiting the correction of chromatic aberration to the region in which
%   the model is valid.
% The first variable, 'model_space' is a structure with same form as the
% `model_space` input argument of 'modelSpaceTransform()'. The second
% variable, `fill`, can be omitted, in which case it defaults to `false`.
% `fill` corresponds to the `fill` input argument of
% 'modelSpaceTransform()'. Refer to the documentation of
% 'modelSpaceTransform.m' for details.
%
% ### Colour space conversion data
% A '.mat' file containing several variables, which is the output of
% 'SonyColorMap.m', for example. The following variables are required:
% - 'sensor_map': A 2D array, where `sensor_map(i, j)` is the sensitivity
%   of the i-th colour channel or spectral band in the input images to the
%   j-th colour channel or spectral band of the latent images. For example,
%   `sensor_map` is a matrix mapping discretized spectral power
%   distributions to RGB colours.
% - 'channel_mode': A Boolean value indicating whether the latent colour
%   space is a set of colour channels (true) or a set of spectral bands
%   (false).
% - 'bands': A vector containing the wavelengths or colour channel indices
%   corresponding to the second dimension of 'sensor_map'. 'bands' is
%   required to resample 'sensor_map' so that it maps from the colour space
%   of the latent image to the colour space of the input RAW image.
%
% ## Output
%
% ### Graphical output
%
% Figures are opened showing the search path taken by the fixed-point
% iterative method of Belge et al. 2002 for selecting regularization
% weights. The search path can be shown on plots of the L-hypersurface, and
% of the true error hypersurface, depending on the amount of graphical
% output requested. (Sampling these surfaces is computationally-expensive.)
% After sampling the L-hypersurface, further figures give insight into the
% convergence properties of the fixed-point iterative method. Lastly,
% additional figures show the location of the image patch used for
% selecting the regularization weights, and compare the true and estimated
% patches.
%
% Graphical output relating to the fixed-point iterative method will not be
% produced if there are more than three regularization weights to be
% chosen.
%
% ### Estimated images
%
% One of each of the following types of images is created, depending on the
% type of latent image (spectral or colour). The images are produced under
% the regularization weights chosen by the method of Belge et al. 2002. The
% filename of the input image, concatenated with a string of parameter
% information, is represented by '*' below.
% - '*_roi.tif' and '*_roi.mat': A cropped version of the input image
%   (stored in the variable 'I_raw'), containing the portion used as input
%   for ADMM. This region of interest was determined using the
%   `model_space` and `fill` variables saved in the input model of
%   dispersion data file (see above). If these variables were not present,
%   the cropped region is the entire input image. All of the other output
%   images listed below are limited to the region shown in '*_roi.tif'.
% - '*_latent.tif' and '*_latent.mat': The latent image estimated using
%   ADMM (stored in the variable 'I_latent'). The '.tif' image is only
%   output if the latent image is a greyscale or 3-channel image.
% - '*_warped.tif' and '*_warped.mat': A version of the latent image
%   (stored in the variable 'I_warped') created by warping the latent image
%   according to the dispersion model. The '.tif' image is only output if
%   if the latent image is a greyscale or 3-channel image.
% - '*_rgb.tif' and '*_rgb.mat': A colour image (stored in the variable
%   'I_rgb') created by converting the latent image to the RGB colour space
%   of the camera.
% - '*_rgb_warped.tif' and '*_rgb_warped.mat': A colour image (stored in
%   the variable 'J_full') created by warping the latent image according to
%   the dispersion model, then converting the image to the RGB colour space
%   of the camera. This output image is, in a sense, a demosaiced version
%   of the input image.
% - '*_reestimated.tif' and '*_reestimated.mat': A simulation (stored in
%   the variable 'J_est') of the input RAW image from the latent image,
%   useful for visually evaluating the convergence of the ADMM algorithm.
%
% ### Data file output
%
% A '.mat' file containing the following variables:
%
% - 'bands': The value of the 'bands' variable loaded with the true latent
%   image.
% - 'bands_color': The 'bands' variable loaded from the colour space
%   conversion data file, for reference.
% - 'image_bounds': The coordinates of the latent image in the space of the
%   cropped input image. This is the 'image_bounds' output argument of
%   'dispersionfunToMatrix()'.
% - 'input_image_filename': The input image filename found using the
%   wildcard provided in the parameters section of the script.
% - 'true_image_filename': The true latent image filename found using the
%   wildcard provided in the parameters section of the script.
% - 'sensor_map_resampled': The resampled version of the 'sensor_map'
%   variable, generated for compatibility with the true latent image.
% 
% Additionally, the file contains the values of all parameters in the first
% section of the script below, for reference. (Specifically, those listed
% in `parameters_list`, which should be updated if the set of parameters is
% changed.)
%
% ## Notes
% - The method of Belge et al. 2002 is derived for an unconstrained
%   optimization problem, and so may not work for non-negativity
%   constrained optimization.
% - The image colour space is not altered by this script; RGB images are
%   produced in the camera's colour space. See 'imreadRAW()' for code to
%   convert an image to sRGB after demosaicing.
% - This script does not distinguish between wavelength bands and colour
%   channels. One can use this script to estimate either a latent
%   hyperspectral image, or a latent aberration-free RGB image (free from
%   lateral chromatic aberration). The latter use case is a baseline that
%   can be compared with the results of 'CorrectByWarping.m'. A latent
%   hyperspectral image can be sharper, in theory, whereas a latent RGB
%   image will retain the within-channel chromatic aberration of the input
%   image. The reason for this difference is the summation of multiple
%   spectral bands into each channel of an RGB image, in contrast to the
%   identity mapping of the colours of a latent RGB image into the colours
%   of the aberrated RGB image. Summation allows multiple sharp bands to
%   form a blurred colour channel.
% - This script uses the first row of `weights` defined in
%   'SetFixedParameters.m' to initialize the fixed-point algorithm for
%   selecting regularization weights based on the image content
%   (implemented in 'selectWeights()'). Elements of `weights(1, :)` can be
%   set to zero to disable the corresponding regularization terms. Note
%   that the number of nonzero elements of `weights(1, :)` determines the
%   dimensionality of the visualizations output by this script.
% - This script could estimate downsampled images (configured by adjusting
%   `downsampling_factor` in 'SetFixedParameters.m'), if it were to use
%   'solvePatches()' instead of 'solvePatchesAligned()' for patch-based
%   image estimation. In that case, however, this script could not process
%   very large images, except at higher downsampling factors.
%   'solvePatchesAligned()' can process large images, but cannot downsample
%   images.
% - This script only uses the first row of `patch_sizes`, and the first
%   element of `paddings`, both defined in 'SetFixedParameters.m'.
%
% ## References
% - Baek, S.-H., Kim, I., Gutierrez, D., & Kim, M. H. (2017). "Compact
%   single-shot hyperspectral imaging using a prism." ACM Transactions
%   on Graphics (Proc. SIGGRAPH Asia 2017), 36(6), 217:1–12.
%   doi:10.1145/3130800.3130896
% - Boyd, S, et al.. "Distributed Optimization and Statistical Learning via
%   the Alternating Direction Method of Multipliers." Foundations and
%   Trends in Machine Learning, vol. 3, no. 1, pp. 1-122, 2011.
%   doi:10.1561/2200000016
% - Belge, M, Kilmer, M. E., & Miller, E. L.. "Efficient determination of
%   multiple regularization parameters in a generalized L-curve
%   framework." Inverse Problems, vol. 18, pp. 1161-1183, 2002.
%   doi:10.1088/0266-5611/18/4/314

% Bernard Llanos
% Supervised by Dr. Y.H. Yang
% University of Alberta, Department of Computing Science
% File created August 24, 2018

% List of parameters to save with results
parameters_list = {
    'true_image_bands_filename',...
    'reverse_dispersion_model_filename',...
    'color_map_filename',...
    'output_directory',...
    'target_patch',...
    'n_samples'...
};

%% Input data and parameters

% Wildcard for 'ls()' to find the image to process.
% '.mat' or image files can be loaded
input_image_wildcard = '/home/llanos/GoogleDrive/ThesisResearch/Results/20180828_Kodak_TestingLHypersurface/kodim19raw.mat';
input_image_variable_name = 'I_raw'; % Used only when loading '.mat' files

% Wildcard for 'ls()' to find the true image.
% '.mat' or image files can be loaded
true_image_wildcard = '/home/llanos/GoogleDrive/ThesisResearch/Data/20180726_Demosaicking_Kodak/PNG_Richard W Franzen/kodim19.png';
true_image_variable_name = 'I_hyper'; % Used only when loading '.mat' files

% Data file containing the colour channels or wavelengths associated with
% the true image
true_image_bands_filename = '/home/llanos/GoogleDrive/ThesisResearch/Results/20180828_Kodak_TestingLHypersurface/RGBColorMapData.mat';

% Model of dispersion
% Can be empty
reverse_dispersion_model_filename = [];

% Colour space conversion data
color_map_filename = '/home/llanos/GoogleDrive/ThesisResearch/Results/20180828_Kodak_TestingLHypersurface/RGBColorMapData.mat';

% Output directory for all images and saved parameters
output_directory = '/home/llanos/Downloads';

% ## Options for the L-hypersurface method of Belge et al. 2002

% The top-left corner (row, column) of the image patch to use for
% regularization weights selection. If empty (`[]`), the patch will be
% selected by the user.
target_patch = []; %[478, 328];

% ## Parameters controlling graphical output

plot_image_patch = true;
plot_search_path = true;
plot_hypersurfaces = true;

% Number of values of each regularization weight to sample when
% constructing the L-hypersurface
% This can be a scalar, or a vector with a length equal to the number of
% weights (not only the number of active weights)
n_samples = 100;

% Parameters which do not usually need to be changed
run('SetFixedParameters.m')

%% Load the images

enabled_weights = selectWeightsOptions.enabled_weights;
n_weights = length(enabled_weights);
if ~isscalar(n_samples) && isvector(n_samples) && length(n_samples) ~= n_weights
    error('If `n_samples is a vector, it must have as many elements as there are weights, %d.', n_weights);
end

input_image_filename = listFiles(input_image_wildcard);
[I_raw, name] = loadImage(input_image_filename{1}, input_image_variable_name);

if ~ismatrix(I_raw)
    error('Expected a RAW image, represented as a 2D array, not a higher-dimensional array.');
end

true_image_filename = listFiles(true_image_wildcard);
I_gt = loadImage(true_image_filename{1}, true_image_variable_name);

bands = [];
bands_variable_name = 'bands';
load(true_image_bands_filename, bands_variable_name);
if isempty(bands)
    error('No wavelength band or colour channel information is associated with the true image.')
end
bands_gt = bands;

%% Load calibration data

has_dispersion = ~isempty(reverse_dispersion_model_filename);
if has_dispersion
    [...
        dispersion_data, ~, transform_data...
    ] = loadDispersionModel(reverse_dispersion_model_filename, false, false);
end

bands = [];
model_variables_required = { 'sensor_map', 'channel_mode' };
load(color_map_filename, model_variables_required{:}, bands_variable_name);
if ~all(ismember(model_variables_required, who))
    error('One or more of the required colour space conversion variables is not loaded.')
end
if isempty(bands)
    error('No (non-empty) variable `bands` loaded from colour space conversion data.');
end

bands_color = bands;
bands = bands_gt;

if channel_mode
    baek2017Algorithm2Options.int_method = 'none';
    solvePatchesOptions.int_method = 'none';
    selectWeightsOptions.int_method = 'none';
    imageFormationOptions.int_method = 'none';
else
    baek2017Algorithm2Options.int_method = int_method;
    solvePatchesOptions.int_method = int_method;
    selectWeightsOptions.int_method = int_method;
    imageFormationOptions.int_method = int_method;
end

imageFormationOptions.patch_size = [100, 100];
imageFormationOptions.padding = 10;

%% Preprocess input data

n_bands = length(bands);
% Resample colour space conversion data if necessary
if n_bands ~= length(bands_color) || any(bands ~= bands_color)
    [sensor_map_resampled, bands] = resampleArrays(...
        bands_color, sensor_map.', bands,...
        bands_interp_method...
        );
    if n_bands ~= length(bands)
        error('The colour space conversion data does not cover a sufficiently large range of wavelengths.');
    end
    sensor_map_resampled = sensor_map_resampled.';
else
    sensor_map_resampled = sensor_map;
end

% Crop images to the region of valid dispersion
if has_dispersion
    [dispersionfun, I_raw] = makeDispersionForImage(...
        dispersion_data, I_raw, transform_data...
    );
else
    dispersionfun = [];
end
image_sampling = size(I_raw);

if has_dispersion
    roi = modelSpaceTransform(...
        [size(I_gt, 1), size(I_gt, 2)],...
        transform_data.model_space, transform_data.fill...
    );
    if ~isempty(roi)
        I_gt = I_gt(roi(1):roi(2), roi(3):roi(4), :);
    end
end
if any([size(I_gt, 1), size(I_gt, 2)] ~= image_sampling)
    error([
        'The RAW version of the image has different spatial dimensions fro',...
        'm the true latent image.'...
    ]);
end

%% L-hypersurface method for regularization weight selection

baek2017Algorithm2Options.add_border = false;
baek2017Algorithm2Options.l_surface = true;
patch_size = patch_sizes(1, :);
padding = paddings(1);

% Most of the options to selectWeights() are set in 'SetFixedParameters.m'
selectWeightsOptions.initial_weights = weights(1, :);

[ weights, patch_lim, I_patch, weights_search ] = selectWeights(...
    I_raw, bayer_pattern, dispersionfun, sensor_map_resampled, bands,...
    selectWeightsOptions,...
    @baek2017Algorithm2, {...
        rho, baek2017Algorithm2Options, false...
    }, target_patch, selectWeightsVerbose...
);

%% Visualize the L-hypersurface method

% Display the target patch
if plot_image_patch
    [...
        I_rgb_gt, I_rgb_gt_warped,...
    ] = imageFormation(...
        I_gt, sensor_map_resampled, bands,...
        imageFormationOptions, dispersionfun...
    );
    image_sampling_patch = diff(patch_lim, 1, 1) + 1;
    I_annotated = insertShape(...
        I_rgb_gt_warped, 'Rectangle',...
        [patch_lim(1, 2), patch_lim(1, 1), image_sampling_patch(2), image_sampling_patch(1)],...
        'LineWidth', 2 ...
    );

    figure;
    imshow(I_annotated);
    title('Image patch used for weights estimation');
    
    % Compare the input and output patches
    I_patch_rgb_gt = I_rgb_gt(patch_lim(1, 1):patch_lim(2, 1), patch_lim(1, 2):patch_lim(2, 2), :);
    I_patch_rgb = imageFormation(...
        I_patch, sensor_map_resampled, bands,...
        imageFormationOptions...
    );
    
    figure;
    imshowpair(I_patch_rgb_gt, I_patch_rgb, 'montage');
    title('True image patch vs. estimated image patch');
end


n_active_weights = sum(enabled_weights);
if n_active_weights < 4
    
    to_all_weights = find(enabled_weights);
    n_iter_all = size(weights_search.weights, 1);
    n_iter_outer = weights_search.iter(end);
    iter_diff = find(diff(weights_search.iter));
    outer_it_start = [1; iter_diff + 1];
    outer_it_end = [iter_diff; n_iter_all];
    iteration_colors = jet(n_iter_outer);
    err_filter = [true, enabled_weights];
    
    % Display the search path for the chosen weights
    if plot_search_path
        log_weights = log10(weights_search.weights(:, enabled_weights));
        log_weights_diff = [diff(log_weights, 1, 1); zeros(1, n_active_weights)];
        log_err = log10(weights_search.err(:, err_filter));
        log_err_diff = [diff(log_err, 1, 1); zeros(1, size(log_err, 2))];
        
        figure;
        hold on
        if n_active_weights == 1
            iter_index = 1:n_iter_all;
            for io = 1:n_iter_outer
                plot(...
                    iter_index(outer_it_start(io):outer_it_end(io)),...
                    log_weights(outer_it_start(io):outer_it_end(io)),...
                    'Marker', 'o', 'Color', iteration_colors(io, :)...
                );
            end
            xlabel('Iteration number')
            ylabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
        elseif n_active_weights == 2
            for io = 1:n_iter_outer
                quiver(...
                    log_weights(outer_it_start(io):outer_it_end(io), 1), log_weights(outer_it_start(io):outer_it_end(io), 2),...
                    log_weights_diff(outer_it_start(io):outer_it_end(io), 1), log_weights_diff(outer_it_start(io):outer_it_end(io), 2),...
                    'AutoScale', 'off', 'Color', iteration_colors(io, :)...
                );
            end
            xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
            ylabel(sprintf('log_{10}(weight %d)', to_all_weights(2)))
        elseif n_active_weights == 3
            for io = 1:n_iter_outer
                quiver3(...
                    log_weights(outer_it_start(io):outer_it_end(io), 1), log_weights(outer_it_start(io):outer_it_end(io), 2), log_weights(outer_it_start(io):outer_it_end(io), 3),...
                    log_weights_diff(outer_it_start(io):outer_it_end(io), 1), log_weights_diff(outer_it_start(io):outer_it_end(io), 2), log_weights_diff(outer_it_start(io):outer_it_end(io), 3),...
                    'AutoScale', 'off', 'Color', iteration_colors(io, :)...
                );
            end
            xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
            ylabel(sprintf('log_{10}(weight %d)', to_all_weights(2)))
            zlabel(sprintf('log_{10}(weight %d)', to_all_weights(3)))
        else
            error('Unexpected number of active weights.');
        end
        title('Search path for the selected weights, in weights space')
        hold off
        
        figure;
        hold on
        if n_active_weights == 1
            for io = 1:n_iter_outer
                quiver(...
                    log_err(outer_it_start(io):outer_it_end(io), 2), log_err(outer_it_start(io):outer_it_end(io), 1),...
                    log_err_diff(outer_it_start(io):outer_it_end(io), 2), log_err_diff(outer_it_start(io):outer_it_end(io), 1),...
                    'AutoScale', 'off', 'Color', iteration_colors(io, :)...
                );
            end
            xlabel(sprintf('log_{10}(regularization norm %d)', to_all_weights(1)))
            ylabel('log_{10}(residual)')
        elseif n_active_weights == 2
            for io = 1:n_iter_outer
                quiver3(...
                    log_err(outer_it_start(io):outer_it_end(io), 2), log_err(outer_it_start(io):outer_it_end(io), 3), log_err(outer_it_start(io):outer_it_end(io), 1),...
                    log_err_diff(outer_it_start(io):outer_it_end(io), 2), log_err_diff(outer_it_start(io):outer_it_end(io), 3), log_err_diff(outer_it_start(io):outer_it_end(io), 1),...
                    'AutoScale', 'off', 'Color', iteration_colors(io, :)...
                );
            end
            xlabel(sprintf('log_{10}(regularization norm %d)', to_all_weights(1)))
            ylabel(sprintf('log_{10}(regularization norm %d)', to_all_weights(2)))
            zlabel('log_{10}(residual)')
        elseif n_active_weights == 3
            for io = 1:n_iter_outer
                quiver3(...
                    log_err(outer_it_start(io):outer_it_end(io), 2), log_err(outer_it_start(io):outer_it_end(io), 3), log_err(outer_it_start(io):outer_it_end(io), 4),...
                    log_err_diff(outer_it_start(io):outer_it_end(io), 2), log_err_diff(outer_it_start(io):outer_it_end(io), 3), log_err_diff(outer_it_start(io):outer_it_end(io), 4),...
                    'AutoScale', 'off', 'Color', iteration_colors(io, :)...
                );
            end
            xlabel(sprintf('log_{10}(regularization norm %d)', to_all_weights(1)))
            ylabel(sprintf('log_{10}(regularization norm %d)', to_all_weights(2)))
            zlabel(sprintf('log_{10}(regularization norm %d)', to_all_weights(3)))
        else
            error('Unexpected number of active weights.');
        end
        title('Search path for the selected weights, in error space')
        hold off
    end
    
    % Sample the L-hypersurface and the true error hypersurface
    if plot_hypersurfaces && n_active_weights < 3
        
        % Generate combinations of weights to test
        if isscalar(n_samples)
            n_samples_full = repmat(n_samples, n_active_weights, 1);
        else
            n_samples_full = n_samples(enabled_weights);
        end
        active_weights_samples = cell(n_active_weights, 1);
        for w = 1:n_active_weights
            active_weights_samples{w} = logspace(...
                log10(weights_search.origin_min_weights(to_all_weights(w))),...
                log10(weights_search.origin_max_weights(to_all_weights(w))),...
                n_samples_full(w)...
            ).';
        end
        n_samples_all = prod(n_samples_full);
        all_weights_samples = zeros(n_samples_all, n_weights);
        for w = 1:n_active_weights
            all_weights_samples(:, to_all_weights(w)) = repmat(...
                repelem(active_weights_samples{w}, prod(n_samples_full((w + 1):end))),...
                prod(n_samples_full(1:(w-1))), 1 ...
            );
        end
        log_all_weights_samples = log10(all_weights_samples(:, enabled_weights));
        
        % Construct arguments for the image estimation algorithm
        if isempty(bayer_pattern)
            align_f = [];
        else
            align_f = offsetBayerPattern(patch_lim(1, :), bayer_pattern);
        end
        image_sampling_f = diff(patch_lim, 1, 1) + 1;
        if has_dispersion
            dispersion_f = dispersionfunToMatrix(...
                dispersionfun, bands, image_sampling_f, image_sampling_f,...
                [0, 0, image_sampling_f(2), image_sampling_f(1)], true,...
                [patch_lim(2, 1), patch_lim(1, 1)] - 1 ...
                );
        else
            dispersion_f = [];
        end
        I_raw_f = I_raw(patch_lim(1, 1):patch_lim(2, 1), patch_lim(1, 2):patch_lim(2, 2), :);
        
        % Test the combinations of weights
        all_err_samples = zeros(n_samples_all, n_weights + 1);
        all_mse_samples = zeros(n_samples_all, 1);
        I_patch_gt = I_gt(patch_lim(1, 1):patch_lim(2, 1), patch_lim(1, 2):patch_lim(2, 2), :);
        border = baek2017Algorithm2Options.l_err_border(2);
        I_patch_gt_clipped = I_patch_gt((border + 1):(end - border), (border + 1):(end - border), :);
        for s = 1:n_samples_all
            [I_patch_s, all_err_samples(s, :)] = baek2017Algorithm2(...
                image_sampling_f, align_f, dispersion_f, sensor_map_resampled, bands,...
                I_raw_f, all_weights_samples(s, :), rho,...
                baek2017Algorithm2Options, baek2017Algorithm2Verbose...
            );
            mse = I_patch_s((border + 1):(end - border), (border + 1):(end - border), :) - I_patch_gt_clipped;
            all_mse_samples(s) = mean(mean(mean(mse.^2)));
        end
        log_all_err_samples = log10(all_err_samples(:, err_filter));
        log_all_mse_samples = log10(all_mse_samples);
        
        % Also obtain mean-square-error values for the search path
        path_mse_samples = zeros(n_iter_all, 1);
        for s = 1:n_iter_all
            I_patch_s = baek2017Algorithm2(...
                image_sampling_f, align_f, dispersion_f, sensor_map_resampled, bands,...
                I_raw_f, weights_search.weights(s, :), rho,...
                baek2017Algorithm2Options, baek2017Algorithm2Verbose...
            );
            mse = I_patch_s((border + 1):(end - border), (border + 1):(end - border), :) - I_patch_gt_clipped;
            path_mse_samples(s) = mean(mean(mean(mse.^2)));
        end
        log_path_mse_samples = log10(path_mse_samples);
        log_path_mse_samples_diff = [diff(log_path_mse_samples, 1); 0];
        
        % Plotting
        figure;
        hold on
        title('L-hypersurface with search path for the selected weights')
        origin_plot = weights_search.origin(err_filter);
        if n_active_weights == 1
            plot(...
                log_all_err_samples(:, 2), log_all_err_samples(:, 1),...
                'Marker', 'o'...
            );
            plot(origin_plot(2), origin_plot(1), 'k*');
        elseif n_active_weights == 2
            tri = delaunay(log_all_err_samples(:, 2), log_all_err_samples(:, 3));
            trisurf(...
                tri, log_all_err_samples(:, 2), log_all_err_samples(:, 3), log_all_err_samples(:, 1),...
                'FaceAlpha', 0.5 ...
            );
            plot3(origin_plot(2), origin_plot(3), origin_plot(1), 'ko');
        else
            error('Unexpected number of active weights.');
        end
        if n_active_weights == 1
            for io = 1:n_iter_outer
                quiver(...
                    log_err(outer_it_start(io):outer_it_end(io), 2), log_err(outer_it_start(io):outer_it_end(io), 1),...
                    log_err_diff(outer_it_start(io):outer_it_end(io), 2), log_err_diff(outer_it_start(io):outer_it_end(io), 1),...
                    'AutoScale', 'off', 'Color', iteration_colors(io, :)...
                );
            end
            xlabel(sprintf('log_{10}(regularization norm %d)', to_all_weights(1)))
            ylabel('log_{10}(residual)')
        elseif n_active_weights == 2
            for io = 1:n_iter_outer
                quiver3(...
                    log_err(outer_it_start(io):outer_it_end(io), 2), log_err(outer_it_start(io):outer_it_end(io), 3), log_err(outer_it_start(io):outer_it_end(io), 1),...
                    log_err_diff(outer_it_start(io):outer_it_end(io), 2), log_err_diff(outer_it_start(io):outer_it_end(io), 3), log_err_diff(outer_it_start(io):outer_it_end(io), 1),...
                    'AutoScale', 'off', 'Color', iteration_colors(io, :)...
                );
            end
            xlabel(sprintf('log_{10}(regularization norm %d)', to_all_weights(1)))
            ylabel(sprintf('log_{10}(regularization norm %d)', to_all_weights(2)))
            zlabel('log_{10}(residual)')
        else
            error('Unexpected number of active weights.');
        end
        hold off
        legend('L-hypersurface', 'MDC origin', 'Search path');
        axis equal
        
        figure;
        hold on
        title('Patch log_{10}(MSE) surface with search path for the selected weights')
        if n_active_weights == 1
            plot(...
                log_all_weights_samples(:, 1), log_all_mse_samples,...
                'Marker', 'o'...
            );
        elseif n_active_weights == 2
            tri = delaunay(log_all_weights_samples(:, 1), log_all_weights_samples(:, 2));
            trisurf(...
                tri, log_all_weights_samples(:, 1), log_all_weights_samples(:, 2), log_all_mse_samples,...
                'FaceAlpha', 0.5 ...
            );
        else
            error('Unexpected number of active weights.');
        end
        if n_active_weights == 1
            for io = 1:n_iter_outer
                quiver(...
                    log_weights(outer_it_start(io):outer_it_end(io), 1), log_path_mse_samples(outer_it_start(io):outer_it_end(io)),...
                    log_weights_diff(outer_it_start(io):outer_it_end(io), 1), log_path_mse_samples_diff(outer_it_start(io):outer_it_end(io)),...
                    'AutoScale', 'off', 'Color', iteration_colors(io, :)...
                );
            end
            xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
            ylabel('log_{10}(Mean square error) wrt ground truth patch')
        elseif n_active_weights == 2
            for io = 1:n_iter_outer
                quiver3(...
                    log_weights(outer_it_start(io):outer_it_end(io), 1), log_weights(outer_it_start(io):outer_it_end(io), 2), log_path_mse_samples(outer_it_start(io):outer_it_end(io)),...
                    log_weights_diff(outer_it_start(io):outer_it_end(io), 1), log_weights_diff(outer_it_start(io):outer_it_end(io), 2), log_path_mse_samples_diff(outer_it_start(io):outer_it_end(io)),...
                    'AutoScale', 'off', 'Color', iteration_colors(io, :)...
                );
            end
            xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
            ylabel(sprintf('log_{10}(weight %d)', to_all_weights(2)))
            zlabel('log_{10}(Mean square error) wrt ground truth patch')
        else
            error('Unexpected number of active weights.');
        end
        hold off
        legend('Patch log_{10}(MSE) surface', 'Search path');
        
        % Look at the behaviour of the fixed-point method
        next_weights = all_err_samples(:, 1) .* (...
            log_all_err_samples(:, (1:n_active_weights) + 1) - repmat(weights_search.origin(to_all_weights + 1), n_samples_all, 1)...
        ) ./ (...
            all_err_samples(:, to_all_weights + 1) .* (log_all_err_samples(:, 1) - repmat(weights_search.origin(1), n_samples_all, 1))...
        );
        next_weights(next_weights < 0) = nan;
        next_weights(~isfinite(next_weights)) = nan;
        log_next_weights = log10(next_weights);
        log_next_weights_diff = log_next_weights - log_all_weights_samples;
        figure;
        hold on
        if n_active_weights == 1
            plot(...
                log_all_weights_samples,...
                log_next_weights,...
                'Marker', 'o'...
            );
            plot(log_all_weights_samples, log_all_weights_samples);
            xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
            ylabel(sprintf('Next value of log_{10}(weight %d)', to_all_weights(1)))
            legend('Fixed point formula result', 'y = x');
        elseif n_active_weights == 2
            quiver(...
                log_all_weights_samples(:, 1), log_all_weights_samples(:, 2),...
                log_next_weights_diff(:, 1), log_next_weights_diff(:, 2),...
                'AutoScale', 'on'...
            );
            xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
            ylabel(sprintf('log_{10}(weight %d)', to_all_weights(2)))
        elseif n_active_weights == 3
            quiver3(...
                log_all_weights_samples(:, 1), log_all_weights_samples(:, 2), log_all_weights_samples(:, 3),...
                log_next_weights_diff(:, 1), log_next_weights_diff(:, 2), log_next_weights_diff(:, 3),...
                'AutoScale', 'on'...
            );
            xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
            ylabel(sprintf('log_{10}(weight %d)', to_all_weights(2)))
            zlabel(sprintf('log_{10}(weight %d)', to_all_weights(3)))
        else
            error('Unexpected number of active weights.');
        end
        title('Fixed-point formula for the next weights evaluated at the current weights')
        hold off
        
        % Look at the minimum distance function of Belge et al. 2002.
        mdc_all_weights = sqrt(sum(...
            (log_all_err_samples - ...
            repmat(weights_search.origin(err_filter), n_samples_all, 1)).^2, 2 ...
        ));
        figure;
        hold on
        if n_active_weights == 1
            plot(...
                log_all_weights_samples,...
                mdc_all_weights,...
                'Marker', 'o'...
            );
            xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
            ylabel('Squared distance to origin')
        elseif n_active_weights == 2
            trisurf(...
                tri, log_all_weights_samples(:, 1), log_all_weights_samples(:, 2), mdc_all_weights...
            );
            xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
            ylabel(sprintf('log_{10}(weight %d)', to_all_weights(2)))
            zlabel('Squared distance to origin');
        else
            error('Unexpected number of active weights.');
        end
        title('Squared distance to the origin of the minimum distance function')
        hold off
        
    elseif plot_hypersurfaces
        warning('The L-hypersurface and the MSE hypersurface cannot be plotted when there are more than two active regularization terms.');
    end

elseif plot_search_path || plot_hypersurfaces
    warning('Graphical output cannot be generated when there are more than four active regularization terms.');
end

%% Estimate the entire latent image

baek2017Algorithm2Options.l_surface = false;
solvePatchesOptions.add_border = add_border; % Not used by solvePatchesAligned()
solvePatchesOptions.patch_size = patch_size;
solvePatchesOptions.padding = padding;

if ~isempty(downsampling_factor)
    if downsampling_factor ~= 1
        warning([...
            '`downsampling_factor` is ignored, because solvePatchesAligned(',...
            ') will be used instead of solvePatches().'...
        ]);
    end
    % image_sampling = ceil(image_sampling / downsampling_factor);
end

name_params = [name, sprintf(...
    '_patch%dx%d_pad%d_weights%ew%ew%e_',...
    patch_size(1), patch_size(2), padding,...
    weights(1), weights(2), weights(3)...
)];
[...
    I_latent, image_bounds, I_rgb, J_full, J_est, I_warped...
] = solvePatchesAligned(...
    I_raw, bayer_pattern, dispersionfun,...
    sensor_map_resampled,...
    bands, solvePatchesOptions, @baek2017Algorithm2,...
    {...
        weights, rho,...
        baek2017Algorithm2Options, baek2017Algorithm2Verbose...
    }...
);

% Save the results
saveImages(...
    output_directory, name_params,...
    I_raw, 'roi', 'I_raw',...
    I_latent, 'latent', 'I_latent',...
    I_rgb, 'rgb', 'I_rgb',...
    J_full, 'rgb_warped', 'J_full',...
    J_est, 'reestimated', 'J_est',...
    I_warped, 'warped', 'I_warped'...
);

%% Save parameters and additional data to a file
save_variables_list = [ parameters_list, {...
        'input_image_filename',...
        'true_image_filename',...
        'bands_color',...
        'bands',...
        'sensor_map_resampled',...
        'image_bounds'...
    } ];
save_data_filename = fullfile(output_directory, 'ValidateLHypersurface.mat');
save(save_data_filename, save_variables_list{:});