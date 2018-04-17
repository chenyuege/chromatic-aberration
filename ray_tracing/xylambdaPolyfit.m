function [ polyfun ] = xylambdaPolyfit(...
    X, x_field, max_degree_xy, disparity, disparity_field,...
    lambda, max_degree_lambda, varargin...
)
% XYLAMBDAPOLYFIT  Fit a polynomial model in three variables
%
% ## Syntax
% polyfun = xylambdaPolyfit(...
%     X, x_field, max_degree_xy, disparity, disparity_field,...
%     lambda, max_degree_lambda [, verbose]...
% )
%
% ## Description
% polyfun = xylambdaPolyfit(...
%     X, x_field, max_degree_xy, disparity, disparity_field,...
%     lambda, max_degree_lambda [, verbose]...
% )
%   Returns a polynomial model of disparity in terms of three variables X,
%   Y, and lambda.
%
% ## Input Arguments
%
% X -- Data for the first two independent variables
%   A structure array of the form of the 'stats_real' or 'stats_ideal'
%   output arguments of 'doubleSphericalLensPSF()'. 'X' must have a
%   size of 1 in its third dimension.
%
% x_field -- First two independent variables field
%   A character vector containing the fieldname in 'X' of the data to use
%   for the first two independent variables of the polynomial model.
%   `X(i, j, 1).(x_field)` is expected to be a two-element row vector.
%
% max_degree_xy -- Maximum degree for the first two independent variables
%   The maximum degree of each of the first two independent variables in
%   the set of permissible polynomial models.
%
% disparity -- Data for the dependent variables
%   A structure array of the form of the 'stats_real' or 'stats_ideal'
%   output arguments of 'doubleSphericalLensPSF()'. 'disparity' must have a
%   size of 1 in its third dimension.
%
% disparity_field -- Dependent variables field
%   A character vector containing the fieldname in 'disparity' of the data
%   to use for the first dependent variables of the polynomial model.
%   `disparity(i, j, 1).(disparity_field)` is expected to be a two-element
%   row vector, containing the values of the two dependent variables.
%
% lambda -- Data for the third independent variable
%   A vector of values of the third independent variable. `lambda(j)` is
%   the value corresponding to the data in `X(:, j, 1).(x_field)` and
%   `disparity(:, j, 1).(disparity_field)`.
%
% max_degree_lambda -- Maximum degree for the third independent variable
%   The maximum degree of the third independent variable in the set of
%   permissible polynomial models.
%
% verbose -- Debugging and visualization controls
%   If `verbose` is `true`, graphical output will be generated for
%   debugging purposes.
%
% ## Output Arguments
%
% polyfun -- Polynomial model
%   A function which takes an input 2D array 'xylambda', where the three
%   columns represent the three independent variables. The output of the
%   function is a 2D array, 'disparity', where the columns represent the two dependent
%   variables. 'disparity' is an evaluation of the polynomials in X, Y, and
%   lambda for the two dependent variables.
%
% ## Algorithm
% This function constructs polynomials for the two dependent variables
% having degrees from zero to max_degree_xy in each of the first two
% independent variables, and having degrees from zero to max_degree_lambda
% in the third independent variable. It selects the degrees of the final
% polynomial model (one trivariate polynomial per dependent variable) by
% cross-validation. The cross-validation error estimates for the
% polynomials for the two dependent variables are pooled.
%
% The input data (both the independent and dependent variables) are centered
% and scaled using 'normalizePointsPCA()' prior to polynomial fitting.
%
% ## References
% - MATLAB Help page for the polyfit() function
% - T. Hastie and R. Tibshirani. The Elements of Statistical Learning: Data
%   Mining, Inference, and Prediction, 2nd Edition. New York: Springer,
%   2009.
% - V. Rudakova and P. Monasse. "Precise Correction of Lateral Chromatic
%   Aberration in Images," Lecture Notes on Computer Science, 8333, pp.
%   12–22, 2014.
%
% See also doubleSphericalLensPSF, statsToDisparity, normalizePointsPCA, crossval

% Bernard Llanos
% Supervised by Dr. Y.H. Yang
% University of Alberta, Department of Computing Science
% File created April 17, 2018

    function [powers, n_powers] = powersarray(deg_xy, deg_lambda)
        exponents_xy = 0:deg_xy;
        exponents_lambda = 0:deg_lambda;
        [x_powers_grid, y_powers_grid, lambda_powers_grid] = ndgrid(...
            exponents_xy, exponents_xy, exponents_lambda...
        );
        powers = cat(3,...
            reshape(x_powers_grid, 1, []),...
            reshape(y_powers_grid, 1, []),...
            reshape(lambda_powers_grid, 1, [])...
            );
        n_powers = size(powers, 2);
    end

    function y_est = predfun(vandermonde_matrix_train, y_train, vandermonde_matrix_test)
        coeff = vandermonde_matrix_train \ y_train;
        y_est = vandermonde_matrix_test * coeff;
    end

    function mse = crossvalfun(x_train, x_test)
        n_train = size(x_train, 1);
        x_train_3d = repmat(permute(x_train(:, 1:3), [1 3 2]), 1, n_powers, 1);
        powers_3d = repmat(powers, n_train, 1, 1);
        vandermonde_matrix_train = prod(x_train_3d .^ powers_3d, 3);
        
        x_test_3d = repmat(permute(x_test(:, 1:3), [1 3 2]), 1, n_powers, 1);
        vandermonde_matrix_test = prod(x_test_3d .^ powers_3d, 3);
        
        y_est_x = predfun(vandermonde_matrix_train, x_train(:, 4), vandermonde_matrix_test);
        y_est_y = predfun(vandermonde_matrix_train, x_train(:, 5), vandermonde_matrix_test);
        mse = sum([
            (x_test(:, 4) - y_est_x);
            (x_test(:, 5) - y_est_y)
            ] .^ 2 ...
            ) / (2 * length(y_est_x));
    end

