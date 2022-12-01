function [t_max, t_min] = update_figure(animatedLines, timestamp, data, features, prev_samp, data_idx, feature_idx, t_max, t_min)
% [Tmax, Tmin] = updatePlot1ch(animatedLines, timeStamp, data, control, prevSamp, dataindex, controlindex, Tmax, Tmin)

% updatePlot1ch updates the plots for the EMG data and control
% animatedLines are handles for the animated lines returned from
% plotSetup(1ch).m. 

% timeStamp is the current time value and is used as the independent (x)
% variable in the graphs

% data is the whole data vector/matrix and is plotted with the max and min
% values between the previous sample and the current dataindex. 
% control is the whole control vector/matrix and is plotted at timeStamp
% with the value at controlindex
% prevSamp is the last time the graphs were plotted and control sent over
% to the virtual hand. Updated in the EMG_live(_1ch).m file after updating
% the hand.
% dataindex is the current location of emg input
% controlindex is the current index of control
% Tmax is the upper xlimit of the graphs, is updated if timeStamp is more
% than that and shifts the graphs by 5 seconds. This allows the graphs to
% keep running continuously if desired.
% Tmin is the lower xlimit of the graphs. updated similarly to Tmax as
% timeStamp increases passed Tmax
    for i = 1:length(animatedLines)
        if i <= 1
            addpoints(animatedLines{i}, timestamp, max( data(i, prev_samp:data_idx-1)));
            addpoints(animatedLines{i}, timestamp, min( data(i, prev_samp:data_idx-1)));
        else
            addpoints(animatedLines{i}, timestamp, features(i-1, feature_idx));
        end
    end
    if timestamp > t_max
        t_max = t_max + 5;
        t_min = t_min + 5;
        xlim([t_min t_max])
    end
    drawnow limitrate %update the plot, but limit update rate to 20 fps
end