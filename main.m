%% TODO
% 1. Add MAV thresh on MAV plot
% 2. Limit x-axes on live plots
% 3. Figure out how to plot the last spike
%% Reset workspace
try
    uno.close;
catch
end
clear all; 
clc;

%% Establish connection with Arduino
% Pass COM port number as argument to bypass automatic connection.
[uno, uno_connected] = connect_board();
fs = 1000; % Hz

%% Initialize the App
tc_app = TCApp;
tc_app.CollectingBaselineLamp.Color = 'black';
tc_app.RecordingSpikesLamp.Color = 'black';
tc_app.DataLogger = uno;

%% Baseline Data Collection
baseline_data = tc_app.BaselineData;
[mav_thresh, mav_baseline] = compute_threshold(baseline_data);
%% Debugging 
mav_thresh = 0.75;

%% Set up animated lines
% [fig, animated_lines, t_max, t_min] = initialize_figure(n_chans, n_feats, tc_app);
n_lines = 4; % sEMG, MAV, MAV threshold, MAV event  
t_max = 10; %secs
t_min = 0; %secs
line_handles = cell( 1, n_lines);

line_handles{1} = animatedline(tc_app.UIAxes_semg);
line_handles{2} = animatedline(tc_app.UIAxes_mav);
line_handles{3} = animatedline(tc_app.UIAxes_mav);
line_handles{4} = animatedline(tc_app.UIAxes_mav_event);

linkaxes([tc_app.UIAxes_semg, tc_app.UIAxes_mav], 'x');
linkaxes([tc_app.UIAxes_mav, tc_app.UIAxes_mav_event], 'y');

tc_app.UIAxes_semg.XLim = [t_min t_max];

animated_lines = line_handles;
%% Plotting in real time
MONITORING_MAV = 0;
START_DETECTED = 1;
STOP_DETECTED = 2;
state = MONITORING_MAV;

n_chans = 1; % raw sEMG channels
n_feats = 1; % real-time features computed from sEMG channels
mav_win_len = 300; %samples
mav_event_padding = 1; %seconds

% INITIALIZATION
[data, features, data_idx, features_idx, prev_sample, prev_timestamp] = initialize_data_structures(60e3, n_feats);
% t_data = [0];
t_features = [];
pause(0.5)

% Run until time is out or figure closes
% while( ishandle(fig))
while( tc_app.RecordSession)
    % SAMPLE ARDUINO
    pause(0.0111111)
    try
        emg = uno.getRecentEMG; % value range: [-2.5:2.5]; length range: [1:buffer length]
        if ~isempty(emg)
            % determine how many EMG samples were received
            [~, new_samples] = size(emg); 
            % add new EMG data to the data buffer
            data( :, data_idx:data_idx + new_samples - 1) = emg(1,:);
            % update the data index for inserting future data
            data_idx = data_idx + new_samples;
            features_idx = features_idx + 1;
        end
    catch
        disp("Data acquisition: FAILED")
    end

    % make sure buffer is not empty and contains enough data to compute
    % your features
    if ~isempty(emg) && data_idx > mav_win_len
        % transform sample time to time in seconds
        timestamp = (data_idx - 1) / fs;
        % CALCULATE FEATURES
        try
            [mav_feat, ~] = compute_amplitude_feats(data(:, data_idx-300: data_idx-1));
            features( 1, features_idx) = mav_feat;
        catch
            disp('Something broke in your code!')
        end
        t_features(features_idx) = timestamp;
        
        % UPDATE PLOT
        [t_max, t_min] = update_figure(animated_lines, timestamp, data, features, prev_sample, data_idx, features_idx, t_max, t_min, mav_thresh, tc_app);

        if state == MONITORING_MAV
            if mav_feat > mav_thresh
                state = START_DETECTED;

                mav_event_start = data_idx-1;
            end
        elseif state == START_DETECTED
            if mav_feat < mav_thresh
                state = STOP_DETECTED;
                
                mav_event_stop = data_idx-1;
                t_stop = timestamp;
            end
        elseif state == STOP_DETECTED
            if (timestamp - t_stop) > mav_event_padding
                state = MONITORING_MAV;
                
                mav_event_data = data(mav_event_start-mav_event_padding*fs:mav_event_stop+mav_event_padding*fs);
                mav_event = compute_running_mav(mav_event_data, 0.100*fs);

                y = mav_event;
                x = linspace(0, length(mav_event)/fs, length(mav_event));
 
                plot(tc_app.UIAxes_mav_event, x, y);
                [tc_init,tc_term]= tc_comp(x,y,mav_thresh);
               
                tc_app.TextArea.Value = sprintf("Time constant init is %.3f \nTime constant term is %.3f", tc_init, tc_term);
            end
        end

        prev_timestamp = timestamp;
        prev_sample = data_idx;
    end
end
%% Plot the data and control values from the most recent time running the system
% finalPlot(data, features, t_data, t_features)
data_table = timetable(data(:,1:data_idx-1)', 'SampleRate', fs);
data_table = renamevars(data_table, "Var1", "sEMG");

features_table = timetable((features(:, 1:length(t_features)))','RowTimes', seconds(t_features'));
features_table = splitvars(features_table);
features_table = renamevars(features_table, ["Var1"], ["MAV"]);
features_table = rmmissing(features_table);

full_table = synchronize(data_table, features_table, 'union', 'linear');

subplot(3,1,1)
scaling_factor = max(full_table.sEMG);

plot(full_table.Time, full_table.sEMG)

subplot(3,1,2)
scaling_factor = max(full_table.MAV);
plot(full_table.Time, full_table{:, 2})

% legend([full_table.Properties.VariableNames(2:3), "Cue"])
ylim([-0.1*scaling_factor 1.1*scaling_factor])
grid on

%% close the arduino serial connection before closing MATLAB
uno.close;
disp('Board connection: TERMINATED')
