function [] = neighboring_rubisco_bend_analysis(carboxysome_data, bin_limit, bin_width, min_chain_length)
% This function creates a histogram of the bend angles between adjacent 
% rubiscos in a chain and colors the data based on the inner concentration
% of the chain's parent carboxysome. The user can select the range of the 
% histogram bins, width of the bins, and the minimum chain length.
%
% Inputs
% carboxysome_data - an array of carboxysome objects filled with data at
%                    least through chain_maker.m
% bin_limit - the rightmost bin edge value, recommended to be the value
%             used for max_angle in chain_maker (tight - 25, pivot - 50)
% bin_width - the width to make bins in the histogram (in degrees)
% min_chain_length - the minimum length a chain can be and still be
%                    included in this analysis
%
% neighboring_rubisco_bend_analysis.m © 2025 is licensed under CC BY-NC-SA 4.0

    % create arrays to hold the data that will be plotted
    bends = [];
    inner_concentrations = [];
    
    % for each carboxysome in the dataset
    for carb = carboxysome_data
        % for each chain with length >= min_chain_length
        for chain = carb.chains([carb.chains.length] >= min_chain_length)
            % for each rubisco linkage in the chain
            for i = 1:length(chain.indices) - 1

                % get the two adjacent rubisco objects
                rubisco_i = carb.rubisco(chain.indices(i));
                rubisco_j = carb.rubisco(chain.indices(i+1));

                % calculate their bend and inner concentration and
                % save it to the arrays to be plotted
                bends(end+1) = calc_bend(rubisco_i, rubisco_j);
                inner_concentrations(end+1) = carb.inner_concentration;
            end
        end
    end

    custom_bins = 0:bin_width:bin_limit; % the edges of the custom bins
    [~, ~, bin_relation] = histcounts(bends, custom_bins); % finds to which bin each bend data point went
    plotz = NaN(length(custom_bins) - 1, length(bends)); % COLORBAR DATA IN SPECIAL FORMAT
    
    % Group the values in z by the vertical bar their corresponding y
    % values belong to. Each row in plotz represents a vertical bar. Each
    % column in plotz represents a layer in the bar.
    for i = 1:length(bends)
        try
            plotz(bin_relation(i), i) = inner_concentrations(i);
        catch % if a data point exceeds the user-defined bend angle upper limit
            % print a warning message and skip that point
            fprintf("Warning: Data point outside of user-specified angle range.\n");
            fprintf("Make sure the bin_limit input matches the max_angle input from linkages.m.\n");
            fprintf("If they match, the data likely has a bad data point. Skipping this point.\n\n");
        end
    end
    
    % Reorder the data in plotz so each column holds only one value that is
    % not NaN and each row is sorted from largest to smallest
    bookmark = 1; % keep track of the end of the data from the last row
    for i = 1:size(plotz, 1) % for each row in plotz
        data_to_move = sort(plotz(i, ~isnan(plotz(i, :))), 'descend')'; % extract all the data from the row
        plotz(i, :) = nan; % clear the row
        plotz(i, bookmark:bookmark + length(data_to_move) - 1) = data_to_move; % paste in the extracted data
        bookmark = bookmark + length(data_to_move); % update the bookmark
    end

    z_values = unique(sort(inner_concentrations, 'descend'), 'stable'); % all the unique z values from large to small
    plotdata = zeros(length(custom_bins) - 1, length(z_values)); % the data that will be bar heights

    % calculates how many identical values exist in each row of plotz and
    % condenses them into one column. If there are n copies of a value, 
    % then num_repeats will have value n for that row and store n in some
    % position in plotdata
    for z_value = z_values
        num_repeats = sum(plotz == z_value, 2); % the number of times z_value appears in each row of plotz
        plotdata(:, z_values == z_value) = num_repeats; % each column of plotdata contains instances of the same z_value
    end
    
    figure;
    b = bar(1:length(custom_bins)-1, plotdata, 'stacked', 'FaceColor', 'flat'); % make a stacked bar graph

    % Link the concentration data to a colormap if there are multiple
    % carboxysomes
    if length(carboxysome_data) > 1
        cmap = colormap('winter');
        zmap = linspace(min(z_values), max(z_values), length(cmap));
        
        % Color each data point based on where it is between the min and max
        for i = 1:length(b)
            % make the bar's color proportional to its z value's distance between z_min and z_max
            b(i).CData = interp1(zmap, cmap, z_values(i));
            b(i).EdgeColor = 'none'; % remove the edges of the bars
        end
    end

    % Make some lables for the plot
    title(['Bend Angles Between Neighboring Rubiscos in Chains of length >=', num2str(min_chain_length), '']);
    xlabel('Bend Angle (deg)');
    ylabel('Counts');

    % Make x axis labels that reflect the actual bin edges
    x_axis_labels = {};

    % Make labels for the x axis of the format [-45,-40), for example.
    % Matlab puts values on the edge of two bins in the larger bin, so we
    % use an open parenthesis on the right
    for i = 1:length(custom_bins) - 1
        if i == length(custom_bins) - 1
            % the largest bin gets a closed parenthesis on the right
            this_label = ['[',num2str(custom_bins(i)),',',num2str(custom_bins(i+1)),']'];
        else
            this_label = ['[',num2str(custom_bins(i)),',',num2str(custom_bins(i+1)),')'];
        end

        x_axis_labels{end+1} = this_label;
    end
    xticks(1:length(custom_bins) - 1); % make enough ticks for each bin
    xticklabels(x_axis_labels); % load the x axis labels
    
    % create and edit the colorbar if needed
    if length(carboxysome_data) > 1
        caxis([min(z_values), max(z_values)]);
        c = colorbar('Location', 'southoutside');
        c.Label.String = 'Inner Rubisco Concentration (\muM)'; % colorbar title
    end
end