function table_out = create_rubisco_table_only_chains(carboxysomes, input_tbl, output_tbl)
% This function produces a .tbl file with data for specifically Rubiscos
% in chains. 

% Inputs
%   carboxysomes is the Carboxysome array obtained after running chain_maker
%   input_tbl is the filename of the dataset used to run chain_maker. (Ex. 'dataset.tbl') 
%   output_tbl is the filename for the output tbl file data. (Ex.
%   'data_out.tbl')
% Outputs
%   table_out is an optional output MATLAB table of the data written to 
%   output_tbl.

    % Iterate through each Carboxysome
    tag_list = [];
    for carb_idx = 1:length(carboxysomes)
        carb = carboxysomes(carb_idx);
        % Store all chain tags
        for chain = carb.chains
            for tag = chain.tags
                 tag_list(end+1) = tag;
            end
        end
    end
    oms = dread(input_tbl);
    rows = ismember(oms(:,1), tag_list);
    data = oms(rows,:);
    table_out = array2table(data);
    % Open output file to write to
    fid = fopen(output_tbl, 'wt');
    if (fid == -1)
        fprintf('Cannot open output file\n');
        fclose(fid);
        return;
    end
    [rows,cols] = size(table_out);
    format_specifier = repmat('%g ', 1, cols-1);
    format_specifier = [format_specifier, '%g\n'];
    for i=1:rows
        fprintf(fid, format_specifier, table_out(i,:).Variables);
    end
    fclose(fid);
    fprintf('Successfully outputted file %s', output_tbl);
end