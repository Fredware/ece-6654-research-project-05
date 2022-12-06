%% Section 1: Clear all variables
try
    uno.close; %close any existing arudino connections
catch 
        %if closing arduino fails, do nothing
end
clear all; clc; %clear all matlab variables and clear the workspace display


%% Section 2: Set Up Virtual Environment (MuJoCo)
% You should have MuJoCo open with a model loaded and running before
% starting this code!  If your code is crashing during this section, try
% the following: Close MuJoCo, Open MuJoCo, Open Model, Play MuJoCo, Run
% MATLAB Code.
[model_info, movements,command, selectedDigits_Set1, selectedDigits_Set2, VREconnected] = connect_hand;


%% Section 3: Connect to Arduino
[uno, ArduinoConnected]=connect_ard1ch();% can put the comport number in as an argument to bypass automatic connection, useful if more than one arduino uno is connected
%% Section 3.5: Collect Baseline Data


%% Section 4: Plot (and control) in real time

% SET UP PLOT
[fig, animatedLines, Tmax, Tmin] = plotSetup1ch();

% INITIALIZATION
[data,control, dataindex, controlindex, prevSamp,previousTimeStamp]=init1ch();
tdata=[0];
tcontrol=[];
pause(0.5)
tic
while(ishandle(fig)) %run until figure closes
    % SAMPLE ARDUINO
    try
        emg = uno.getRecentEMG; % gets the recent EMG values from the Arduino. Values returned will be between -2.5 and 2.5 . The size of this variable will be a 1 x up to 330
        if ~isempty(emg)
            [~,newsamps] = size(emg); % determine how many samples were received since the last call
            data(:,dataindex:dataindex+newsamps-1) = emg(1,:); % add new EMG data to the data vector
            dataindex = dataindex + newsamps; %update sample count
            controlindex = controlindex + 1;
        else
            disp('empty array') %if data from arduino is empty, display "empty array"
        end
    catch
        disp('error')
    end
    if ~isempty(emg)
        % UPDATE
        timeStamp = toc; %get timestamp
        % CALCULATE CONTROL VALUES
        try

            %% %%%%%%%%%%%%%%%%%%%%%%% START OF YOUR CODE %%%%%%%%%%%%%%%%%%%%%%%%%%
            
            myControlValue = data(1,dataindex-1); %set the control value to the most recent value of the EMG data. REPLACE THIS LINE

            %% %%%%%%%%%%%%%%%%%%%%%%%% END OF YOUR CODE %%%%%%%%%%%%%%%%%%%%%%%%%%%

            control(1,controlindex) = myControlValue; %update the control parameter with your control value
        catch
            disp('Something broke in your code!')
        end
        tcontrol(controlindex)=timeStamp; %update timestamp
        tempStart = tdata(end);
        tdata(prevSamp:dataindex-1)=linspace(tempStart,timeStamp,newsamps);

        % UPDATE PLOT
        [Tmax, Tmin] = updatePlot1ch(animatedLines, timeStamp, data, control, prevSamp, dataindex, controlindex, Tmax, Tmin);

        % UPDATE HAND
        if(VREconnected) %if connected
            status = updateHand(control, controlindex, command, selectedDigits_Set1, selectedDigits_Set2);
        end
        previousTimeStamp = timeStamp;
        prevSamp = dataindex;
    end
end
%% Section 5: Plot the data and control values from the most recent time running the system
data = data(~isnan(data)); %data is initialized and space is allocated as NaNs. Remove those if necessary.
control = control(~isnan(control)); %data is initialized and space is allocated as NaNs. Remove those if necessary.
finalPlot(data,control,tdata,tcontrol) %plot data and control with their respective timestamps
%% Time Constant calculation
% Ask participant to hold still and relax arm muscles for first 5 seconds
% to obtain baseline
% collect data at baseline: first ~5 seconds

% Baseline Data Collection and Analysis
    % obtain index of where 5 seconds ends
        %creates array of 1s where time is greater than 5
        LogTime5 = tdata > 5; 
        % detects where there is a change from 0 --> 1 (crosses over 5)
        ChangeTime5 = ischange(double(LogTime5));
        % finds the index of that change
        IdxTime5 = find(ChangeTime5);
    % conversion of EMG Data to mean absolute value
    MAVdata = movmean(abs(data),10);
    % Obtain EMG MAVs for the baseline/resting period
    dataBaseline = MAVdata(1:IdxTime5);
    % Average EMG MAVs for the baseline/resting period
    dataBaselineMean = mean(abs(dataBaseline));
    % Obtain Standard Deviation of EMG MAVs for the baseline/resting period
    dataBaselineSTD = std(dataBaselineMean);