nargoutchk(1, 1);
narginchk(7, 8);

if ~isempty(varargin)
    verbose = varargin{1};
else
    verbose = false;
end

sz = size(X);
n_points = sz(1) * sz(2);
n_lambda = sz(3);
if n_lambda ~= length(lambda)
    error('Expected as many wavelengths in `lambda` as the size of `X` in the third dimension.')
end
n_spatial_dim = 2;
if length(X(1).(x_field)) ~= n_spatial_dim
    error('Expected two independent variables in each element of `X`, "x", and "y".');
end

X_unpacked = permute(reshape([X.(x_field)], n_spatial_dim, []), [2 1]);
lambda_unpacked = repelem(lambda, n_points, 1);
disparity_unpacked = permute(reshape([disparity.(disparity_field)], 2, []), [2 1]);
dataset = [X_unpacked lambda_unpacked disparity_unpacked];

[dataset_normalized_points, T_points] = normalizePointsPCA([dataset(:, 1:3), ones(n_points, 1)]);
[dataset_normalized_disparity, T_disparity] = normalizePointsPCA([dataset(:, 4:5), ones(n_points, 1)]);
T_disparity_inv = inv(T_disparity);
dataset_normalized = [dataset_normalized_points(:, 1:(end-1)) dataset_normalized_disparity(:, 1:(end-1))];

% Use cross validation to find the optimal polynomial complexity
powers = [];
n_powers = [];
mean_mse = zeros(max_degree_xy, max_degree_lambda);
std_mse = zeros(max_degree_xy, max_degree_lambda);
for deg_xy = 0:max_degree_xy
    for deg_lambda = 0:max_degree_lambda
        [powers, n_powers] = powersarray(deg_xy, deg_lambda);
        mse = crossval(crossvalfun, dataset_normalized); % Defaults to 10-fold cross validation
        mean_mse(deg_xy, deg_lambda)  = mean(mse);
        std_mse(deg_xy, deg_lambda)  = std(mse);
    end
end

% "Often a 'one-standard error' rule is used with cross-validation, in
% which we choose the most parsimonious model whose error is no more than
% one standard error above the error of the best model."
%
% From T. Hastie and R. Tibshirani, 2009.
min_mse = min(min(mean_mse));
choice_mse = mean_mse - std_mse - min_mse;
possible_choices = (choice_mse <= 0);
[deg_xy_matrix, deg_lambda_matrix] = meshgrid(0:max_degree_xy, 0:max_degree_lambda);
% Prioritize simplicity with respect to wavelength
deg_lambda_best = min(deg_lambda_matrix(possible_choices));
possible_choices = possible_choices & (deg_lambda_matrix == deg_lambda_best);
degree_xy_best = min(deg_xy_matrix(possible_choices));

% Visualization
if verbose
    mse_minus1std = mean_mse - std_mse;
    mse_plus1std = mean_mse + std_mse;
    figure;
    hold on
    s1 = surf(deg_xy_matrix, deg_lambda_matrix, mse_minus1std);
    set(s1, 'EdgeColor', 'none', 'FaceAlpha', 0.4);
    s2 = surf(deg_xy_matrix, deg_lambda_matrix, mse_plus1std);
    set(s2, 'EdgeColor', 'none', 'FaceAlpha', 0.4);
    s3 = surf(deg_xy_matrix, deg_lambda_matrix, mean_mse);
    set(s3, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
    set(s3, 'CData', repmat(possible_choices, 1, 1, 3), 'FaceColor', 'texturemap');
    scatter(degree_xy_best, deg_lambda_best, mean_mse(degree_xy_best, deg_lambda_best), 'filled')
    hold off
    xlabel('Spatial polynomial degree')
    ylabel('Wavelength polynomial degree')
    zlabel('Mean square error')
    legend('-1 std', '+1 std', 'Mean square error', 'Selected model');
    title('Cross validation error estimates, with "1 std. dev. from min" models in white');
end

% Fit the final model using all data
[powers_final, n_powers] = powersarray(degree_xy_best, deg_lambda_best);
x_train_final = repmat(permute(dataset_normalized(:, 1:3), [1 3 2]), 1, n_powers, 1);
powers_final_rep = repmat(powers_final, n_points, 1, 1);
vandermonde_matrix_final = prod(x_train_final .^ powers_final_rep, 3);
coeff_x = vandermonde_matrix_final \ dataset_normalized(:, 4);
coeff_y = vandermonde_matrix_final \ dataset_normalized(:, 5);

    function disparity = modelfun(xylambda)
        % Apply and reverse normalization
        n = size(xylambda, 1);
        xylambda_normalized = (T_points * [xylambda, ones(n, 1)].').';
        powers_rep = repmat(powers_final, n, 1, 1);
        vandermonde_matrix = prod(xylambda_normalized(:, 1:(end-1)) .^ powers_rep, 3);

        disparity_x_normalized = vandermonde_matrix * coeff_x;
        disparity_y_normalized = vandermonde_matrix * coeff_y;
        disparity_normalized = [disparity_x_normalized disparity_y_normalized, ones(n, 1)];
        disparity = (T_disparity_inv * disparity_normalized.').';
        disparity = disparity(:, 1:(end-1));
    end

polyfun = @modelfun;
end