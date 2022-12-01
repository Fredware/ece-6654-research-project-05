classdef SerialComm < handle
    % This class for connecting to, reading from, and closing the TASKA fingertip sensors
    %
    % Note: It is currently hard-coded for eight sensors (4 IR, 4 baro),
    % but could be adapted for other sensor counts
    %
    % Example usage:
    % TS = TASKASensors;
    % TS.Status.IR or TS.Status.BARO would display IR or baro data,
    % respectively
    %
    % Version: 20210222
    % Author: Tyler Davis
    
    properties
        ARD; 
        COM_ID;
        Count; 
        Data_Buffer;
        Status;
        Ready; 
    end
    
    methods
        function obj = SerialComm( varargin)
            % Optional args:            
            % {1}: Numbre of channels (defaults to 1).
            % {2}: COM Port ID

            obj.Ready = false;
            
            % Buffer size = channels * 500 samples @ 1 kHz = 500 ms of data
            if nargin > 0
                n_chans = varargin{1};
            else
                n_chans = 1;
            end

            n_samples = 50000;
            
            obj.Data_Buffer = zeros(n_chans, n_samples);
            
            obj.Status.ElapsedTime = nan;
            obj.Status.CurrTime = clock;
            obj.Status.LastTime = clock;
            obj.Count = 0;
            
            if nargin > 1
                COMPort=varargin{2};
                init( obj, COMPort);
            else
                init( obj);
            end
        end
        
        function init( obj, varargin)
            if nargin > 1
                COMPort = varargin{1};
                if ~isempty( COMPort)
                    obj.COM_ID = sprintf( 'COM%0.0f', COMPort(1));
                end
            else
                devs = getSerialID;
                if ~isempty(devs)
                    COMPort = cell2mat(devs(~cellfun(@isempty,regexp(devs(:,1),'Arduino Uno')),2));
                    if ~isempty(COMPort)
                        obj.COM_ID = sprintf('COM%0.0f',COMPort(1));
                    else
                        COMPort = cell2mat(devs(~cellfun(@isempty,regexp(devs(:,1),'USB-SERIAL CH340')),2));
                        if ~isempty(COMPort)
                            obj.COM_ID = sprintf('COM%0.0f',COMPort(1));
                        end
                    end
                end
            end
            delete(instrfind('port',obj.COM_ID));
            obj.ARD = serialport(obj.COM_ID,256000,'Timeout',1); %9600
            configureCallback(obj.ARD,"terminator",@obj.read);
            flush(obj.ARD);
            pause(0.1);
            obj.Ready = true;
        end
        
        function close( obj, varargin)
            if isobject( obj.ARD)
                delete( obj.ARD);
            end
        end
        
        function read( obj, varargin)
            try
                % read data & update status
                obj.Status.Data = sscanf( readline( obj.ARD), '%d');
                obj.Status.CurrTime = clock;
                obj.Status.ElapsedTime = etime( obj.Status.CurrTime, obj.Status.LastTime);
                obj.Status.LastTime = obj.Status.CurrTime;
                
                % store data into buffer
                obj.Data_Buffer = circshift( obj.Data_Buffer, -1, 2);
                obj.Data_Buffer( :, end) = obj.Status.Data;
                
                obj.Count = obj.Count + 1;
            catch
                disp('Serial communication error!')
            end
        end
        
        function EMG = getEMG( obj, varargin)
            % - divide by highest value (1024) to normalize signal
            % - multiply by 5 to match the signal recorded by the SpikerShield (0V-5V)
            % - subtract 2.5 V to make the signal zero-centered and undo the
            %   shift introduced by BYB  
            EMG = obj.Data_Buffer / 1024 * 5 - 2.5;
        end
        
        function [EMG] = getRecentEMG( obj, varargin)
            lastIdx = length( obj.Data_Buffer);
            startIdx = lastIdx - obj.Count;
            if startIdx < 1
                startIdx = 1;
            end
            if startIdx == lastIdx
                EMG = [];
            else
                EMG = obj.Data_Buffer( :, startIdx:end) / 1024 * 5 - 2.5;
                obj.Count = 0;
            end
%             varargout{1} = obj.Status.CurrTime;
%             varargout{2} = length(EMG) / ( obj.Status.CurrTime - obj.Status.LastTime);
        end
    end    
end %class