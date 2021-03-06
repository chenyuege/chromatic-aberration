function e_rgb_table = evaluateAndSaveRGB(...
    I_rgb, R_rgb, dp, I_name, alg_name, name_params...
)
% EVALUATEANDSAVERGB  Compare colour images and save the comparison results
%
% ## Syntax
% e_rgb_table = evaluateAndSaveRGB(...
%     I_rgb, R_rgb, dp, I_name, alg_name, name_params...
% )
%
% ## Description
% e_rgb_table = evaluateAndSaveRGB(...
%     I_rgb, R_rgb, dp, I_name, alg_name, name_params...
% )
%   Returns a table containing quantitative comparisons between the two
%   images, and saves any graphical comparisons to files.
%
% ## Input Arguments
%
% I_rgb -- Estimated colour image
%   An h x w x 3 array containing an estimated colour image.
%
% R_rgb -- Reference colour image
%   An h x w x 3 array containing the ideal/true colour image.
%
% dp -- Dataset description
%   A structure output by 'describeDataset()' providing information about
%   which comparisons to generate for the image having the name `I_name`.
%
% I_name -- Image name
%   A character vector containing the name of the image being estimated,
%   used to query `dp` for special evaluations to be conducted on it.
%
% alg_name -- Algorithm name
%   A character vector describing the image estimation algorithm and its
%   parameters, used to label the output in `e_rgb_table`.
%
% name_params -- Image partial filename
%   A character vector containing the base path and filename (excluding the
%   file extension) describing the estimated image. Graphical evaluations
%   performed on the estimated image will be saved to MATLAB figure files
%   that are given filepaths starting with this string and ending with a
%   prefix describing the type of evaluation, followed by the file
%   extension.
%
% ## Output Arguments
%
% e_rgb_table -- Colour error statistics
%   A table form of the `e_rgb` structure returned by 'evaluateRGB()' when
%   invoked on the estimated and reference images.
%
% ## Side Effects
% - The figures created by 'evaluateRGB()' are closed.
%
% See also evaluateRGB, evaluateAndSaveSpectral, describeDataset, writetable

% Bernard Llanos
% Supervised by Dr. Y.H. Yang
% University of Alberta, Department of Computing Science
% File created August 15, 2018

narginchk(6, 6);
nargoutchk(0, 1);

evaluate_options = dp.evaluation.global_rgb;
if isfield(dp.evaluation.custom_rgb, I_name)
    evaluate_options = mergeStructs(...
        dp.evaluation.global_rgb,...
        dp.evaluation.custom_rgb.(I_name), false, true...
    );
end
[e_rgb, fg_rgb] = evaluateRGB(...
    I_rgb, R_rgb, evaluate_options...
);

% Save figures to files
n_channels_rgb = 3;
if isfield(fg_rgb, 'error_map')
    for c = 1:n_channels_rgb
        savefig(...
            fg_rgb.error_map(c),...
            [name_params sprintf('_errChannel%d.fig', c)], 'compact'...
        );
        close(fg_rgb.error_map(c));
    end
end

% Produce table output
e_rgb_formatted = struct(...
    'Algorithm', string(alg_name),...
    'MRAE_R', e_rgb.mrae(1),...
    'MRAE_G', e_rgb.mrae(2),...
    'MRAE_B', e_rgb.mrae(3),...
    'RMSE_R', e_rgb.rmse(1),...
    'RMSE_G', e_rgb.rmse(2),...
    'RMSE_B', e_rgb.rmse(3),...
    'PSNR_R', e_rgb.psnr(1),...
    'PSNR_G', e_rgb.psnr(2),...
    'PSNR_B', e_rgb.psnr(3),...
    'CPSNR', e_rgb.cpsnr,...
    'SSIM_R', e_rgb.ssim(1),...
    'SSIM_G', e_rgb.ssim(2),...
    'SSIM_B', e_rgb.ssim(3),...
    'SSIM_Mean', e_rgb.ssim(4),...
    'MI_RG_Reference', e_rgb.mi_within(1, 1),...
    'MI_RG', e_rgb.mi_within(1, 2),...
    'MI_GB_Reference', e_rgb.mi_within(2, 1),...
    'MI_GB', e_rgb.mi_within(2, 2),...
    'MI_RB_Reference', e_rgb.mi_within(3, 1),...
    'MI_RB', e_rgb.mi_within(3, 2),...
    'MI_R', e_rgb.mi_between(1),...
    'MI_G', e_rgb.mi_between(2),...
    'MI_B', e_rgb.mi_between(3)...
);
e_rgb_table = struct2table(e_rgb_formatted);

end
