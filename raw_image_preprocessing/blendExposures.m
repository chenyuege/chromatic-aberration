function [ output_files, peaks, scaling_factors ] = blendExposures(...
    dir, var_name, reference_paths, other_paths, regex, range, align...
)
% BLENDEXPOSURES  Combine images taken under different exposure settings
%
% ## Syntax
% output_files = blendExposures(...
%   dir, var_name, reference_paths, other_paths, regex, range, align...
% )
% [output_files, peaks] = blendExposures(...
%   dir, var_name, reference_paths, other_paths, regex, range, align...
% )
% [output_files, peaks, scaling_factors] = blendExposures(...
%   dir, var_name, reference_paths, other_paths, regex, range, align...
% )
%
% ## Description
% output_files = blendExposures(...
%   dir, var_name, reference_paths, other_paths, regex, range, align...
% )
%   Load and process images, then save them to the output directory and
%   return the names and paths of the output files. (No output arguments
%   can also be requested.)
%
% [output_files, peaks] = blendExposures(...
%   dir, var_name, reference_paths, other_paths, regex, range, align...
% )
%   Additionally returns the peak values used to normalize the images.
%
% [output_files, peaks, scaling_factors] = blendExposures(...
%   dir, var_name, reference_paths, other_paths, regex, range, align...
% )
%   Additionally returns the scaling factors used to convert between
%   exposures.
%
% ## Input Arguments
%
% dir -- Output directories
%   A structure with the following fields:
%   - 'out_reference': A cell vector of character vectors containing the
%     paths of the directories in which to store processed versions of the
%     images referred to by `reference_paths`. If this field is absent, the
%     reference images will still be used to calibrate conversions between
%     exposures, but will not be merged across exposures.
%   - 'other_paths': A cell vector of character vectors containing the
%     paths of the directories in which to store processed versions of the
%     images referred to by `other_paths`. If this field is absent, and
%     `other_paths` is not empty, and error will be thrown.
%
%   Each field of 'dir' refers to a cell vector with the same length as
%   `regex`. The elements of the cell vectors pertain to the images which
%   match the corresponding elements of `regex`.
%
% var_name -- Input and output variable name
%   A character vector containing the variable name of the variable used to
%   store images in the input and output '.mat' files. (Images are stored
%   as '.mat' files, not as image files.)
%
% reference_paths -- Reference image filenames and paths
%   A cell vector of character vectors containing the names and paths of
%   images taken under different exposures, used to calibrate conversion
%   factors between exposures, and, if `dir.out_reference` exists, also
%   blended across exposures and saved to files.
%
% other_paths -- Other image filenames and paths
%   A cell vector of character vectors containing the names and paths of
%   additional images to be blended across exposures. `other_paths` can be
%   empty (`{}`).
%
% regex -- Regular expressions
%   A cell vector of cell vectors of character vectors. Each character
%   vector is a regular expression which matches the filenames of images
%   taken under a given exposure setting. Each cell vector of character
%   vectors represents a set of exposures that it is permissible to convert
%   between. Each set of exposures must be ordered by increasing exposure.
%
%   Filename paths and extensions are removed prior to regular expression
%   operations.
%
% range -- Clipping range
%   A two-element vector containing the values at or below which a pixel is
%   considered to be zero, and at or above which a pixel is considered to
%   be saturated, respectively. Only pixels between these two values will
%   be used to calibrate conversions between exposures.
%
% align -- Bayer pattern description
%   A four-character character vector, specifying the Bayer tile pattern of
%   the images. For example, 'gbrg'.
%
%   `align` has the same form as the `sensorAlignment` input argument of
%   `demosaic()`
%
% ## Output Arguments
%
% output_files -- Output image filenames
%   A structure with the following fields:
%   - 'out_reference': A cell vector of cell vectors of character vectors
%     containing the paths and filenames of the processed versions of the
%     images referred to by `reference_paths`. This field is only present
%     if `dir.out_reference` exists.
%   - 'other_paths': A cell vector of cell vectors of character vectors
%     containing the paths and filenames of the processed versions of the
%     images referred to by `other_paths`. This field is only present if
%     `dir.other_paths` exists.
%
%   Each field of 'output_files' refers to a cell vector with the same
%   length as `regex`. The elements of the cell vector pertain to the
%   images which match the corresponding elements of `regex`.
%
% peaks -- Image peak values
%   The output images are normalized so that the maximum image value is
%   equal to the maximum image value at any of the original exposures. The
%   images are normalized in batches corresponding to the elements of
%   `regex`. `peaks` is a vector, with the same length as `regex`,
%   containing the peak values used for normalization.
%
% scaling_factors -- Exposure scaling factors
%   A cell vector of matrices, where `scaling_factors{i}` corresponds to
%   `regex{i}`, and contains a matrix of scaling factors for converting
%   pixels between the exposures referred to by the elements of `regex{i}`.
%   `scaling_factors{i}` is an n x 3 matrix, where 'n' is the length of
%   `regex{i}`, and the columns index colour channels.
%   `scaling_factors{i}(j, k)` is the scaling factor by which pixels, in
%   the k-th colour channel, subject to exposure `regex{i}{j}`, should be
%   multiplied to convert them to exposure `regex{i}{end}`.
%
%   Note that `peaks(i)` is equal to the maximum value in
%   `scaling_factors{i}`.
%
% ## Detailed description
%
% This function iterates over the elements of `regex`. For each element,
% `regex{i}`, it finds the files in `reference_paths` matching any of the
% elements of `regex{i}`. These files are then grouped by two criteria:
% - Exposure: The element of `regex{i}` they matched
% - Scene: The filename that results when the substrings matching the
%   element of `regex{i}` are removed.
%
% This function expects one image for every element of `regex{i}` for each
% scene.
%
% The files are loaded, and an array is created with as many columns as
% there are exposures. The rows of the array are corresponding pixels, all
% having values between the elements of `range`, from the images in the
% same scene, taken under different exposures. The first principal
% component is computed for the data, and it represents a set of scaling
% factors which can convert pixels from one exposure to another.
%
% Given the scaling factors, this function can then produce images which
% contain pixels from multiple exposures. It does so by loading the images
% to be merged (referred to by `reference_paths` and/or `other_paths`).
% Scenes are discovered in the loaded images (images from `reference_paths`
% are always treated as from different scenes from the images from
% `other_paths`). For each scene, this function selects pixels from the
% highest possible exposure (at a higher index in `regex{i}`) that are less
% than `range(2)` and uses the scaling factors to map them all to the same
% exposure (the exposure corresponding to the last element of `regex{i}`).
% The final image then may contain more properly exposed pixels than any
% of the individual images.
%
% The output images corresponding to `regex{i}` are normalized by dividing
% by `peaks(i)`. `peaks(i)` is the maximum possible value that could result
% from mapping a value of one, from any exposure in `regex{i}`, to the
% exposure corresponding to the last element of `regex{i}`.
%
% ## Notes
% - All images are expected to be raw images (colour-filter array images
%   stored as a single channel) in floating point format, with values in
%   the range [0, 1]. (If images have values slightly below zero, because
%   of dark frame subtraction, this is fine.)
% - Individual colour channels are processed separately; Exposure
%   conversion factors are calibrated per-channel.
% - The input images should be linearized and dark corrected (dark frame
%   subtracted)
%
% ## References
% The approach taken in this function is inspired by the conversion between
% exposures used in:
%
%   Darrodi, M. M., Finlayson, G., Goodman, T., & Mackiewicz, M. (2015).
%   Reference data set for camera spectral sensitivity estimation. Journal
%   of the Optical Society of America A: Optics and Image Science, and
%   Vision, 32(3), 381-391. doi:10.1364/JOSAA.32.000381
%
% See also darkSubtract, imreadRAW, dirreadRAW, bayerMask

