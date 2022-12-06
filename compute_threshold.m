function [mav_thresh,mav_baseline] = compute_threshold(data)
    % conversion of EMG Data to mean absolute value
    dataMax = max(movmean(abs(data),30)); 

% Rest of Data is for instantaneous MVCs afterthe 5 second baseline period
% Spike Detection and Framing:
    % Set a threshold for spike detection at the average MAV during the
    % baseline period + 4 times the standard deviation
    mav_thresh = dataMax.*0.075;
    mav_baseline = mean(abs(data((end-5000):end)));
end