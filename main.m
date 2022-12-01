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
my_app = TCApp;

my_app.UIFigure
%% Baseline Data Collection
baseline_period = 3; %seconds
fs = 1000; % Hz

% Let the background buffer accumulate data for the specified period
pause(baseline_period)

% Retrieve data from buffer
emg = uno.getRecentEMG; % value range: [-2.5:2.5]; length range: [1:buffer length]

% Compute detection threshold using the retrieved data
baseline_data = emg(1:baseline_period*fs);
mav_thresh = compute_threshold(baseline_data);

%% Plotting in real time
% SET UP PLOT
INSTRUCTION_PERIOD = 4; %seconds
RELAXATION_PERIOD = 2; %seconds

n_chans = 1; % raw sEMG channels
n_feats = 1; % real-time features computed from sEMG channels

[fig, animated_lines, t_max, t_min] = initialize_figure(n_chans, n_feats, my_app);

% INITIALIZATION
[data, features, data_idx, features_idx, prev_sample, prev_timestamp] = initialize_data_structures(60e3, n_feats);
% t_data = [0];
t_features = [];
pause(0.5)

% Run until time is out or figure closes
% while( ishandle(fig))
while( ishandle(my_app.UIFigure))
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

    if ~isempty(emg) && data_idx > 500
        % UPDATE timestamp
%         timestamp = toc;
        timestamp = (data_idx - 1) / fs;
        % CALCULATE FEATURES
        try
            [mav_feat, ~] = compute_amplitude_feats(data(:, data_idx-300: data_idx-1));

            features( 1, features_idx) = mav_feat;

        catch
            disp('Something broke in your code!')
        end

        t_features(features_idx) = timestamp;
%         tempStart = t_data(end);
%         t_data( prev_sample:data_idx-1) = linspace( tempStart, timestamp, new_samples);
        
        % UPDATE PLOT
        [t_max, t_min] = update_figure(animated_lines, timestamp, data, features, prev_sample, data_idx, features_idx, t_max, t_min, mav_thresh);
    
      


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
%% save data to file
raw_data = data(1:data_idx-1);