% Bernard Llanos
% Supervised by Dr. Y.H. Yang
% University of Alberta, Department of Computing Science
% File created December 3, 2018

nargoutchk(0, 3)
narginchk(7, 7)

n_path_types = 2;
n_exposure_groups = length(regex);

do_output = false(n_path_types, 1);
if isfield(dir, 'out_reference')
    do_output(1) = true;
    output_files.out_reference = cell(n_exposure_groups, 1);
end
if isfield(dir, 'other_paths')
    do_output(2) = true;
    output_files.other_paths = cell(n_exposure_groups, 1);
elseif ~isempty(other_paths)
    error('Images are referred to in `other_paths` that will not be processed because `dir.other_paths` does not exist.');
end

all_paths = {reference_paths, other_paths};

% Remove filename paths and extensions
names = cell(n_path_types, 1);
for i = 1:n_path_types
    names{i} = cell(size(all_paths{i}));
    for j = 1:length(names{i})
        [~, names{i}{j}, ~] = fileparts(all_paths{i}{j});
    end
end

n_channels = 3; % RGB channels
peaks = zeros(n_exposure_groups, 1);
scaling_factors = cell(n_exposure_groups, 1);

for r = 1:length(regex)
    n_exposures = length(regex{r});
    
    % Group files by exposure
    exposure_indices = cell(n_path_types, 1);
    exposure_free_names = cell(n_path_types, 1);
    exposure_free_names_ind = cell(n_path_types, 1);
    for i = 1:n_path_types
        exposure_indices{i} = zeros(length(names{i}), 1);
        exposure_free_names{i} = cell(n_exposures, 1);
        exposure_free_names_ind{i} = cell(n_exposures, 1);
        for ri = 1:n_exposures
            reg_indices = regexp(names{i}, regex{r}{ri});
            filter = find(~cellfun(@isempty, reg_indices, 'UniformOutput', true));
            exposure_indices{i}(filter) = ri;
            exposure_free_names{i}{ri} = regexprep(names{i}(filter), regex{r}{ri}, '');
            exposure_free_names_ind{i}{ri} = filter;
        end
    end
    
    % Group files by scene
    scene_indices = cell(n_path_types, 1);
    n_scenes = zeros(n_path_types, 1);
    scene_names = cell(n_path_types, 1);
    for i = 1:n_path_types
        scene_indices{i} = zeros(length(names{i}), 1);
        exposure_free_names{i} = cat(1, exposure_free_names{i}{:});
        exposure_free_names_ind{i} = cat(1, exposure_free_names_ind{i}{:});
        [scene_names{i}, ~, unique_indices] = unique(exposure_free_names{i});
        n_scenes(i) = length(scene_names{i});
        for j = 1:n_scenes(i)
            filter = (unique_indices == j);
            indices = exposure_free_names_ind{i}(filter);
            scene_indices{i}(indices) = j;
        end
    end
    
    % For each colour channel, load reference images by scene, then by exposure
    factors_r = zeros(n_exposures, n_channels);
    for c = 1:n_channels
        pixels = cell(n_scenes(1), 1);
        for s = 1:n_scenes(1)
            scene_filter = (scene_indices{1} == s);
            for ri = 1:n_exposures
                filter = (exposure_indices{1} == ri) & scene_filter;
                if sum(filter) ~= 1
                    error('Expected one and only one image per exposure per scene.');
                end
                filepath = reference_paths{filter};
                I = loadImage(filepath, var_name);
                if size(I, 3) ~= 1
                    error('The input image "%s" is not a RAW image.', filepath);
                end
                if ri == 1
                    mask = reshape(bayerMask(size(I, 1), size(I, 2), align), [], n_channels);
                    mask_c = mask(:, c);
                    pixels{s} = zeros(sum(mask_c), n_exposures);
                    pixels{s}(:, ri) = I(mask_c);
                else
                    pixels{s}(:, ri) = I(mask_c);
                end
            end

            % Filter to pixels in the desired range
            pixels{s} = pixels{s}(all((pixels{s} > range(1)) & (pixels{s} < range(2)), 2), :);
        end
        pixels = cell2mat(pixels);

        % Find per-channel exposure conversion factors
        component = pca(pixels, 'NumComponents', 1);
        factors_r(:, c) = component(end) ./ component;
    end
    peaks(r) = max(max(factors_r));
    scaling_factors{r} = factors_r;
    
    % Blend across exposures
    for i = 1:n_path_types
        if ~do_output(i)
            continue;
        end
        
        for s = 1:n_scenes(i)
            scene_filter = (scene_indices{i} == s);
            filter = (exposure_indices{i} == n_exposures) & scene_filter;
            if sum(filter) ~= 1
                error('Expected one and only one image per exposure per scene.');
            end
            filepath = all_paths{i}{filter};
            I = loadImage(filepath, var_name);
            if size(I, 3) ~= 1
                error('The input image "%s" is not a RAW image.', filepath);
            end
            I_out = I;
            mask_channels = bayerMask(size(I, 1), size(I, 2), align);
            mask_saturation = (I_out >= range(2));
            for ri = (n_exposures - 1):-1:1
                filter = (exposure_indices{i} == ri) & scene_filter;
                filepath = all_paths{i}{filter};
                I = loadImage(filepath, var_name);
                if size(I, 3) ~= 1
                    error('The input image "%s" is not a RAW image.', filepath);
                end
                for c = 1:n_channels
                    mask_c = mask_channels(:, :, c) & mask_saturation;
                    mask_saturation(mask_c) = (I(mask_c) >= range(2));
                    I_out(mask_c) = I(mask_c) * factors_r(ri, c);
                end
            end
            I_out = I_out / peaks(r);
            if i == 1
                if s == 1
                    output_files.out_reference{r} = cell(n_scenes(i), 1);
                end
                output_files.out_reference{r}{s} = saveImages(...
                    'data', dir.out_reference{r}, scene_names{i}{s}, I_out, '', var_name...
                );
            elseif i == 2
                if s == 1
                    output_files.other_paths{r} = cell(n_scenes(i), 1);
                end
                output_files.other_paths{r}{s} = saveImages(...
                    'data', dir.other_paths{r}, scene_names{i}{s}, I_out, '', var_name...
                );
            else
                error('Unknown type of image.');
            end
        end
    end
end

end