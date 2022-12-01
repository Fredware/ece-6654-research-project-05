function [mav_thresh] = compute_threshold(data)
    % conversion of EMG Data to mean absolute value
    dataBaseline = movmean(abs(data), 10);    
    % Average EMG MAVs for the baseline/resting period
    dataBaselineMean = mean(abs(dataBaseline));
    % Obtain Standard Deviation of EMG MAVs for the baseline/resting period
    dataBaselineSTD = std(dataBaselineMean);

% Rest of Data is for instantaneous MVCs afterthe 5 second baseline period
% Spike Detection and Framing:
    % Set a threshold for spike detection at the average MAV during the
    % baseline period + 4 times the standard deviation
    mav_thresh = dataBaselineMean+(4.*dataBaselineSTD);
end