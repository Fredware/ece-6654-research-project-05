function finalPlot( data, features, t_data, t_features)
% this function plots both the data and the control values for each input.
% This allows users to see how they both look after recording them. 
%  = imresize(control,[1 length(data)]);

[n_chans, ~] = size(data);
[n_features, ~] = size(features);

fig_rows = n_chans + n_features;
fig_cols = 1;
fig_idx = 1;

figure()

for i = 1:n_chans
    subplot( fig_rows, fig_cols, fig_idx)
    plot( t_data, data(~isnan(data)))
    ylabel('V')
    xlabel('Time (s)')
    ylim([-3.0, 3.0])
    yticks(-2.5:0.5:2.5)
    grid on
    fig_idx = fig_idx + 1;
end

nan_features = features(:, 1:length(t_features));

for i = 1:n_features
    subplot( fig_rows, fig_cols, fig_idx)
    plot(t_features, nan_features(i,:))
    ylabel(strcat('Feature ', num2str(i)))
    xlabel('Time (s)')
    fig_idx = fig_idx + 1;
end
end