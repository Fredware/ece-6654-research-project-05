function [board, connected] = connect_board(varargin)
% This function sets up the communication between matlab and the arduino,
% for one EMG channel input.
% uno is a serial communication MATLAB object that is used to get the data
% from the arduino, and ArduinoConnected is a flag specifying if the
% connection was made (1) or not (0).

try
    % SET UP ARDUINO COMMUNICATION
    if nargin
        SerialComm(varargin);
    else
        board = SerialComm(); %setup connection to arduino
    end
    connected = 1;
    disp('Board connection: INITIATED')
catch
    board = NaN;
    connected = 0;
    disp('Board connection: FAILED')
end
end