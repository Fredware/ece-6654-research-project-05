function [tc_init, tc_term] = tc_comp(time,mav,mav_thresh)

    % Peak
        % Find Value and Index at Peak in Window
        [MAVpeak,IdxPeak] = max(mav);
        % Find Time at Peak in Window
        TimePeak = time(IdxPeak);

   % Baseline Crossing Point at Start of MVC
        % Find where MAV is above baseline (Prior to Peak)
        AboveBaselineLog =  mav(1:IdxPeak) > mav_thresh;
        % Detect where MAV crosses the baseline
        BaselineX = ischange(double(AboveBaselineLog));
        % Find Indices after MAV last crosses Baseline before Peak
        %Last Index
        IdxBaselineX = find(BaselineX,1,"last");
        % Before and After Cross Indices
        Idxs2BaselineX = [IdxBaselineX - 1, IdxBaselineX];
        %Find MAVs at Baseline Crossing Idxs
        MAVsBaselineX = mav(Idxs2BaselineX);
        %Find Time at Baseline Crossing Idxs
        TimesBaselineX = time(Idxs2BaselineX);

    % Initiation and Termination points: 1 - 1/e and 1e of difference
    % between peak and Baseline
        % Find difference between Peak MAV and Baseline MAV
        peakDiff = MAVpeak - mav_thresh;
        % Find MAVs at Time Constant points (1 - 1/e) (Initiation) and (1/e) (Termination) of difference
        % between Peak and Baseline MAVs
        MAVInit = peakDiff.*(1 - (1./exp(1))) + mav_thresh;
        MAVTerm = peakDiff.*(1./exp(1)) + mav_thresh;
        % Find MAVs above Initiation MAV points and Below Termination MAV points
        AboveMAVInitLog = mav > MAVInit; 
        AboveMAVTermLog = mav < MAVTerm;
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
        MAVsInitX = mav(Idxs2InitX);
        % Find MAVs before and after the last time crossing Termination MAV
        MAVsTermX = mav(Idxs2TermX);
        % Find Times before and after first time crossing Initiation MAV
        TimesInitX = time(Idxs2InitX);
        % Find Times before and after the last time crossing Termination MAV
        TimesTermX = time(Idxs2TermX);

    % Interpolation, Interpolate Times where crossings happened from the points
    % around them, 
        % Baseline: 
        MAVsBaselineXDiff = MAVsBaselineX(2) - MAVsBaselineX(1);
        TimesBaselineXDiff = TimesBaselineX(2) - TimesBaselineX(1);
        x = mav_thresh - MAVsBaselineX(1);
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
    tc_init = InitTime - BaselineTime;
    tc_term = TermTime - TimePeak ;