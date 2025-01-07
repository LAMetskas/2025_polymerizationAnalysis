function rubiscos = read_rubisco_objects_from_tomogram(data)
% This function takes in data table of rubisco from a tomogram, creates one
% Rubisco object for each row of the data table, and returns an array of 
% all the created Rubiscos.
%
% Inputs
% data - an array of rubisco data
%
% Outputs - an array of rubisco objects, one for each row of the data
    data_size = size(data, 1); % number of rubiscos in data
    c_data = repmat(Rubisco.empty, data_size, 1);
    for idx = 1:data_size
        row = data(idx, :);
        args = num2cell(row(:)); % Convert to cell array
	    c_data(idx) = Rubisco(args{:}); % Unpack cell array as arguments
    end
    rubiscos = c_data;
end