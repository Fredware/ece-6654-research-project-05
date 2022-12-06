function [mav_event] = compute_running_mav(data, window_size)
    mav_event = movmean(abs(data)', window_size);
end