% Rest of Data is for instantaneous MVCs afterthe 5 second baseline period
% Spike Detection and Framing:
    % Set a threshold for spike detection at the average MAV during the
    % baseline period + 4 times the standard deviation
    threshold = dataBaselineMean+(4.*dataBaselineSTD);
    % Create logical vector that equals one where EMG values are above the
    % threshold
    AboveThresholdLog = MAVdata > threshold;
    % Detects where the vector changes from 0 --> 1 and 1 --> 0 (where EMG mean
    % absolute value crosses the threshold)
    ThresholdCross = ischange(double(AboveThresholdLog));
    % Finds the indices of those threshold Crossings
    IdxsThresholdCross = find(ThresholdCross);
    % Define window of interest for one contraction ( ~ 1s before and after the
    % last threshold crossing)
    OneSecond = round(IdxTime5./5);
    SpikeWindowMAV = MAVdata((IdxsThresholdCross(end - 1) - OneSecond):(IdxsThresholdCross(end) + OneSecond));
    SpikeWindowTime = tdata((IdxsThresholdCross(end - 1) - OneSecond):(IdxsThresholdCross(end) + OneSecond));

% Obtaining Time Constant Nearest Points Indices, MAV values, and time
% valus
    % Peak
        % Find Value and Index at Peak in Window
        [MAVpeak,IdxPeak] = max(SpikeWindowMAV);
        % Find Time at Peak in Window
        TimePeak = SpikeWindowTime(IdxPeak);

   % Baseline Crossing Point at Start of MVC
        % Find where MAV is above baseline (Prior to Peak)
        AboveBaselineLog = SpikeWindowMAV(1:IdxPeak) > dataBaselineMean;
        % Detect where MAV crosses the baseline
        BaselineX = ischange(double(AboveBaselineLog));
        % Find Indices after MAV last crosses Baseline before Peak
        %Last Index
        IdxBaselineX = find(BaselineX,1,"last");
        % Before and After Cross Indices
        Idxs2BaselineX = [IdxBaselineX - 1, IdxBaselineX];
        %Find MAVs at Baseline Crossing Idxs
        MAVsBaselineX = SpikeWindowMAV(Idxs2BaselineX);
        %Find Time at Baseline Crossing Idxs
        TimesBaselineX = SpikeWindowTime(IdxsBaselineX);

    % Initiation and Termination points: 1 - 1/e and 1e of difference
    % between peak and Baseline
        % Find difference between Peak MAV and Baseline MAV
        peakDiff = MAVpeak - dataBaselineMean;
        % Find MAVs at Time Constant points (1 - 1/e) (Initiation) and (1/e) (Termination) of difference
        % between Peak and Baseline MAVs
        MAVInit = peakDiff.*(1 - (1./exp)) + dataBaselineMean;
        MAVTerm = peakDiff.*(1./exp) + dataBaselineMean;
        % Find MAVs above Initiation MAV points and Below Termination MAV points
        AboveMAVInitLog = SpikeWindow > MAVInit; 
        AboveMAVTermLog = SpikeWindow < MAVTerm;
        % Detect where MAV crosses Initiation and Termination MAVs
        MAVInitX = ischange(double(AboveMAVInitLog));
        MAVTermX = ischange(double(AboveMAVTermLog));
        %Find Indices of the points after these crosses.
        IdxMAVInitX = find(MAVInitX);
        IdxMAVTermX = find(MAVTermX);
        % Find indices  before and after first time crossing Initation MAV
        Idxs2InitX = [IdxMAVInitX(1) - 1, IdxMAVInitX(1)];
        %Find indices before and after the last time crossing the Termination MAV
        Idxs2TermX = [IdxMAVTermX(end) - 1, IdxMAVTermX(1)];
        % Find MAVs before and after first time crossing Initiation MAV
        MAVsInitX = SpikeWindowMAV(Idxs2InitX);
        % Find MAVs before and after the last time crossing Termination MAV
        MAVsTermX = SpikeWindowMAV(Idxs2TermX);
        % Find Times before and after first time crossing Initiation MAV
        TimesInitX = SpikeWindowTime(Idxs2InitX);
        % Find Times before and after the last time crossing Termination MAV
        TimesTermX = SpikeWindowTime(Idxs2TermX);

    % Interpolation, Interpolate Times where crossings happened from the points
    % around them, 
        % Baseline: 
        MAVsBaselineXDiff = MAVsBaselineX(2) - MAVsBaselineX(1);
        TimesBaselineXDiff = TimesBaselineX(2) - TimesBaselineX(1);
        x = dataBaselineMean - MAVsBaselineX(1);
        BaselineTime = (x./MAVsBaselineXDiff).*TimesBaselineXDiff + TimesBaselineX(1);
        % Initiation: 
        MAVsInitXDiff = MAVsInitX(2) - MAVsInitX(1);
        TimesInitXDiff = TimesInitX(2) - TimesInitX(1);
        x = MAVInit - MAVsInitX(1);
        InitTime = (x./MAVsInitXDiff).*TimesInitXDiff + TimesInitX(1);
        % Termination: 
        MAVsTermXDiff = MAVsTermX(1) - MAVsTermX(2);
        TimesTermXDiff = TimesTermX(2) - TimesTermX(1);
        x = MAVsTermX(1) - MAVTerm;
        TermTime = (x./MAVsTermXDiff).*TimesTermXDiff + TimesTermX(1);
    
    % Time Constant Calculation
    InitTC = InitTime - BaselineTime;
    TermTC = TermTime - TimePeak ;
%% Section 6: Close the arduino serial connection before closing MATLAB
uno.close;